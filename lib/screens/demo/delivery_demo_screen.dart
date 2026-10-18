import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/delivery_agent.dart';
import '../../models/order.dart';
import '../../theme/app_colors.dart';

class DeliveryDemoScreen extends StatefulWidget {
  const DeliveryDemoScreen({super.key});

  @override
  State<DeliveryDemoScreen> createState() => _DeliveryDemoScreenState();
}

class _DeliveryDemoScreenState extends State<DeliveryDemoScreen> {
  final DeliveryAgent _agent = DeliveryAgent();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = false;
  final List<Map<String, String>> _messages = [];

  final List<String> _suggestions = [
    'Where is my order?',
    'What is the tracking number for ORD-1001?',
    'Ask Shopping Agent for matching accessories',
    'Ask Shopping Agent for replacement items',
  ];

  Future<void> _sendMessage(String text) async {
    final query = text.trim();
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();

    setState(() {
      _messages.add({'role': 'user', 'text': query});
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();

    // Check if user is asking the Delivery Agent to consult the Shopping Agent
    final lower = query.toLowerCase();
    if (lower.contains('ask shopping') || lower.contains('accessory') || lower.contains('replacement') || lower.contains('exchange')) {
      await _agent.sendQueryToShoppingAgent(question: query);

      setState(() {
        _messages.add({
          'role': 'agent',
          'text': '🚚 [Delivery Agent]: I have sent a consultation inquiry to our Shopping Agent through AgentBridge:\n\n'
              '"$query"\n\n'
              '🔒 Due to permission security, please open the Messages tab and tap Approve to allow the Shopping Agent to respond.',
        });
        _isLoading = false;
      });
      _scrollToBottom();
      return;
    }

    final reply = await _agent.processDeliveryQuery(query);

    setState(() {
      _messages.add({'role': 'agent', 'text': reply});
      _isLoading = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showOrdersSheet() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return FutureBuilder<List<Order>>(
          future: _agent.fetchOrders(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 250,
                child: Center(child: CircularProgressIndicator(color: Colors.green)),
              );
            }
            final orders = snapshot.data ?? [];
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Live Supabase Orders',
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${orders.length} in Gemini Context',
                          style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (orders.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No orders found in database.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: orders.length,
                        separatorBuilder: (_, _) => const Divider(color: AppColors.border),
                        itemBuilder: (context, idx) {
                          final o = orders[idx];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.local_shipping, color: Colors.green, size: 20),
                            ),
                            title: Text(
                              '${o.orderNumber}: ${o.productName}',
                              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                            ),
                            subtitle: Text(
                              'Status: ${o.status} • Tracking: ${o.trackingNumber ?? "N/A"} (${o.courier ?? "TBD"})',
                              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
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

  void _showAskShoppingAgentDialog() {
    final queryController = TextEditingController(
      text: 'Can you recommend matching accessories or cables for our recent electronics orders?',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.forum_outlined, color: Colors.blue),
            SizedBox(width: 8),
            Text('Ask Shopping Agent', style: TextStyle(color: AppColors.textPrimary, fontSize: 17)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The Delivery Agent will ask the Shopping Agent through AgentBridge:',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: queryController,
              maxLines: 3,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Question for Shopping Agent',
                filled: true,
                fillColor: AppColors.background,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Will be recorded as PENDING. You can Approve or Reject in the Messages tab.',
              style: TextStyle(color: AppColors.textMuted, fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              final q = queryController.text.trim();
              if (q.isNotEmpty) {
                await _agent.sendQueryToShoppingAgent(question: q);
                setState(() {
                  _messages.add({
                    'role': 'agent',
                    'text': '🚚 [Delivery Agent ➔ Shopping Agent Consultation Sent]\n\n'
                        'Question: "$q"\n\n'
                        '🔒 Status: PENDING (Waiting for Owner Approval in Messages screen).',
                  });
                });
                _scrollToBottom();
              }
            },
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('Send Inquiry'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.local_shipping, color: Colors.green, size: 18),
            ),
            const SizedBox(width: 8),
            const Flexible(
              child: Text(
                'Delivery Agent',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Ask Shopping Agent',
            icon: const Icon(Icons.forum_outlined, color: Colors.blue),
            onPressed: _showAskShoppingAgentDialog,
          ),
          IconButton(
            tooltip: 'View Live Supabase Orders',
            icon: const Icon(Icons.inventory_2_outlined, color: Colors.green),
            onPressed: _showOrdersSheet,
          ),
          IconButton(
            tooltip: 'View Messages Inbox',
            icon: const Icon(Icons.mark_email_unread_rounded, color: AppColors.primary),
            onPressed: () => context.push('/messages'),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Chat Messages ──────────────────────────────────────────────────
          Expanded(
            child: _messages.isEmpty
                ? _buildWelcome()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length + (_isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) return _buildTyping();
                      final msg = _messages[index];
                      return _buildBubble(msg['role']!, msg['text']!);
                    },
                  ),
          ),

          // ── Suggestions ───────────────────────────────────────────────────
          if (_messages.isEmpty)
            SizedBox(
              height: 44,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _suggestions.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) => GestureDetector(
                  onTap: () => _sendMessage(_suggestions[i]),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(_suggestions[i],
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ),
                ),
              ),
            ),

          const SizedBox(height: 8),

          // ── Input Bar ─────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            color: AppColors.surface,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: const TextStyle(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Ask delivery details or ask Shopping Agent...',
                      hintStyle: const TextStyle(color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                    ),
                    onSubmitted: _sendMessage,
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _isLoading ? null : () => _sendMessage(_controller.text),
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _isLoading ? Colors.grey : Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send, color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcome() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.local_shipping, color: Colors.green, size: 40),
            ),
            const SizedBox(height: 16),
            const Text('Delivery Agent', style: TextStyle(color: AppColors.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Trained with live Supabase orders & Gemini',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _showOrdersSheet,
                  icon: const Icon(Icons.dataset_outlined, size: 16),
                  label: const Text('View Live Orders'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.withValues(alpha: 0.15),
                    foregroundColor: Colors.green,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showAskShoppingAgentDialog,
                  icon: const Icon(Icons.forum_outlined, size: 16),
                  label: const Text('Ask Shopping Agent'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.withValues(alpha: 0.15),
                    foregroundColor: Colors.blue,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(String role, String text) {
    final isUser = role == 'user';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.local_shipping, color: Colors.green, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? Colors.green : AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
              ),
              child: Text(
                text,
                style: TextStyle(
                  color: isUser ? Colors.white : AppColors.textPrimary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildTyping() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.local_shipping, color: Colors.green, size: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                SizedBox(
                  width: 40,
                  child: Text('...', style: TextStyle(color: Colors.green, fontSize: 18, letterSpacing: 4)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
