class BridgeMessage {
  final String id;
  final String ownerId;
  final String? agentId;
  final String content;
  final String? aiResponse;
  final String status;
  final DateTime createdAt;

  BridgeMessage({
    required this.id,
    required this.ownerId,
    this.agentId,
    required this.content,
    this.aiResponse,
    this.status = 'pending',
    required this.createdAt,
  });

  factory BridgeMessage.fromMap(Map<String, dynamic> map) {
    return BridgeMessage(
      id: map['id'] ?? '',
      ownerId: map['owner_id'] ?? '',
      agentId: map['agent_id'],
      content: map['content'] ?? '',
      aiResponse: map['ai_response'],
      status: map['status'] ?? 'pending',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'owner_id': ownerId,
      'agent_id': agentId,
      'content': content,
      'ai_response': aiResponse,
      'status': status,
    };
  }
}
