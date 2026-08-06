class CheckoutPreviewModel {
  const CheckoutPreviewModel({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPriceMad,
    required this.subtotalMad,
    required this.deliveryFeeMad,
    required this.taxMad,
    required this.totalMad,
    required this.deliveryMethod,
    required this.deliveryAvailable,
    required this.pickupOnly,
    required this.taxEnabled,
    required this.stockAvailable,
  });

  final String productId;
  final String productName;
  final int quantity;
  final double unitPriceMad;
  final double subtotalMad;
  final double deliveryFeeMad;
  final double taxMad;
  final double totalMad;
  final String deliveryMethod;
  final bool deliveryAvailable;
  final bool pickupOnly;
  final bool taxEnabled;
  final int stockAvailable;

  factory CheckoutPreviewModel.fromJson(Map<String, dynamic> json) {
    return CheckoutPreviewModel(
      productId: json['product_id'] as String,
      productName: json['product_name'] as String,
      quantity: json['quantity'] as int,
      unitPriceMad: (json['unit_price_mad'] as num).toDouble(),
      subtotalMad: (json['subtotal_mad'] as num).toDouble(),
      deliveryFeeMad: (json['delivery_fee_mad'] as num).toDouble(),
      taxMad: (json['tax_mad'] as num).toDouble(),
      totalMad: (json['total_mad'] as num).toDouble(),
      deliveryMethod: json['delivery_method'] as String,
      deliveryAvailable: json['delivery_available'] as bool,
      pickupOnly: json['pickup_only'] as bool,
      taxEnabled: json['tax_enabled'] as bool,
      stockAvailable: json['stock_available'] as int,
    );
  }
}

class CheckoutSessionModel {
  const CheckoutSessionModel({
    required this.orderId,
    required this.checkoutUrl,
    required this.sessionId,
  });

  final String orderId;
  final String checkoutUrl;
  final String sessionId;

  factory CheckoutSessionModel.fromJson(Map<String, dynamic> json) {
    return CheckoutSessionModel(
      orderId: json['order_id'] as String,
      checkoutUrl: json['checkout_url'] as String,
      sessionId: json['session_id'] as String,
    );
  }
}

class PurchaseOrderModel {
  const PurchaseOrderModel({
    required this.id,
    required this.orderNumber,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.subtotalMad,
    required this.deliveryFeeMad,
    required this.taxMad,
    required this.totalMad,
    required this.deliveryMethod,
    required this.paymentStatus,
    required this.orderStatus,
    required this.receiptNumber,
    this.buyerName = '',
    this.buyerPhone = '',
    this.buyerAddress = '',
    this.sellerBusinessName,
    this.buyerEmail,
    this.paidAt,
    required this.createdAt,
  });

  final String id;
  final String orderNumber;
  final String productId;
  final String productName;
  final int quantity;
  final double subtotalMad;
  final double deliveryFeeMad;
  final double taxMad;
  final double totalMad;
  final String deliveryMethod;
  final String paymentStatus;
  final String orderStatus;
  final String receiptNumber;
  final String buyerName;
  final String buyerPhone;
  final String buyerAddress;
  final String? sellerBusinessName;
  final String? buyerEmail;
  final DateTime? paidAt;
  final DateTime createdAt;

  bool get isPaid => paymentStatus == 'paid';
  bool get isPickup => deliveryMethod == 'pickup';

  factory PurchaseOrderModel.fromJson(Map<String, dynamic> json) {
    return PurchaseOrderModel(
      id: json['id'] as String,
      orderNumber: json['order_number'] as String,
      productId: json['product_id'] as String,
      productName: json['product_name'] as String,
      quantity: json['quantity'] as int,
      subtotalMad: (json['subtotal_mad'] as num).toDouble(),
      deliveryFeeMad: (json['delivery_fee_mad'] as num).toDouble(),
      taxMad: (json['tax_mad'] as num).toDouble(),
      totalMad: (json['total_mad'] as num).toDouble(),
      deliveryMethod: json['delivery_method'] as String,
      paymentStatus: json['payment_status'] as String,
      orderStatus: json['order_status'] as String,
      receiptNumber: json['receipt_number'] as String? ?? '',
      buyerName: json['buyer_name'] as String? ?? '',
      buyerPhone: json['buyer_phone'] as String? ?? '',
      buyerAddress: json['buyer_address'] as String? ?? '',
      sellerBusinessName: json['seller_business_name'] as String?,
      buyerEmail: json['buyer_email'] as String?,
      paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at'] as String) : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class PurchaseReceiptModel {
  const PurchaseReceiptModel({
    required this.receiptNumber,
    required this.orderNumber,
    required this.issuedAt,
    required this.receiptText,
    required this.totalMad,
  });

  final String receiptNumber;
  final String orderNumber;
  final DateTime issuedAt;
  final String receiptText;
  final double totalMad;

  factory PurchaseReceiptModel.fromJson(Map<String, dynamic> json) {
    return PurchaseReceiptModel(
      receiptNumber: json['receipt_number'] as String,
      orderNumber: json['order_number'] as String,
      issuedAt: DateTime.parse(json['issued_at'] as String),
      receiptText: json['receipt_text'] as String,
      totalMad: (json['total_mad'] as num).toDouble(),
    );
  }
}
