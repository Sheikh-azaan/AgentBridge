class PermissionRule {
  final String id;
  final String ownerId;
  final String? agentId;
  final String ruleName;
  final String ruleType; // 'system_prompt', 'guardrail', 'action_policy', 'rate_limit'
  final String content;
  final bool isActive;
  final DateTime createdAt;

  PermissionRule({
    required this.id,
    required this.ownerId,
    this.agentId,
    required this.ruleName,
    required this.ruleType,
    required this.content,
    this.isActive = true,
    required this.createdAt,
  });

  factory PermissionRule.fromMap(Map<String, dynamic> map) {
    return PermissionRule(
      id: map['id'] ?? '',
      ownerId: map['owner_id'] ?? '',
      agentId: map['agent_id'],
      ruleName: map['rule_name'] ?? map['title'] ?? 'Rule',
      ruleType: map['rule_type'] ?? 'guardrail',
      content: map['content'] ?? '',
      isActive: map['is_active'] ?? true,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'owner_id': ownerId,
      'agent_id': agentId,
      'rule_name': ruleName,
      'rule_type': ruleType,
      'content': content,
      'is_active': isActive,
    };
  }
}
