import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/agent.dart';
import 'dashboard_provider.dart';

class AgentsNotifier extends AsyncNotifier<List<Agent>> {
  @override
  FutureOr<List<Agent>> build() async {
    final service = ref.watch(supabaseServiceProvider);
    return service.getAgents();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(supabaseServiceProvider);
      return service.getAgents();
    });
  }

  Future<void> toggleAgent(String agentId, bool isActive) async {
    final service = ref.read(supabaseServiceProvider);
    await service.updateAgent(id: agentId, isActive: isActive);
    await refresh();
    ref.invalidate(dashboardStatsProvider);
  }

  Future<void> deleteAgent(String agentId) async {
    final service = ref.read(supabaseServiceProvider);
    await service.deleteAgent(agentId);
    await refresh();
    ref.invalidate(dashboardStatsProvider);
  }
}

final agentsNotifierProvider = AsyncNotifierProvider<AgentsNotifier, List<Agent>>(AgentsNotifier.new);
