class Agent {
  final String id;
  final String ownerId;
  final String name;
  final String? description;
  final String? apiEndpoint;
  final bool isActive;
  final DateTime createdAt;

  Agent({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description,
    this.apiEndpoint,
    this.isActive = true,
    required this.createdAt,
  });

  factory Agent.fromMap(Map<String, dynamic> map) {
    return Agent(
      id: map['id'] ?? '',
      ownerId: map['owner_id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'],
      apiEndpoint: map['api_endpoint'],
      isActive: map['is_active'] ?? true,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'owner_id': ownerId,
      'name': name,
      'description': description,
      'api_endpoint': apiEndpoint,
      'is_active': isActive,
    };
  }
}
