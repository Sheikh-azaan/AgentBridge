import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/delivery_agent.dart';
import '../../core/shopping_agent.dart';
import '../../theme/app_colors.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final _supabase = Supabase.instance.client;
  final DeliveryAgent _deliveryAgent = DeliveryAgent();
  final ShoppingAgent _shoppingAgent = ShoppingAgent();

  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  String _filter = 'all'; // 'all', 'pending', 'approved', 'rejected'

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() => _loading = true);
    try {
      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) {
        // Fallback for demo when testing
        final data = await _supabase
            .from('messages')
            .select()
            .order('created_at', ascending: false)
            .limit(30);

        if (mounted) {
          setState(() {
            _messages = List<Map<String, dynamic>>.from(data);
            _loading = false;
          });
        }
        return;
      }

      final data = await _supabase
          .from('messages')
          .select()
          .eq('owner_id', uid)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading messages: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _approveMessage(Map<String, dynamic> msg) async {
    final msgId = msg['id'];
    final content = msg['content'] ?? '';
    final isDeliveryToShopping = content.contains('Delivery Agent ➔ Shopping Agent');

    // Show processing indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(isDeliveryToShopping
            ? 'Processing approval and notifying Shopping Agent...'
            : 'Processing approval and notifying Delivery Agent...'),
        duration: const Duration(seconds: 1),
      ),
    );

    if (isDeliveryToShopping) {
      // Delivery Agent asked Shopping Agent -> Groq AI answers
      await _shoppingAgent.executeApprovedQueryFromDeliveryAgent(
        messageId: msgId,
        content: content,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Approved! Shopping Agent replied to Delivery Agent.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadMessages();
      }
    } else {
      // Shopping Agent asked Delivery Agent -> Dispatches order in Supabase
      await _deliveryAgent.executeApprovedDispatch(
        messageId: msgId,
        content: content,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Approved! Delivery Agent scheduled shipment in Supabase.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadMessages();
      }
    }
  }

  Future<void> _rejectMessage(Map<String, dynamic> msg) async {
    final msgId = msg['id'];

    try {
      await _supabase.from('messages').update({
        'status': 'rejected',
        'ai_response': '❌ [AgentBridge]: Request rejected by Owner. Operation aborted.',
      }).eq('id', msgId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Message Rejected. Delivery Agent blocked.'),
            backgroundColor: Colors.red,
          ),
        );
        _loadMessages();
      }
    } catch (e) {
      debugPrint('Error rejecting message: $e');
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'approved':
        return AppColors.success;
      case 'rejected':
        return AppColors.error;
      case 'pending':
      default:
        return AppColors.warning;
    }
  }

  List<Map<String, dynamic>> get _filteredMessages {
    if (_filter == 'all') return _messages;
    return _messages.where((m) => (m['status'] ?? 'pending') == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredMessages;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'AgentBridge Messages',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
            onPressed: _loadMessages,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Filter Chips ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('all', 'All (${_messages.length})'),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'pending',
                  'Pending (${_messages.where((m) => (m['status'] ?? 'pending') == 'pending').length})',
                  color: AppColors.warning,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'approved',
                  'Approved',
                  color: AppColors.success,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'rejected',
                  'Rejected',
                  color: AppColors.error,
                ),
              ],
            ),
          ),

          // ── Messages List ─────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : RefreshIndicator(
                    onRefresh: _loadMessages,
                    color: AppColors.primary,
                    backgroundColor: AppColors.surface,
                    child: filtered.isEmpty
                        ? _buildEmpty()
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: filtered.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 12),
                            itemBuilder: (_, i) => _buildMessageCard(filtered[i]),
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label, {Color? color}) {
    final selected = _filter == value;
    return GestureDetector(
      onTap: () => setState(() => _filter = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? (color ?? AppColors.primary).withValues(alpha: 0.2)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? (color ?? AppColors.primary) : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? (color ?? AppColors.primary) : AppColors.textSecondary,
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildMessageCard(Map<String, dynamic> msg) {
    final status = msg['status'] ?? 'pending';
    final content = msg['content'] ?? 'No content';
    final aiResponse = msg['ai_response'];
    final color = _getStatusColor(status);
    final dateStr = msg['created_at'];
    final date = dateStr != null ? DateTime.tryParse(dateStr)?.toLocal() : null;
    final isPending = status == 'pending';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPending ? AppColors.warning.withValues(alpha: 0.5) : AppColors.border,
          width: isPending ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Status badge + Timestamp
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isPending
                          ? Icons.hourglass_top_rounded
                          : status == 'approved'
                              ? Icons.check_circle_rounded
                              : Icons.cancel_rounded,
                      size: 13,
                      color: color,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () => context.push('/inspector', extra: msg),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.search_rounded, size: 12, color: AppColors.primaryGlow),
                          SizedBox(width: 4),
                          Text(
                            'Inspect',
                            style: TextStyle(
                              color: AppColors.primaryGlow,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (date != null)
                    Text(
                      '${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Message Content
          Text(
            content,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),

          // AI Response (if approved or rejected)
          if (aiResponse != null && aiResponse.toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    status == 'approved' ? Icons.local_shipping : Icons.block,
                    size: 16,
                    color: color,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      aiResponse.toString(),
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // ── ACTION BUTTONS FOR PENDING MESSAGES ────────────────────────────
          if (isPending) ...[
            const SizedBox(height: 16),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 12),
            Row(
              children: [
                // REJECT BUTTON
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _rejectMessage(msg),
                    icon: const Icon(Icons.close_rounded, size: 16, color: AppColors.error),
                    label: const Text('Reject', style: TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // APPROVE BUTTON
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approveMessage(msg),
                    icon: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
                    label: const Text('Approve', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.message_outlined, size: 56, color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Messages Yet',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'When messages are routed through AgentBridge,\nthey will appear here for approval.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}
