class Order {
  final String id;
  final String productId;
  final String productTitle;
  final String buyerName;
  final String buyerEmail;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String status;
  final String createdAt;

  const Order({
    required this.id,
    required this.productId,
    required this.productTitle,
    required this.buyerName,
    required this.buyerEmail,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    required this.status,
    required this.createdAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] as String,
        productId: json['product_id'] as String,
        productTitle: json['product_title'] as String,
        buyerName: json['buyer_name'] as String,
        buyerEmail: json['buyer_email'] as String,
        quantity: json['quantity'] as int,
        unitPrice: (json['unit_price'] as num).toDouble(),
        totalPrice: (json['total_price'] as num).toDouble(),
        status: json['status'] as String,
        createdAt: json['created_at'] as String,
      );
}
