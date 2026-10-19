import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/agent.dart';
import 'permission_gate.dart';

class RoutingEngine {
  final _supabase = Supabase.instance.client;
  final _gate = PermissionGate();

  Future<String?> route({
    required String userMessage,
    String? agentId,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return null;

    String? targetAgentId = agentId;

    if (targetAgentId == null) {
      final agent = await _pickBestAgent(uid, userMessage);
      if (agent == null) {
        debugPrint('[RoutingEngine] No active agents found for user $uid');
        return 'No active agents registered. Please add an agent first.';
      }
      targetAgentId = agent.id;
      debugPrint('[RoutingEngine] Auto-selected agent: ${agent.name} ($targetAgentId)');
    }

    return _gate.processMessage(
      agentId: targetAgentId,
      userMessage: userMessage,
    );
  }

  Future<Agent?> _pickBestAgent(String uid, String message) async {
    try {
      final response = await _supabase
          .from('agents')
          .select()
          .eq('owner_id', uid)
          .eq('is_active', true)
          .order('created_at', ascending: true)
          .limit(1);

      final List data = response as List;
      if (data.isEmpty) return null;

      return Agent.fromMap(data.first);
    } catch (e) {
      debugPrint('[RoutingEngine] Error picking agent: $e');
      return null;
    }
  }

  Future<List<Agent>> getActiveAgents() async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return [];

    try {
      final response = await _supabase
          .from('agents')
          .select()
          .eq('owner_id', uid)
          .eq('is_active', true)
          .order('created_at', ascending: false);

      return (response as List).map((e) => Agent.fromMap(e)).toList();
    } catch (e) {
      debugPrint('[RoutingEngine] Error fetching agents: $e');
      return [];
    }
  }
}
