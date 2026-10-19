import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/bridge_message.dart';
import 'dashboard_provider.dart';

class MessagesNotifier extends AsyncNotifier<List<BridgeMessage>> {
  @override
  FutureOr<List<BridgeMessage>> build() async {
    final service = ref.watch(supabaseServiceProvider);
    return service.getMessages();
  }

  Future<void> refresh([String? status]) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(supabaseServiceProvider);
      return service.getMessages(status: status);
    });
  }

  Future<void> updateStatus(String messageId, String status, {String? aiResponse}) async {
    final service = ref.read(supabaseServiceProvider);
    await service.updateMessageStatus(
      id: messageId,
      status: status,
      aiResponse: aiResponse,
    );
    await refresh();
    ref.invalidate(dashboardStatsProvider);
  }
}

final messagesNotifierProvider = AsyncNotifierProvider<MessagesNotifier, List<BridgeMessage>>(MessagesNotifier.new);
