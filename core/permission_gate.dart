import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/permission_rule.dart';
import 'app_config.dart';

/// PermissionGate
/// ─────────────────────────────────────────────────────────────────────────────
/// 1. Fetches active rules for a given agent from Supabase
/// 2. Composes them into a system prompt
/// 3. Sends the full request to the AI API (Gemini by default)
/// 4. Returns the AI response text
/// 5. Saves the response to the Supabase messages table
/// ─────────────────────────────────────────────────────────────────────────────
class PermissionGate {
  final _supabase = Supabase.instance.client;

  /// Main entry point.
  /// [agentId]     - the UUID of the target agent
  /// [userMessage] - the raw message the user wants to send
  /// Returns the AI's reply text, or null on failure.
  Future<String?> processMessage({
    required String agentId,
    required String userMessage,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return null;

    // ── 1. Fetch active rules for this agent (+ global rules) ────────────────
    final List<PermissionRule> rules = await _fetchRules(agentId);

    // ── 2. Build system prompt from rules ────────────────────────────────────
    final String systemPrompt = _buildSystemPrompt(rules);

    // ── 3. Compose full prompt ───────────────────────────────────────────────
    final String fullPrompt = systemPrompt.isNotEmpty
        ? '$systemPrompt\n\nUSER MESSAGE:\n$userMessage'
        : userMessage;

    // ── 4. Apply guardrails (block before API call if violated) ──────────────
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

    // ── 5. Call AI API ───────────────────────────────────────────────────────
    final String? aiReply = await _callAI(fullPrompt);

    // ── 6. Save to Supabase messages table ───────────────────────────────────
    await _saveMessage(
      uid: uid,
      agentId: agentId,
      content: userMessage,
      aiResponse: aiReply,
      status: 'approved',
    );

    return aiReply;
  }

  // ── Fetch active rules for this agent + global rules ─────────────────────
  Future<List<PermissionRule>> _fetchRules(String agentId) async {
    try {
      // Rules specific to this agent
      final agentRules = await _supabase
          .from('rules')
          .select()
          .eq('agent_id', agentId)
          .eq('is_active', true);

      // Global rules (no agent assigned)
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

  // ── Build system prompt by concatenating all system_prompt rules ──────────
  String _buildSystemPrompt(List<PermissionRule> rules) {
    final prompts = rules
        .where((r) => r.ruleType == 'system_prompt')
        .map((r) => r.content)
        .toList();

    if (prompts.isEmpty) return '';

    return 'SYSTEM INSTRUCTIONS (follow strictly):\n${prompts.join('\n')}';
  }

  // ── Check guardrail rules — returns a block message if violated ───────────
  String? _checkGuardrails(List<PermissionRule> rules, String userMessage) {
    final guardrails = rules.where((r) => r.ruleType == 'guardrail').toList();

    for (final rule in guardrails) {
      // Each guardrail content contains comma-separated keywords to block
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

    return null; // no violation
  }

  // ── Call the AI API (Gemini by default, works with OpenAI too) ────────────
  Future<String?> _callAI(String prompt) async {
    final endpoint = AppConfig.aiRelayEndpoint;
    final apiKey = AppConfig.aiApiKey;

    if (apiKey.isEmpty || apiKey == 'YOUR_GEMINI_OR_OPENAI_KEY_HERE') {
      debugPrint('[PermissionGate] AI_API_KEY not set in .env');
      return 'AI API key not configured. Please set AI_API_KEY in your .env file.';
    }

    try {
      // ── Gemini format ──────────────────────────────────────────────────────
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
      }

      // ── OpenAI format ──────────────────────────────────────────────────────
      else if (endpoint.contains('openai.com')) {
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
      }

      // ── Custom endpoint ────────────────────────────────────────────────────
      else {
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

  // ── Save message + AI response to Supabase ────────────────────────────────
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
