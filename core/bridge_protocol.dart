import 'dart:convert';

/// BridgeIntent: Represents the standardized intent of an inter-agent message
enum BridgeIntent {
  orderDispatch,    // Shopping Agent -> Delivery Agent (Create order)
  catalogInquiry,   // Delivery Agent -> Shopping Agent (Ask about products/accessories)
  trackingInquiry,  // User / Agent -> Delivery Agent (Track order)
  generalQuery,     // General conversation
}

/// BridgePacket: Standardized communication unit across all agents
class BridgePacket {
  final String id;
  final String fromAgent;
  final String toAgent;
  final BridgeIntent intent;
  final Map<String, dynamic> payload;
  final String rawText;
  final bool requiresApproval;
  final DateTime timestamp;

  BridgePacket({
    required this.id,
    required this.fromAgent,
    required this.toAgent,
    required this.intent,
    required this.payload,
    required this.rawText,
    this.requiresApproval = true,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Convert to JSON for transmission or logging
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'from_agent': fromAgent,
      'to_agent': toAgent,
      'intent': intent.name,
      'payload': payload,
      'raw_text': rawText,
      'requires_approval': requiresApproval,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  /// Construct from JSON
  factory BridgePacket.fromJson(Map<String, dynamic> json) {
    return BridgePacket(
      id: json['id'] ?? '',
      fromAgent: json['from_agent'] ?? 'unknown',
      toAgent: json['to_agent'] ?? 'unknown',
      intent: BridgeIntent.values.firstWhere(
        (e) => e.name == json['intent'],
        orElse: () => BridgeIntent.generalQuery,
      ),
      payload: Map<String, dynamic>.from(json['payload'] ?? {}),
      rawText: json['raw_text'] ?? '',
      requiresApproval: json['requires_approval'] ?? true,
      timestamp: json['timestamp'] != null
          ? DateTime.tryParse(json['timestamp']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// BridgeProtocol
/// ─────────────────────────────────────────────────────────────────────────────
/// The Universal Normalization & Translation Layer for AgentBridge.
/// Converts between disparate AI model schemas (Gemini, Groq, OpenAI)
/// and handles inter-agent packet encoding / decoding.
/// ─────────────────────────────────────────────────────────────────────────────
class BridgeProtocol {
  BridgeProtocol._(); // static utility class

  // ── 1. Inter-Agent Packet Builders ─────────────────────────────────────────

  /// Creates an Order Dispatch packet (Shopping Agent ➔ Delivery Agent)
  static BridgePacket buildOrderDispatchPacket({
    required String productName,
    required double price,
    String? customerName,
    String? address,
  }) {
    final payload = {
      'product_name': productName,
      'price': price,
      'customer_name': customerName ?? 'Verified Customer',
      'shipping_address': address ?? 'Sector 7, Tech Zone',
    };

    final rawText = '🤖 [Shopping Agent ➔ Delivery Agent]: '
        'User ordered "$productName" (\$${price.toStringAsFixed(2)}). '
        'Requesting Delivery Agent to dispatch shipment.';

    return BridgePacket(
      id: 'pkt_${DateTime.now().millisecondsSinceEpoch}',
      fromAgent: 'shopping_agent',
      toAgent: 'delivery_agent',
      intent: BridgeIntent.orderDispatch,
      payload: payload,
      rawText: rawText,
      requiresApproval: true,
    );
  }

  /// Creates a Consultation packet (Delivery Agent ➔ Shopping Agent)
  static BridgePacket buildCatalogInquiryPacket({
    required String question,
    String? orderNumber,
  }) {
    final payload = {
      'question': question,
      'order_number': orderNumber,
    };

    final rawText = '🚚 [Delivery Agent ➔ Shopping Agent]: '
        '${orderNumber != null ? "Regarding order $orderNumber: " : ""}'
        '$question';

    return BridgePacket(
      id: 'pkt_${DateTime.now().millisecondsSinceEpoch}',
      fromAgent: 'delivery_agent',
      toAgent: 'shopping_agent',
      intent: BridgeIntent.catalogInquiry,
      payload: payload,
      rawText: rawText,
      requiresApproval: true,
    );
  }

  // ── 2. Parsing from Supabase Message Strings ───────────────────────────────

  /// Parses human-readable Supabase message content back into a typed BridgePacket
  static BridgePacket parseSupabaseMessage(String content) {
    if (content.contains('Shopping Agent') && (content.contains('ordered') || content.contains('dispatch'))) {
      String productName = 'Product Item';
      double price = 0.0;

      final nameMatch = RegExp(r'(?:ordered|for)\s+["\x27](.+?)["\x27]').firstMatch(content);
      if (nameMatch != null) {
        productName = nameMatch.group(1)?.trim() ?? productName;
      }

      final priceMatch = RegExp(r'\(\$([\d\.]+)\)').firstMatch(content);
      if (priceMatch != null) {
        price = double.tryParse(priceMatch.group(1) ?? '0.0') ?? 0.0;
      }

      return BridgePacket(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        fromAgent: 'shopping_agent',
        toAgent: 'delivery_agent',
        intent: BridgeIntent.orderDispatch,
        payload: {
          'product_name': productName,
          'price': price,
        },
        rawText: content,
      );
    } else if (content.contains('Delivery Agent ➔ Shopping Agent')) {
      final question = content.replaceFirst(RegExp(r'^.+?:\s*'), '').trim();
      return BridgePacket(
        id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
        fromAgent: 'delivery_agent',
        toAgent: 'shopping_agent',
        intent: BridgeIntent.catalogInquiry,
        payload: {'question': question},
        rawText: content,
      );
    }

    return BridgePacket(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      fromAgent: 'user',
      toAgent: 'all',
      intent: BridgeIntent.generalQuery,
      payload: {'text': content},
      rawText: content,
    );
  }

  // ── 3. Schema Translators (Groq ⇄ Gemini) ──────────────────────────────────

  /// Formats prompt into Google Gemini REST schema
  static Map<String, dynamic> toGeminiPayload({
    required String prompt,
    String? systemInstruction,
  }) {
    return {
      if (systemInstruction != null)
        'systemInstruction': {
          'parts': [
            {'text': systemInstruction}
          ]
        },
      'contents': [
        {
          'parts': [
            {'text': prompt}
          ]
        }
      ],
      'generationConfig': {
        'temperature': 0.7,
        'maxOutputTokens': 800,
      },
    };
  }

  /// Extracts text response from Gemini API response JSON
  static String extractGeminiText(String responseBody) {
    try {
      final data = jsonDecode(responseBody);
      return data['candidates']?[0]?['content']?['parts']?[0]?['text'] ??
          'No text returned from Gemini.';
    } catch (e) {
      return 'Error parsing Gemini response: $e';
    }
  }

  /// Formats prompt into OpenAI / Groq chat completions schema
  static Map<String, dynamic> toGroqPayload({
    required String userPrompt,
    String? systemPrompt,
    String model = 'qwen/qwen3.8-27b',
  }) {
    return {
      'model': model,
      'messages': [
        if (systemPrompt != null)
          {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userPrompt},
      ],
      'temperature': 0.6,
      'max_tokens': 1000,
    };
  }

  /// Extracts text response from Groq / OpenAI chat completion JSON
  static String extractGroqText(String responseBody) {
    try {
      final data = jsonDecode(responseBody);
      return data['choices']?[0]?['message']?['content'] ??
          'No text returned from Groq.';
    } catch (e) {
      return 'Error parsing Groq response: $e';
    }
  }
}
