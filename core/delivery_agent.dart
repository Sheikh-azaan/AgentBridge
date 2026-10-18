import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/order.dart';
import 'app_config.dart';
import 'bridge_protocol.dart';

/// DeliveryAgent
/// ─────────────────────────────────────────────────────────────────────────────
/// 1. Fetches real order data from Supabase orders table
/// 2. Injects order data into system prompt (Gemini Prompt Training)
/// 3. Sends prompt to Gemini API
/// 4. Handles inter-agent communication from Shopping Agent
/// ─────────────────────────────────────────────────────────────────────────────
class DeliveryAgent {
  final _supabase = Supabase.instance.client;

  /// Main entry: fetch orders → build prompt → ask Gemini
  Future<String> processDeliveryQuery(String userMessage) async {
    final uid = _supabase.auth.currentUser?.id;

    // ── 1. Fetch real orders from Supabase ────────────────────────────────────
    final List<Order> orders = await fetchOrders(uid);

    if (orders.isEmpty) {
      return '📦 No orders found in database. Place an order through the Shopping Agent first.';
    }

    // ── 2. Build order context string (Dynamic Training) ──────────────────────
    final String orderContext = orders
        .map((o) => o.toPromptString())
        .join('\n─────────────────\n');

    // ── 3. Build full prompt ──────────────────────────────────────────────────
    final String systemPrompt = '''
You are the Delivery Support Agent for AgentBridge.
Here is the LIVE order and shipment data directly from our Supabase database:

$orderContext

Answer the user's delivery questions ONLY based on this real data.
Be concise, professional, and friendly. Include tracking number, courier, ETA, and status when relevant.
If asked about an order or product not in this data, clearly state that no record exists in the system.
''';

    final String fullPrompt = '$systemPrompt\n\nUSER: $userMessage';

    // ── 4. Send to Gemini ─────────────────────────────────────────────────────
    return await _callGemini(fullPrompt);
  }

  /// Fetch orders from Supabase (with fallback if user ID was from SQL editor)
  Future<List<Order>> fetchOrders([String? uid]) async {
    final currentUid = uid ?? _supabase.auth.currentUser?.id;
    try {
      if (currentUid != null) {
        final response = await _supabase
            .from('orders')
            .select()
            .eq('owner_id', currentUid)
            .order('created_at', ascending: false);

        final list = (response as List).map((e) => Order.fromMap(e)).toList();
        if (list.isNotEmpty) return list;
      }

      // Fallback: fetch any existing orders in database (e.g. created via SQL editor)
      final allResponse = await _supabase
          .from('orders')
          .select()
          .order('created_at', ascending: false)
          .limit(10);

      return (allResponse as List).map((e) => Order.fromMap(e)).toList();
    } catch (e) {
      debugPrint('[DeliveryAgent] Error fetching orders: $e');
      return [];
    }
  }

