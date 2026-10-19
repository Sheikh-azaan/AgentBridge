class Order {
  final String id;
  final String ownerId;
  final String customerName;
  final String orderNumber;
  final String productName;
  final String? trackingNumber;
  final String? courier;
  final String status;
  final String? shippingAddress;
  final DateTime? estimatedDelivery;
  final DateTime createdAt;

  Order({
    required this.id,
    required this.ownerId,
    required this.customerName,
    required this.orderNumber,
    required this.productName,
    this.trackingNumber,
    this.courier,
    required this.status,
    this.shippingAddress,
    this.estimatedDelivery,
    required this.createdAt,
  });

  factory Order.fromMap(Map<String, dynamic> map) {
    return Order(
      id: map['id'] ?? '',
      ownerId: map['owner_id'] ?? '',
      customerName: map['customer_name'] ?? '',
      orderNumber: map['order_number'] ?? '',
      productName: map['product_name'] ?? '',
      trackingNumber: map['tracking_number'],
      courier: map['courier'],
      status: map['status'] ?? 'pending',
      shippingAddress: map['shipping_address'],
      estimatedDelivery: map['estimated_delivery'] != null
          ? DateTime.tryParse(map['estimated_delivery'])
          : null,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }

  String toPromptString() {
    return '''
Order Number : $orderNumber
Product      : $productName
Status       : $status
Tracking No  : ${trackingNumber ?? 'Not assigned yet'}
Courier      : ${courier ?? 'Not assigned yet'}
ETA          : ${estimatedDelivery != null ? estimatedDelivery!.toLocal().toString().split(' ')[0] : 'TBD'}
Address      : ${shippingAddress ?? 'N/A'}
''';
  }
}
