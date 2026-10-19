import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/bridge_protocol.dart';
import '../../core/delivery_agent.dart';
import '../../core/shopping_agent.dart';
import '../../theme/app_colors.dart';
import 'widgets/payload_viewer.dart';
import 'widgets/permission_actions.dart';
import 'widgets/pipeline_step.dart';

class InspectorScreen extends StatefulWidget {
  final Map<String, dynamic>? initialMessage;
  final String? messageId;

  const InspectorScreen({
    super.key,
    this.initialMessage,
    this.messageId,
  });

  @override
  State<InspectorScreen> createState() => _InspectorScreenState();
}

class _InspectorScreenState extends State<InspectorScreen> {
  final _supabase = Supabase.instance.client;
  final _deliveryAgent = DeliveryAgent();
  final _shoppingAgent = ShoppingAgent();

  Map<String, dynamic>? _currentMessage;
  List<Map<String, dynamic>> _allMessages = [];
  bool _loading = true;
  bool _actionInProgress = false;

  @override
  void initState() {
    super.initState();
    _initMessage();
  }

  Future<void> _initMessage() async {
    setState(() => _loading = true);

    if (widget.initialMessage != null) {
      _currentMessage = Map<String, dynamic>.from(widget.initialMessage!);
      await _loadAllMessagesList();
      if (mounted) setState(() => _loading = false);
      return;
    }

    if (widget.messageId != null) {
      await _loadMessageById(widget.messageId!);
    } else {
      await _loadLatestMessage();
    }

    await _loadAllMessagesList();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _loadMessageById(String id) async {
    try {
      final res = await _supabase.from('messages').select().eq('id', id).maybeSingle();
      if (res != null && mounted) {
        setState(() => _currentMessage = Map<String, dynamic>.from(res));
      }
    } catch (e) {
      debugPrint('[InspectorScreen] Error loading message by ID: $e');
    }
  }

  Future<void> _loadLatestMessage() async {
    try {
      final uid = _supabase.auth.currentUser?.id;
      var query = _supabase.from('messages').select().order('created_at', ascending: false).limit(1);
      if (uid != null) {
        query = _supabase.from('messages').select().eq('owner_id', uid).order('created_at', ascending: false).limit(1);
      }

      final res = await query;
      final list = res as List;
      if (list.isNotEmpty && mounted) {
        setState(() => _currentMessage = Map<String, dynamic>.from(list.first));
      }
    } catch (e) {
      debugPrint('[InspectorScreen] Error loading latest message: $e');
    }
  }

  Future<void> _loadAllMessagesList() async {
    try {
      final uid = _supabase.auth.currentUser?.id;
      var query = _supabase.from('messages').select().order('created_at', ascending: false).limit(20);
      if (uid != null) {
        query = _supabase.from('messages').select().eq('owner_id', uid).order('created_at', ascending: false).limit(20);
      }

      final res = await query;
      if (mounted) {
        setState(() {
          _allMessages = List<Map<String, dynamic>>.from(res as List);
        });
      }
    } catch (e) {
      debugPrint('[InspectorScreen] Error loading messages list: $e');
    }
  }

  Future<void> _refresh() async {
    if (_currentMessage != null && _currentMessage!['id'] != null) {
      await _loadMessageById(_currentMessage!['id']);
    } else {
      await _loadLatestMessage();
    }
    await _loadAllMessagesList();
  }

  Future<void> _approve() async {
    if (_currentMessage == null) return;
    final msgId = _currentMessage!['id'];
    final content = _currentMessage!['content'] ?? '';
    final isDeliveryToShopping = content.contains('Delivery Agent ➔ Shopping Agent');

    setState(() => _actionInProgress = true);

    try {
      if (isDeliveryToShopping) {
        await _shoppingAgent.executeApprovedQueryFromDeliveryAgent(
          messageId: msgId,
          content: content,
        );
      } else {
        await _deliveryAgent.executeApprovedDispatch(
          messageId: msgId,
          content: content,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Approved & Executed! Target agent responded.'),
            backgroundColor: AppColors.success,
          ),
        );
      }
      await _refresh();
    } catch (e) {
      debugPrint('[InspectorScreen] Approval error: $e');
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  Future<void> _reject() async {
    if (_currentMessage == null) return;
    final msgId = _currentMessage!['id'];

    setState(() => _actionInProgress = true);

    try {
      await _supabase.from('messages').update({
        'status': 'rejected',
        'ai_response': '❌ [AgentBridge]: Request rejected by Owner at Permission Gate.',
      }).eq('id', msgId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🛑 Message Rejected. Target agent blocked.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      await _refresh();
    } catch (e) {
      debugPrint('[InspectorScreen] Rejection error: $e');
    } finally {
      if (mounted) setState(() => _actionInProgress = false);
    }
  }

  void _showSwitchMessageSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                child: Row(
                  children: const [
                    Icon(Icons.swap_horiz_rounded, color: AppColors.primary),
                    SizedBox(width: 8),
                    Text(
                      'Select Message to Inspect',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppColors.border, height: 1),
              Expanded(
                child: _allMessages.isEmpty
                    ? const Center(
                        child: Text(
                          'No messages in database.',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _allMessages.length,
                        itemBuilder: (ctx, i) {
                          final msg = _allMessages[i];
                          final isSelected = msg['id'] == _currentMessage?['id'];
                          final status = msg['status'] ?? 'pending';

                          Color statusColor = AppColors.warning;
                          if (status == 'approved') statusColor = AppColors.success;
                          if (status == 'rejected') statusColor = AppColors.error;

                          return ListTile(
                            selected: isSelected,
                            selectedTileColor: AppColors.surface2,
                            leading: Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            title: Text(
                              msg['content'] ?? 'No content',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              'Status: ${status.toUpperCase()} • ID: ${msg['id']?.toString().substring(0, 8) ?? '...'}',
                              style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check, size: 16, color: AppColors.primary)
                                : null,
                            onTap: () {
                              Navigator.pop(ctx);
                              setState(() => _currentMessage = msg);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
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
          children: const [
            Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
            SizedBox(width: 8),
            Text(
              'Message Inspector',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Switch Message',
            icon: const Icon(Icons.swap_vert_rounded, color: AppColors.textSecondary),
            onPressed: _showSwitchMessageSheet,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: AppColors.textSecondary),
            onPressed: _refresh,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _currentMessage == null
              ? _buildEmptyState()
              : _buildInspectorContent(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: const Icon(Icons.find_in_page_outlined, size: 48, color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),
            const Text(
              'No Message Selected',
              style: TextStyle(color: AppColors.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Trigger a message from Shopping Demo or pick one from the list to inspect its pipeline.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _showSwitchMessageSheet,
              icon: const Icon(Icons.list_alt_rounded, size: 16),
              label: const Text('Browse Messages'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInspectorContent() {
    final msg = _currentMessage!;
    final msgId = msg['id'] ?? 'unknown';
    final content = msg['content'] ?? '';
    final aiResponse = msg['ai_response'];
    final status = msg['status'] ?? 'pending';

    final packet = BridgeProtocol.parseSupabaseMessage(content);

    final isDeliveryTarget = packet.toAgent == 'delivery_agent';
    final targetAgentName = isDeliveryTarget ? 'Delivery Agent v2' : 'Shopping Agent v1';
    final targetModel = isDeliveryTarget ? 'Gemini 1.5 Pro' : 'Groq (qwen3.8-27b)';
    final sourceAgentName = packet.fromAgent == 'shopping_agent'
        ? 'Shopping Agent'
        : packet.fromAgent == 'delivery_agent'
            ? 'Delivery Agent'
            : 'Customer / User';

    const step1Status = PipelineStepStatus.completed;
    const step2Status = PipelineStepStatus.completed;
    const step3Status = PipelineStepStatus.completed;

    PipelineStepStatus step4Status;
    PipelineStepStatus step5Status;

    if (status == 'pending') {
      step4Status = PipelineStepStatus.pending;
      step5Status = PipelineStepStatus.skipped;
    } else if (status == 'approved') {
      step4Status = PipelineStepStatus.completed;
      step5Status = PipelineStepStatus.completed;
    } else {
      step4Status = PipelineStepStatus.rejected;
      step5Status = PipelineStepStatus.rejected;
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.primary,
      backgroundColor: AppColors.surface,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.timeline_rounded, color: AppColors.primaryGlow, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MESSAGE #${msgId.toString().substring(0, msgId.toString().length > 8 ? 8 : msgId.toString().length).toUpperCase()}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '$sourceAgentName ➔ $targetAgentName',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(status),
                ],
              ),
            ),
            const SizedBox(height: 20),

            PipelineStepCard(
              stepNumber: 1,
              title: 'Request Received',
              subtitle: 'From: $sourceAgentName (Intent: ${packet.intent.name})',
              status: step1Status,
              icon: Icons.input_rounded,
              content: PayloadViewer(
                label: 'Raw Request Payload',
                payload: content,
              ),
            ),

            PipelineStepCard(
              stepNumber: 2,
              title: 'Payload Normalized',
              subtitle: 'Formatted into universal BridgePacket envelope',
              status: step2Status,
              icon: Icons.transform_rounded,
              content: PayloadViewer(
                label: 'BridgePacket Schema',
                payload: packet.toJson(),
              ),
            ),

            PipelineStepCard(
              stepNumber: 3,
              title: 'Routed to Agent',
              subtitle: 'Target resolved by Routing Engine',
              status: step3Status,
              icon: Icons.alt_route_rounded,
              content: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Icon(
                      isDeliveryTarget ? Icons.local_shipping_outlined : Icons.storefront_outlined,
                      color: AppColors.primaryGlow,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            targetAgentName,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Model: $targetModel • Capabilities: [${isDeliveryTarget ? "orders, tracking" : "catalog, pricing"}]',
                            style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            PipelineStepCard(
              stepNumber: 4,
              title: 'Permission Gate',
              subtitle: 'Human-in-the-loop validation & policy enforcement',
              status: step4Status,
              icon: Icons.verified_user_outlined,
              content: PermissionActions(
                status: status,
                isProcessing: _actionInProgress,
                onApprove: _approve,
                onReject: _reject,
              ),
            ),

            PipelineStepCard(
              stepNumber: 5,
              title: 'Execution & Result',
              subtitle: status == 'approved'
                  ? 'Processed successfully by AI endpoint'
                  : status == 'rejected'
                      ? 'Execution halted by owner'
                      : 'Waiting for permission approval to proceed',
              status: step5Status,
              isLast: true,
              icon: Icons.output_rounded,
              content: aiResponse != null && aiResponse.toString().isNotEmpty
                  ? PayloadViewer(
                      label: 'AI Endpoint Result',
                      payload: aiResponse.toString(),
                      icon: Icons.smart_toy_outlined,
                    )
                  : Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.surface2.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.hourglass_empty_rounded, size: 14, color: AppColors.textMuted),
                          SizedBox(width: 8),
                          Text(
                            'Result pending permission gate approval.',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 11.5),
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color = AppColors.warning;
    IconData icon = Icons.hourglass_top_rounded;

    if (status == 'approved') {
      color = AppColors.success;
      icon = Icons.check_circle_rounded;
    } else if (status == 'rejected') {
      color = AppColors.error;
      icon = Icons.cancel_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
