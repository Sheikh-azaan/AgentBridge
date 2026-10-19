import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/permission_rule.dart';
import 'app_config.dart';

class PermissionGate {
  final _supabase = Supabase.instance.client;

  Future<String?> processMessage({
    required String agentId,
    required String userMessage,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return null;

    final List<PermissionRule> rules = await _fetchRules(agentId);

    final String systemPrompt = _buildSystemPrompt(rules);

    final String fullPrompt = systemPrompt.isNotEmpty
        ? '$systemPrompt\n\nUSER MESSAGE:\n$userMessage'
        : userMessage;

    final String? blocked = _checkGuardrails(rules, userMessage);
    if (blocked != null) {
      await _saveMessage(
        uid: uid,
        agentId: agentId,
        content: userMessage,
        aiResponse: blocked,
        status: 'rejected',
      );
      return blocked;
    }

    final String? aiReply = await _callAI(fullPrompt);

    await _saveMessage(
      uid: uid,
      agentId: agentId,
      content: userMessage,
      aiResponse: aiReply,
      status: 'approved',
    );

    return aiReply;
  }

  Future<List<PermissionRule>> _fetchRules(String agentId) async {
    try {
      final agentRules = await _supabase
          .from('rules')
          .select()
          .eq('agent_id', agentId)
          .eq('is_active', true);

      final globalRules = await _supabase
          .from('rules')
          .select()
          .filter('agent_id', 'is', null)
          .eq('is_active', true);

      final allRules = [
        ...(agentRules as List),
        ...(globalRules as List),
      ];

      return allRules.map((e) => PermissionRule.fromMap(e)).toList();
    } catch (e) {
      debugPrint('[PermissionGate] Error fetching rules: $e');
      return [];
    }
  }

  String _buildSystemPrompt(List<PermissionRule> rules) {
    final prompts = rules
        .where((r) => r.ruleType == 'system_prompt')
        .map((r) => r.content)
        .toList();

    if (prompts.isEmpty) return '';

    return 'SYSTEM INSTRUCTIONS (follow strictly):\n${prompts.join('\n')}';
  }

  String? _checkGuardrails(List<PermissionRule> rules, String userMessage) {
    final guardrails = rules.where((r) => r.ruleType == 'guardrail').toList();

    for (final rule in guardrails) {
      final keywords = rule.content
          .split(',')
          .map((k) => k.trim().toLowerCase())
          .where((k) => k.isNotEmpty)
          .toList();

      for (final keyword in keywords) {
        if (userMessage.toLowerCase().contains(keyword)) {
          return '⚠️ This message was blocked by the rule: "${rule.ruleName}". '
              'The topic "$keyword" is not allowed for this agent.';
        }
      }
    }

    return null;
  }

  Future<String?> _callAI(String prompt) async {
    final endpoint = AppConfig.aiRelayEndpoint;
    final apiKey = AppConfig.aiApiKey;

    if (apiKey.isEmpty || apiKey == 'YOUR_GEMINI_OR_OPENAI_KEY_HERE') {
      debugPrint('[PermissionGate] AI_API_KEY not set in .env');
      return 'AI API key not configured. Please set AI_API_KEY in your .env file.';
    }

    try {
      if (endpoint.contains('generativelanguage.googleapis.com')) {
        final uri = Uri.parse('$endpoint?key=$apiKey');
        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': prompt}
                ]
              }
            ]
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['candidates']?[0]?['content']?['parts']?[0]?['text']
              as String?;
        } else {
          debugPrint('[PermissionGate] Gemini error ${response.statusCode}: ${response.body}');
          return 'AI error: ${response.statusCode}';
        }
      } else if (endpoint.contains('openai.com')) {
        final uri = Uri.parse(endpoint);
        final response = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': 'gpt-4o-mini',
            'messages': [
              {'role': 'user', 'content': prompt}
            ],
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['choices']?[0]?['message']?['content'] as String?;
        } else {
          debugPrint('[PermissionGate] OpenAI error ${response.statusCode}: ${response.body}');
          return 'AI error: ${response.statusCode}';
        }
      } else {
        final uri = Uri.parse(endpoint);
        final response = await http.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({'message': prompt}),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['reply'] ?? data['response'] ?? data['text'] as String?;
        } else {
          return 'AI error: ${response.statusCode}';
        }
      }
    } catch (e) {
      debugPrint('[PermissionGate] Network error: $e');
      return 'Network error: Could not reach AI service.';
    }
  }

  Future<void> _saveMessage({
    required String uid,
    required String agentId,
    required String content,
    String? aiResponse,
    required String status,
  }) async {
    try {
      await _supabase.from('messages').insert({
        'owner_id': uid,
        'agent_id': agentId,
        'content': content,
        'ai_response': aiResponse,
        'status': status,
      });
    } catch (e) {
      debugPrint('[PermissionGate] Error saving message: $e');
    }
  }
}