  /// Inter-agent communication: Shopping Agent notifies Delivery Agent
  Future<Map<String, dynamic>> receiveOrderFromShoppingAgent({
    required String productName,
    String? customerName,
    String? shippingAddress,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    final orderNum = 'ORD-${1000 + (DateTime.now().millisecondsSinceEpoch % 9000)}';
    final trackingNum = 'TRK${2000 + (DateTime.now().millisecondsSinceEpoch % 8000)}';
    final courier = 'FedEx Express';
    final eta = DateTime.now().add(const Duration(days: 3)).toIso8601String().split('T')[0];

    // 1. Insert order into Supabase orders table
    if (uid != null) {
      try {
        await _supabase.from('orders').insert({
          'owner_id': uid,
          'customer_name': customerName ?? 'AgentBridge Customer',
          'order_number': orderNum,
          'product_name': productName,
          'tracking_number': trackingNum,
          'courier': courier,
          'status': 'out_for_delivery',
          'shipping_address': shippingAddress ?? 'House 5, Tech Zone',
          'estimated_delivery': eta,
        });
      } catch (e) {
        debugPrint('[DeliveryAgent] Error inserting order: $e');
      }

      // 2. Record inter-agent communication in Supabase messages table
      try {
        await _supabase.from('messages').insert({
          'owner_id': uid,
          'content': '🤖 [Shopping Agent ➔ Delivery Agent]: New order placed for $productName ($orderNum). Please arrange dispatch.',
          'ai_response': '🚚 [Delivery Agent ➔ Shopping Agent]: Order $orderNum received and verified! Assigned courier: $courier (Tracking: $trackingNum). Delivery ETA: $eta.',
          'status': 'approved',
        });
      } catch (e) {
        debugPrint('[DeliveryAgent] Error inserting inter-agent message: $e');
      }
    }

    return {
      'order_number': orderNum,
      'tracking_number': trackingNum,
      'courier': courier,
      'product_name': productName,
      'estimated_delivery': eta,
      'status': 'out_for_delivery',
    };
  }

  /// Execute an approved inter-agent message (Permission Granted by Owner)
  Future<void> executeApprovedDispatch({
    required String messageId,
    required String content,
  }) async {
    final uid = _supabase.auth.currentUser?.id;

    // Use BridgeProtocol to parse standardized packet
    final packet = BridgeProtocol.parseSupabaseMessage(content);
    final productName = packet.payload['product_name'] ?? 'Product Item';

    final orderNum = 'ORD-${1000 + (DateTime.now().millisecondsSinceEpoch % 9000)}';
    final trackingNum = 'TRK${2000 + (DateTime.now().millisecondsSinceEpoch % 8000)}';
    final courier = 'FedEx Express';
    final eta = DateTime.now().add(const Duration(days: 3)).toIso8601String().split('T')[0];

    try {
      if (uid != null) {
        // 1. Insert into live Supabase orders table
        await _supabase.from('orders').insert({
          'owner_id': uid,
          'customer_name': 'Verified Customer',
          'order_number': orderNum,
          'product_name': productName,
          'tracking_number': trackingNum,
          'courier': courier,
          'status': 'out_for_delivery',
          'shipping_address': 'Sector 7, Tech Zone',
          'estimated_delivery': eta,
        });

        // 2. Update message with Delivery Agent response
        final response = '🚚 [Delivery Agent]: Permission GRANTED by Owner! Dispatched $orderNum via $courier (Tracking: $trackingNum, ETA: $eta).';
        await _supabase.from('messages').update({
          'status': 'approved',
          'ai_response': response,
        }).eq('id', messageId);
      }
    } catch (e) {
      debugPrint('[DeliveryAgent] Error executing approved dispatch: $e');
    }
  }

  /// Delivery Agent asks Shopping Agent (e.g. accessories, stock, replacement)
  Future<void> sendQueryToShoppingAgent({
    required String question,
    String? orderNumber,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid != null) {
      try {
        final packet = BridgeProtocol.buildCatalogInquiryPacket(
          question: question,
          orderNumber: orderNumber,
        );

        await _supabase.from('messages').insert({
          'owner_id': uid,
          'content': packet.rawText,
          'status': 'pending', // Awaiting owner approval!
        });
      } catch (e) {
        debugPrint('[DeliveryAgent] Error sending query to Shopping Agent: $e');
      }
    }
  }

  // ── Call Gemini API ────────────────────────────────────────────────────────
  Future<String> _callGemini(String prompt) async {
    final endpoint = AppConfig.aiRelayEndpoint;
    final apiKey = AppConfig.aiApiKey;

    if (apiKey.isEmpty || apiKey == 'YOUR_GEMINI_OR_OPENAI_KEY_HERE') {
      return '⚠️ AI_API_KEY not configured in .env file.';
    }

    try {
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
        return data['candidates']?[0]?['content']?['parts']?[0]?['text'] ??
            'No response from AI.';
      } else {
        debugPrint('[DeliveryAgent] Gemini error ${response.statusCode}: ${response.body}');
        return '❌ AI error (${response.statusCode}): Could not process query.';
      }
    } catch (e) {
      debugPrint('[DeliveryAgent] Network error: $e');
      return '❌ Network error: Could not reach Gemini API.';
    }
  }
}
