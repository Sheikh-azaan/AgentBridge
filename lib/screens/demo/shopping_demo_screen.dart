import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/bridge_protocol.dart';
import '../../theme/app_colors.dart';

class ShoppingDemoScreen extends StatefulWidget {
  const ShoppingDemoScreen({super.key});

  @override
  State<ShoppingDemoScreen> createState() => _ShoppingDemoScreenState();
}

class _ShoppingDemoScreenState extends State<ShoppingDemoScreen> {
  final _supabase = Supabase.instance.client;
  bool _isLoading = false;
  String _log = "Ready to test the Groq Shopping Agent.\nAsk for ANY product (electronics, clothing, shoes, SSDs, bags, jewelry, monitors)!\n\n";
  final TextEditingController _promptController = TextEditingController(
    text: "Can you recommend a good backpack for travel?",
  );

  List<dynamic> _allProducts = [];
  Map<String, dynamic>? _selectedProduct;
  String? _customProductTitle;
  double _customProductPrice = 49.99;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    try {
      final storeResponse = await http.get(Uri.parse('https://fakestoreapi.com/products'));
      if (storeResponse.statusCode == 200) {
        final List<dynamic> data = jsonDecode(storeResponse.body);
        if (mounted) {
          setState(() {
            _allProducts = data;
            _detectMatchingProduct(_promptController.text);
          });
        }
      }
    } catch (e) {
      debugPrint('[ShoppingDemo] Error fetching products: $e');
    }
  }

  void _detectMatchingProduct(String query, [String? aiResponse]) {
    final q = query.toLowerCase();
    final a = (aiResponse ?? '').toLowerCase();

    if (aiResponse != null) {
      final tagMatch = RegExp(r'\[SELECTED_PRODUCT:\s*(.+?)\s*\|\s*Price:\s*\$?([\d\.]+)\]')
          .firstMatch(aiResponse);
      if (tagMatch != null) {
        final title = tagMatch.group(1)?.trim();
        final price = double.tryParse(tagMatch.group(2) ?? '49.99') ?? 49.99;
        if (title != null && title.isNotEmpty) {
          setState(() {
            _customProductTitle = title;
            _customProductPrice = price;
            _selectedProduct = _findInCatalog(title);
          });
          return;
        }
      }
    }

    if (_allProducts.isEmpty) {
      _extractCustomTitleFromQuery(query);
      return;
    }

    Map<String, dynamic>? bestProduct;
    int highestScore = 0;

    final queryWords = q
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .split(' ')
        .where((w) => w.length > 2 && !_commonStopWords.contains(w));

    for (final p in _allProducts) {
      final title = (p['title'] as String? ?? '').toLowerCase();
      final category = (p['category'] as String? ?? '').toLowerCase();
      final desc = (p['description'] as String? ?? '').toLowerCase();

      int score = 0;
      for (final w in queryWords) {
        if (title.contains(w)) score += 8;
        if (category.contains(w)) score += 4;
        if (desc.contains(w)) score += 2;
        if (a.isNotEmpty && a.contains(title.split(' ').take(3).join(' '))) score += 10;
      }

      if (score > highestScore) {
        highestScore = score;
        bestProduct = p;
      }
    }

    if (bestProduct != null && highestScore >= 4) {
      setState(() {
        _selectedProduct = bestProduct;
        _customProductTitle = bestProduct!['title'];
        _customProductPrice = (bestProduct['price'] as num?)?.toDouble() ?? 49.99;
      });
    } else {
      _extractCustomTitleFromQuery(query);
    }
  }

  static const _commonStopWords = {
    'the', 'and', 'for', 'you', 'have', 'can', 'what', 'which', 'show', 'want',
    'buy', 'need', 'give', 'good', 'best', 'tell', 'about', 'recommend', 'some', 'please'
  };

  void _extractCustomTitleFromQuery(String query) {
    String cleaned = query.trim();
    final prefixes = [
      RegExp(r'^(?:can you recommend|recommend|show me|i want to buy|i want|i need|buy a|buy an|buy)\s+', caseSensitive: false),
      RegExp(r'\s+(?:in stock|for sale|please)\??$', caseSensitive: false),
    ];
    for (final r in prefixes) {
      cleaned = cleaned.replaceAll(r, '').trim();
    }
    if (cleaned.endsWith('?')) cleaned = cleaned.substring(0, cleaned.length - 1).trim();

    if (cleaned.isNotEmpty) {
      setState(() {
        _customProductTitle = _capitalize(cleaned);
        _selectedProduct = null;
      });
    }
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s.split(' ').map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
  }

  Map<String, dynamic>? _findInCatalog(String title) {
    final lower = title.toLowerCase();
    for (final p in _allProducts) {
      if ((p['title'] as String? ?? '').toLowerCase().contains(lower) ||
          lower.contains((p['title'] as String? ?? '').toLowerCase())) {
        return p;
      }
    }
    return null;
  }

  void _appendLog(String text) {
    setState(() {
      _log += "$text\n";
    });
  }

  Future<void> _runDemo() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _log = "--- Starting Shopping Agent Run ---\n\n";
    });

    try {
      if (_allProducts.isEmpty) {
        _appendLog("1. Fetching products from Fake Store API...");
        final storeResponse = await http.get(Uri.parse('https://fakestoreapi.com/products'));
        if (storeResponse.statusCode == 200) {
          _allProducts = jsonDecode(storeResponse.body);
        }
      }

      final productSummary = _allProducts.map((p) => {
        'id': p['id'],
        'title': p['title'],
        'price': p['price'],
        'category': p['category'],
        'description': (p['description'] as String).split('.').first,
      }).toList();
      final productContextString = jsonEncode(productSummary);

      final userPrompt = _promptController.text;
      _appendLog("Query: \"$userPrompt\"");
      _appendLog("Connecting to Groq AI...");

      final apiKey = dotenv.env['GROQ_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception("GROQ_API_KEY is not set in .env");
      }

      final groqResponse = await http.post(
        Uri.parse('https://api.groq.com/openai/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          "model": "qwen/qwen3.8-27b",
          "messages": [
            {
              "role": "system",
              "content": '''You are a helpful shopping agent with access to this store inventory (JSON):
$productContextString

Rules:
1. Answer the user's questions based on our inventory.
2. If the user asks for an item we carry, recommend it and mention its price.
3. If the user asks for something not in the inventory, politely offer the closest alternative or acknowledge their request.
4. At the very end of your response, on a new line, always output the recommended product in this exact tag format:
[SELECTED_PRODUCT: Exact Product Title | Price: \$XX.XX]
'''
            },
            {
              "role": "user",
              "content": userPrompt
            }
          ]
        }),
      );

      if (groqResponse.statusCode != 200) {
        _appendLog("❌ Groq Error: ${groqResponse.body}");
        return;
      }

      final jsonResponse = jsonDecode(groqResponse.body);
      final aiMessage = jsonResponse['choices'][0]['message']['content'] ?? '';

      _appendLog("\n🤖 Shopping Agent Response:\n\n$aiMessage");

      _detectMatchingProduct(userPrompt, aiMessage);

    } catch (e) {
      _appendLog("❌ Error: $e");
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _requestPurchaseHandoff(String productName, double price) async {
    final uid = _supabase.auth.currentUser?.id;

    setState(() => _isLoading = true);
    _appendLog("\n────────────────────────────────────────");
    _appendLog("🔄 DISPATCHING INTER-AGENT REQUEST");
    _appendLog("📦 Requested Item : \"$productName\"");
    _appendLog("💵 Item Price     : \$${price.toStringAsFixed(2)}");
    _appendLog("Creating 'pending' message in Supabase...");

    try {
      if (uid != null) {
        final packet = BridgeProtocol.buildOrderDispatchPacket(
          productName: productName,
          price: price,
        );

        await _supabase.from('messages').insert({
          'owner_id': uid,
          'content': packet.rawText,
          'status': 'pending',
        });
      }

      _appendLog("✅ Permission request registered in AgentBridge!");
      _appendLog("🛑 Status: PENDING (Delivery Agent halted until you Approve in Messages)");

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.security_rounded, color: AppColors.warning),
                SizedBox(width: 8),
                Text('Approval Required', style: TextStyle(color: AppColors.textPrimary, fontSize: 17)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Shopping Agent sent this exact item for delivery:',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.inventory_2_outlined, color: Colors.green, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '$productName\n\$${price.toStringAsFixed(2)}',
                          style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'The Delivery Agent will NOT create or dispatch this shipment until you tap Approve in the Messages screen.',
                  style: TextStyle(color: AppColors.textMuted, fontSize: 12, height: 1.4),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Stay Here', style: TextStyle(color: AppColors.textSecondary)),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(ctx);
                  context.push('/messages');
                },
                icon: const Icon(Icons.mark_email_unread_rounded, size: 16),
                label: const Text('Go to Messages'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      _appendLog("❌ Error creating pending message: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showOrderConfirmationDialog(String defaultTitle, double defaultPrice) {
    final titleController = TextEditingController(text: defaultTitle);
    final priceController = TextEditingController(text: defaultPrice.toStringAsFixed(2));

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.shopping_bag_outlined, color: Colors.green),
            SizedBox(width: 8),
            Text('Confirm Item to Dispatch', style: TextStyle(color: AppColors.textPrimary, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Confirm or edit the exact product you want the Delivery Agent to handle:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: titleController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Product Name',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                labelText: 'Price (\$)',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              final finalTitle = titleController.text.trim();
              final finalPrice = double.tryParse(priceController.text) ?? defaultPrice;
              if (finalTitle.isNotEmpty) {
                _requestPurchaseHandoff(finalTitle, finalPrice);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('Send to Delivery Agent'),
          ),
        ],
      ),
    );
  }

  void _showCatalogPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          builder: (context, scrollCtrl) {
            return Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Select Any Product from Store',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.textSecondary),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.separated(
                      controller: scrollCtrl,
                      itemCount: _allProducts.length,
                      separatorBuilder: (_, _) => const Divider(color: AppColors.border),
                      itemBuilder: (context, idx) {
                        final p = _allProducts[idx];
                        final title = p['title'] ?? 'Product';
                        final price = (p['price'] as num?)?.toDouble() ?? 0.0;
                        final category = p['category'] ?? '';

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 44,
                            height: 44,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Image.network(
                              p['image'] ?? '',
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => const Icon(Icons.inventory, color: Colors.grey),
                            ),
                          ),
                          title: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '$category • \$${price.toStringAsFixed(2)}',
                            style: const TextStyle(color: Colors.green, fontSize: 12),
                          ),
                          trailing: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              setState(() {
                                _selectedProduct = p;
                                _customProductTitle = title;
                                _customProductPrice = price;
                                _promptController.text = "I would like to order $title";
                              });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            ),
                            child: const Text('Pick', style: TextStyle(color: Colors.white, fontSize: 12)),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeTitle = _customProductTitle ??
        (_selectedProduct != null ? _selectedProduct!['title'] as String : null) ??
        _promptController.text.trim();
    final activePrice = _selectedProduct != null
        ? (_selectedProduct!['price'] as num).toDouble()
        : _customProductPrice;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Shopping Agent'),
        backgroundColor: AppColors.surface,
        actions: [
          IconButton(
            tooltip: 'Browse All Products',
            icon: const Icon(Icons.storefront_rounded, color: AppColors.textSecondary),
            onPressed: _allProducts.isEmpty ? null : _showCatalogPicker,
          ),
          IconButton(
            tooltip: 'View Messages Inbox',
            icon: const Icon(Icons.mark_email_unread_rounded, color: AppColors.primary),
            onPressed: () => context.push('/messages'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _promptController,
              style: const TextStyle(color: AppColors.textPrimary),
              onChanged: (val) {
                _detectMatchingProduct(val);
              },
              decoration: InputDecoration(
                labelText: 'Ask for ANY product',
                hintText: 'e.g. SSD, Winter Jacket, Backpack, Monitor...',
                hintStyle: const TextStyle(color: AppColors.textMuted),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _runDemo,
                icon: const Icon(Icons.search_rounded, size: 18),
                label: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Ask Shopping Agent', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),

            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.shopping_bag_rounded, color: Colors.green, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activeTitle.isNotEmpty ? activeTitle : 'Type any product above',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '\$${activePrice.toStringAsFixed(2)} • Matched for Delivery Agent',
                          style: const TextStyle(color: Colors.green, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: _allProducts.isEmpty ? null : _showCatalogPicker,
                    child: const Text('Catalog', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                  ),
                  ElevatedButton(
                    onPressed: (_isLoading || activeTitle.isEmpty)
                        ? null
                        : () => _showOrderConfirmationDialog(activeTitle, activePrice),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    child: const Text('Order', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    _log,
                    style: const TextStyle(color: AppColors.textPrimary, fontFamily: 'monospace', fontSize: 13),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
