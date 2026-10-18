import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../theme/app_colors.dart';

class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _logs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAuditLogs();
  }

  Future<void> _loadAuditLogs() async {
    setState(() => _loading = true);
    try {
      final uid = _supabase.auth.currentUser?.id;
      if (uid == null) return;
      
      final data = await _supabase
          .from('audit_logs')
          .select()
          .eq('owner_id', uid)
          .order('created_at', ascending: false);
          
      if (mounted) {
        setState(() {
          _logs = List<Map<String, dynamic>>.from(data);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading audit logs: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  IconData _getIconForAction(String? action) {
    switch (action) {
      case 'agent_created':
        return Icons.smart_toy_rounded;
      case 'agent_deleted':
        return Icons.delete_outline_rounded;
      case 'message_routed':
        return Icons.route_rounded;
      case 'rule_created':
        return Icons.rule_rounded;
      case 'login':
        return Icons.login_rounded;
      default:
        return Icons.history_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
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
          'Audit Log',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : RefreshIndicator(
              onRefresh: _loadAuditLogs,
              color: AppColors.primary,
              backgroundColor: AppColors.surface,
              child: _logs.isEmpty
                  ? _buildEmpty()
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _logs.length,
                      itemBuilder: (_, i) => _buildLogTile(_logs[i]),
                    ),
            ),
    );
  }

  Widget _buildLogTile(Map<String, dynamic> log) {
    final action = log['action'] ?? 'unknown_action';
    final desc = log['description'] ?? 'No details provided';
    final dateStr = log['created_at'];
    final date = dateStr != null ? DateTime.tryParse(dateStr)?.toLocal() : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.textSecondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_getIconForAction(action), color: AppColors.textSecondary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      action.toString().replaceAll('_', ' ').toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (date != null)
                      Text(
                        '${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  desc,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.4),
                ),
              ],
            ),
          ),
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
            child: const Icon(Icons.history_rounded, size: 56, color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Activity Found',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Important events and actions\nwill appear in this audit log.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }
}
