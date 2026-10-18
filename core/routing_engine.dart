import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/agent.dart';
import 'permission_gate.dart';

/// RoutingEngine
/// ─────────────────────────────────────────────────────────────────────────────
/// Finds the best active agent for a given message, then hands off to
/// PermissionGate to enforce rules and call the AI API.
/// ─────────────────────────────────────────────────────────────────────────────
class RoutingEngine {
  final _supabase = Supabase.instance.client;
  final _gate = PermissionGate();

  /// Route a user message:
  /// - If [agentId] is provided → send directly to that agent
  /// - Otherwise → pick the first active agent owned by the user
  ///
  /// Returns the AI reply text, or null on failure.
  Future<String?> route({
    required String userMessage,
    String? agentId,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) return null;

    // ── Resolve target agent ─────────────────────────────────────────────────
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

    // ── Hand off to PermissionGate ───────────────────────────────────────────
    return _gate.processMessage(
      agentId: targetAgentId,
      userMessage: userMessage,
    );
  }

  /// Picks the best agent:
  /// Currently picks the first active agent. Can be extended with
  /// keyword matching, intent classification, or round-robin logic.
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

  /// Get all active agents for the current user
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
