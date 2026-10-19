import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

class ShoppingAgent {
  final _supabase = Supabase.instance.client;

  Future<List<dynamic>> fetchCatalog() async {
    try {
      final res = await http.get(Uri.parse('https://fakestoreapi.com/products'));
      if (res.statusCode == 200) {
        return jsonDecode(res.body) as List<dynamic>;
      }
    } catch (e) {
      debugPrint('[ShoppingAgent] Error fetching catalog: $e');
    }
    return [];
  }

  Future<String> queryGroq({
    required String prompt,
    String? systemContext,
  }) async {
    final apiKey = dotenv.env['GROQ_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      return '⚠️ GROQ_API_KEY is not set in .env';
    }

    try {
      final response = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'qwen/qwen3.8-27b',
          'messages': [
            if (systemContext != null)
              {'role': 'system', 'content': systemContext},
            {'role': 'user', 'content': prompt},
          ],
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['choices']?[0]?['message']?['content'] ?? 'No response from Groq.';
      } else {
        return '❌ Groq error: ${response.statusCode}';
      }
    } catch (e) {
      return '❌ Network error connecting to Groq AI: $e';
    }
  }

  Future<void> executeApprovedQueryFromDeliveryAgent({
    required String messageId,
    required String content,
  }) async {
    final catalog = await fetchCatalog();
    final catalogSummary = catalog.take(15).map((p) => {
      'title': p['title'],
      'price': p['price'],
      'category': p['category'],
    }).toList();

    final systemContext = '''
You are the Shopping Agent for AgentBridge.
The Delivery Agent is asking you a question regarding a customer order.
Here is your current store catalog:
${jsonEncode(catalogSummary)}

Provide a clear, helpful, and concise answer recommending items, checking stock, or clarifying details.
''';

    final answer = await queryGroq(
      prompt: content,
      systemContext: systemContext,
    );

    try {
      await _supabase.from('messages').update({
        'status': 'approved',
        'ai_response': '🤖 [Shopping Agent]: $answer',
      }).eq('id', messageId);
    } catch (e) {
      debugPrint('[ShoppingAgent] Error updating message: $e');
    }
  }
}
