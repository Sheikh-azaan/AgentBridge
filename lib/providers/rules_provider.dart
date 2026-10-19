import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/permission_rule.dart';
import 'dashboard_provider.dart';

class RulesNotifier extends AsyncNotifier<List<PermissionRule>> {
  @override
  FutureOr<List<PermissionRule>> build() async {
    final service = ref.watch(supabaseServiceProvider);
    return service.getRules();
  }

  Future<void> refresh({String? agentId, String? ruleType}) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(supabaseServiceProvider);
      return service.getRules(agentId: agentId, ruleType: ruleType);
    });
  }

  Future<void> toggleRule(String ruleId, bool isActive) async {
    final service = ref.read(supabaseServiceProvider);
    await service.toggleRuleStatus(ruleId, isActive);
    await refresh();
  }

  Future<void> deleteRule(String ruleId) async {
    final service = ref.read(supabaseServiceProvider);
    await service.deleteRule(ruleId);
    await refresh();
  }
}

final rulesNotifierProvider = AsyncNotifierProvider<RulesNotifier, List<PermissionRule>>(RulesNotifier.new);
