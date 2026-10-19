import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../core/app_config.dart';
import '../core/bridge_protocol.dart';

class AgentResponse {
  final bool isSuccess;
  final String? reply;
  final Map<String, dynamic>? data;
  final String? error;
  final int statusCode;

  AgentResponse({
    required this.isSuccess,
    this.reply,
    this.data,
    this.error,
    this.statusCode = 200,
  });

  factory AgentResponse.success(String reply, {Map<String, dynamic>? data, int statusCode = 200}) {
    return AgentResponse(
      isSuccess: true,
      reply: reply,
      data: data,
      statusCode: statusCode,
    );
  }

  factory AgentResponse.failure(String error, {int statusCode = 500}) {
    return AgentResponse(
      isSuccess: false,
      error: error,
      statusCode: statusCode,
    );
  }
}

class AgentConnector {
  static final AgentConnector _instance = AgentConnector._internal();
  factory AgentConnector() => _instance;
  AgentConnector._internal();

  final http.Client _httpClient = http.Client();

  Future<AgentResponse> pingAgent(String endpoint, {Duration timeout = const Duration(seconds: 5)}) async {
    try {
      final uri = Uri.parse(endpoint);
      final response = await _httpClient.get(uri).timeout(timeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return AgentResponse.success('Agent is online and reachable', statusCode: response.statusCode);
      }
      return AgentResponse.failure('Agent returned HTTP ${response.statusCode}', statusCode: response.statusCode);
    } catch (e) {
      debugPrint('[AgentConnector] ping error: $e');
      return AgentResponse.failure('Agent unreachable: $e');
    }
  }

  Future<AgentResponse> forwardToAgentEndpoint({
    required String endpoint,
    required Map<String, dynamic> payload,
    Map<String, String>? headers,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      final uri = Uri.parse(endpoint);
      final defaultHeaders = {
        'Content-Type': 'application/json',
        'User-Agent': 'AgentBridge/1.0',
      };
      if (headers != null) {
        defaultHeaders.addAll(headers);
      }

      final response = await _httpClient
          .post(
            uri,
            headers: defaultHeaders,
            body: jsonEncode(payload),
          )
          .timeout(timeout);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        try {
          final decoded = jsonDecode(response.body);
          final replyText = decoded is Map
              ? (decoded['reply'] ?? decoded['response'] ?? decoded['message'] ?? response.body)
              : response.body;

          return AgentResponse.success(
            replyText.toString(),
            data: decoded is Map ? Map<String, dynamic>.from(decoded) : null,
            statusCode: response.statusCode,
          );
        } catch (_) {
          return AgentResponse.success(response.body, statusCode: response.statusCode);
        }
      } else {
        return AgentResponse.failure(
          'Agent endpoint responded with status ${response.statusCode}: ${response.body}',
          statusCode: response.statusCode,
        );
      }
    } on TimeoutException {
      return AgentResponse.failure('Request to agent endpoint timed out', statusCode: 408);
    } catch (e) {
      debugPrint('[AgentConnector] forwardToAgentEndpoint error: $e');
      return AgentResponse.failure('Connection failed: $e');
    }
  }

  Future<AgentResponse> relayPacket(
    BridgePacket packet, {
    String? targetEndpoint,
  }) async {
    if (targetEndpoint != null && targetEndpoint.isNotEmpty) {
      return forwardToAgentEndpoint(
        endpoint: targetEndpoint,
        payload: packet.toJson(),
      );
    }

    final prompt = 'INTER-AGENT PACKET (${packet.intent.name.toUpperCase()}):\n'
        'From: ${packet.fromAgent} -> To: ${packet.toAgent}\n'
        'Message: ${packet.rawText}\n'
        'Payload: ${jsonEncode(packet.payload)}';

    return queryAIRelay(prompt: prompt);
  }

  Future<AgentResponse> queryAIRelay({
    required String prompt,
    String? systemPrompt,
    String? customEndpoint,
    String? customApiKey,
  }) async {
    final endpoint = customEndpoint ?? AppConfig.aiRelayEndpoint;
    final apiKey = customApiKey ?? AppConfig.aiApiKey;

    if (apiKey.isEmpty || apiKey == 'YOUR_GEMINI_OR_OPENAI_KEY_HERE') {
      return AgentResponse.failure('AI API key is not configured in .env');
    }

    try {
      if (endpoint.contains('generativelanguage.googleapis.com')) {
        final uri = Uri.parse('$endpoint?key=$apiKey');
        final fullText = systemPrompt != null && systemPrompt.isNotEmpty
            ? '$systemPrompt\n\n$prompt'
            : prompt;

        final response = await _httpClient.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'parts': [
                  {'text': fullText}
                ]
              }
            ]
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final text = data['candidates']?[0]?['content']?[0]?['text'] ??
              data['candidates']?[0]?['content']?['parts']?[0]?['text'] ??
              'No response generated.';
          return AgentResponse.success(text, statusCode: 200);
        }
        return AgentResponse.failure('Gemini API error: ${response.statusCode}', statusCode: response.statusCode);
      }

      if (endpoint.contains('api.groq.com') || endpoint.contains('openai.com')) {
        final uri = Uri.parse(endpoint);
        final messages = <Map<String, String>>[];
        if (systemPrompt != null && systemPrompt.isNotEmpty) {
          messages.add({'role': 'system', 'content': systemPrompt});
        }
        messages.add({'role': 'user', 'content': prompt});

        final response = await _httpClient.post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': endpoint.contains('groq') ? 'qwen/qwen3.8-27b' : 'gpt-4o-mini',
            'messages': messages,
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final text = data['choices']?[0]?['message']?['content'] ?? 'No response generated.';
          return AgentResponse.success(text, statusCode: 200);
        }
        return AgentResponse.failure('AI Model API error: ${response.statusCode}', statusCode: response.statusCode);
      }

      return forwardToAgentEndpoint(
        endpoint: endpoint,
        headers: {'Authorization': 'Bearer $apiKey'},
        payload: {
          'prompt': prompt,
          'system_prompt': systemPrompt,
        },
      );
    } catch (e) {
      debugPrint('[AgentConnector] queryAIRelay error: $e');
      return AgentResponse.failure('AI Relay request failed: $e');
    }
  }

  void dispose() {
    _httpClient.close();
  }
}
