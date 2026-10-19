import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/agent.dart';
import '../models/order.dart';
import '../models/permission_rule.dart';
import '../models/bridge_message.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient get client => Supabase.instance.client;
  String? get currentUserId => client.auth.currentUser?.id;

  Future<Map<String, int>> getDashboardStats() async {
    final uid = currentUserId;
    if (uid == null) {
      return {'agents': 0, 'pending': 0, 'approved': 0, 'rejected': 0};
    }

    try {
      final agentsResponse = await client
          .from('agents')
          .select('id')
          .eq('owner_id', uid)
          .eq('is_active', true);
      final int agentsCount = (agentsResponse as List).length;

      final messagesResponse = await client
          .from('messages')
          .select('status')
          .eq('owner_id', uid);
      final msgs = messagesResponse as List;

      return {
        'agents': agentsCount,
        'pending': msgs.where((m) => m['status'] == 'pending').length,
        'approved': msgs.where((m) => m['status'] == 'approved').length,
        'rejected': msgs.where((m) => m['status'] == 'rejected').length,
      };
    } catch (e) {
      debugPrint('[SupabaseService] getDashboardStats error: $e');
      return {'agents': 0, 'pending': 0, 'approved': 0, 'rejected': 0};
    }
  }

  Future<List<Agent>> getAgents({bool onlyActive = false}) async {
    final uid = currentUserId;
    if (uid == null) return [];

    try {
      var query = client.from('agents').select().eq('owner_id', uid);
      if (onlyActive) {
        query = query.eq('is_active', true);
      }
      final response = await query.order('created_at', ascending: false);
      return (response as List).map((e) => Agent.fromMap(e)).toList();
    } catch (e) {
      debugPrint('[SupabaseService] getAgents error: $e');
      return [];
    }
  }

  Future<Agent?> getAgentById(String agentId) async {
    try {
      final response = await client
          .from('agents')
          .select()
          .eq('id', agentId)
          .maybeSingle();
      if (response == null) return null;
      return Agent.fromMap(response);
    } catch (e) {
      debugPrint('[SupabaseService] getAgentById error: $e');
      return null;
    }
  }

  Future<Agent?> createAgent({
    required String name,
    String? description,
    String? apiEndpoint,
    bool isActive = true,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('User not authenticated');

    try {
      final data = await client.from('agents').insert({
        'owner_id': uid,
        'name': name,
        'description': description,
        'api_endpoint': apiEndpoint,
        'is_active': isActive,
      }).select().single();

      await logAudit(
        action: 'agent_created',
        description: 'Created agent: $name',
      );

      return Agent.fromMap(data);
    } catch (e) {
      debugPrint('[SupabaseService] createAgent error: $e');
      rethrow;
    }
  }

  Future<void> updateAgent({
    required String id,
    String? name,
    String? description,
    String? apiEndpoint,
    bool? isActive,
  }) async {
    try {
      final updates = <String, dynamic>{};
      if (name != null) updates['name'] = name;
      if (description != null) updates['description'] = description;
      if (apiEndpoint != null) updates['api_endpoint'] = apiEndpoint;
      if (isActive != null) updates['is_active'] = isActive;

      if (updates.isNotEmpty) {
        await client.from('agents').update(updates).eq('id', id);
        await logAudit(
          action: 'agent_updated',
          description: 'Updated agent: $id',
        );
      }
    } catch (e) {
      debugPrint('[SupabaseService] updateAgent error: $e');
      rethrow;
    }
  }

  Future<void> deleteAgent(String id) async {
    try {
      await client.from('agents').delete().eq('id', id);
      await logAudit(
        action: 'agent_deleted',
        description: 'Deleted agent: $id',
      );
    } catch (e) {
      debugPrint('[SupabaseService] deleteAgent error: $e');
      rethrow;
    }
  }

  Future<List<BridgeMessage>> getMessages({String? status, int limit = 50}) async {
    final uid = currentUserId;
    if (uid == null) return [];

    try {
      var query = client.from('messages').select().eq('owner_id', uid);
      if (status != null && status.isNotEmpty && status != 'all') {
        query = query.eq('status', status);
      }
      final response = await query.order('created_at', ascending: false).limit(limit);
      return (response as List).map((e) => BridgeMessage.fromMap(e)).toList();
    } catch (e) {
      debugPrint('[SupabaseService] getMessages error: $e');
      return [];
    }
  }

  Future<BridgeMessage?> saveMessage({
    required String content,
    String? agentId,
    String? aiResponse,
    String status = 'pending',
  }) async {
    final uid = currentUserId;
    if (uid == null) return null;

    try {
      final response = await client.from('messages').insert({
        'owner_id': uid,
        'agent_id': agentId,
        'content': content,
        'ai_response': aiResponse,
        'status': status,
      }).select().single();

      return BridgeMessage.fromMap(response);
    } catch (e) {
      debugPrint('[SupabaseService] saveMessage error: $e');
      return null;
    }
  }

  Future<void> updateMessageStatus({
    required String id,
    required String status,
    String? aiResponse,
  }) async {
    try {
      final updates = <String, dynamic>{'status': status};
      if (aiResponse != null) updates['ai_response'] = aiResponse;

      await client.from('messages').update(updates).eq('id', id);
      await logAudit(
        action: 'message_$status',
        description: 'Message $id marked as $status',
      );
    } catch (e) {
      debugPrint('[SupabaseService] updateMessageStatus error: $e');
      rethrow;
    }
  }

  Future<List<PermissionRule>> getRules({String? agentId, String? ruleType}) async {
    final uid = currentUserId;
    if (uid == null) return [];

    try {
      var query = client.from('rules').select().eq('owner_id', uid);
      if (agentId != null) query = query.eq('agent_id', agentId);
      if (ruleType != null && ruleType != 'All') query = query.eq('rule_type', ruleType);

      final response = await query.order('created_at', ascending: false);
      return (response as List).map((e) => PermissionRule.fromMap(e)).toList();
    } catch (e) {
      debugPrint('[SupabaseService] getRules error: $e');
      return [];
    }
  }

  Future<PermissionRule?> createRule({
    required String ruleName,
    required String ruleType,
    required String content,
    String? agentId,
    bool isActive = true,
  }) async {
    final uid = currentUserId;
    if (uid == null) throw Exception('User not authenticated');

    try {
      final response = await client.from('rules').insert({
        'owner_id': uid,
        'agent_id': agentId,
        'rule_name': ruleName,
        'rule_type': ruleType,
        'content': content,
        'is_active': isActive,
      }).select().single();

      await logAudit(
        action: 'rule_created',
        description: 'Created rule: $ruleName ($ruleType)',
      );

      return PermissionRule.fromMap(response);
    } catch (e) {
      debugPrint('[SupabaseService] createRule error: $e');
      rethrow;
    }
  }

  Future<void> toggleRuleStatus(String ruleId, bool isActive) async {
    try {
      await client.from('rules').update({'is_active': isActive}).eq('id', ruleId);
    } catch (e) {
      debugPrint('[SupabaseService] toggleRuleStatus error: $e');
      rethrow;
    }
  }

  Future<void> deleteRule(String ruleId) async {
    try {
      await client.from('rules').delete().eq('id', ruleId);
      await logAudit(
        action: 'rule_deleted',
        description: 'Deleted rule: $ruleId',
      );
    } catch (e) {
      debugPrint('[SupabaseService] deleteRule error: $e');
      rethrow;
    }
  }

  Future<List<Order>> getOrders({int limit = 50}) async {
    final uid = currentUserId;
    try {
      var query = client.from('orders').select();
      if (uid != null) {
        query = query.eq('owner_id', uid);
      }
      final response = await query.order('created_at', ascending: false).limit(limit);
      return (response as List).map((e) => Order.fromMap(e)).toList();
    } catch (e) {
      debugPrint('[SupabaseService] getOrders error: $e');
      return [];
    }
  }

  Future<Order?> insertOrder({
    required String customerName,
    required String orderNumber,
    required String productName,
    String? trackingNumber,
    String? courier,
    String status = 'pending',
    String? shippingAddress,
    DateTime? estimatedDelivery,
  }) async {
    final uid = currentUserId;
    if (uid == null) return null;

    try {
      final response = await client.from('orders').insert({
        'owner_id': uid,
        'customer_name': customerName,
        'order_number': orderNumber,
        'product_name': productName,
        'tracking_number': trackingNumber,
        'courier': courier,
        'status': status,
        'shipping_address': shippingAddress,
        'estimated_delivery': estimatedDelivery?.toIso8601String(),
      }).select().single();

      return Order.fromMap(response);
    } catch (e) {
      debugPrint('[SupabaseService] insertOrder error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getAuditLogs({int limit = 50}) async {
    final uid = currentUserId;
    if (uid == null) return [];

    try {
      final response = await client
          .from('audit_logs')
          .select()
          .eq('owner_id', uid)
          .order('created_at', ascending: false)
          .limit(limit);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('[SupabaseService] getAuditLogs error: $e');
      return [];
    }
  }

  Future<void> logAudit({
    required String action,
    required String description,
    Map<String, dynamic>? metadata,
  }) async {
    final uid = currentUserId;
    if (uid == null) return;

    try {
      await client.from('audit_logs').insert({
        'owner_id': uid,
        'action': action,
        'description': description,
        'metadata': metadata ?? {},
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('[SupabaseService] logAudit error (non-fatal): $e');
    }
  }
}
