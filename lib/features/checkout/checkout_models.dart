/// Checkout and order types mirroring the backend's OrderDtos and AddressController. Money is rupees.
library;

double _money(Object? value) => (value as num).toDouble();

double? _moneyOrNull(Object? value) => value == null ? null : (value as num).toDouble();

class QuoteLine {
  const QuoteLine({
    required this.productId,
    required this.name,
    required this.quantity,
    required this.basePrice,
    required this.pricePerCase,
    required this.lineTotal,
    required this.saving,
    required this.stockAvailable,
    required this.problem,
  });

  final String productId;
  final String name;
  final int quantity;
  final double basePrice;
  final double pricePerCase;
  final double lineTotal;
  final double saving;
  final int stockAvailable;
  final String? problem;

  factory QuoteLine.fromJson(Map<String, dynamic> json) => QuoteLine(
        productId: json['productId'] as String,
        name: json['name'] as String,
        quantity: json['quantity'] as int,
        basePrice: _money(json['basePrice']),
        pricePerCase: _money(json['pricePerCase']),
        lineTotal: _money(json['lineTotal']),
        saving: _money(json['saving']),
        stockAvailable: json['stockAvailable'] as int,
        problem: json['problem'] as String?,
      );
}

class CreditInfo {
  const CreditInfo({required this.limit, required this.outstanding, required this.available});

  final double limit;
  final double outstanding;
  final double available;

  factory CreditInfo.fromJson(Map<String, dynamic> json) => CreditInfo(
        limit: _money(json['limit']),
        outstanding: _money(json['outstanding']),
        available: _money(json['available']),
      );
}

/// The server's price for the cart. The app shows these numbers; it never adds prices up itself.
class Quote {
  const Quote({
    required this.lines,
    required this.totalCases,
    required this.subtotal,
    required this.couponCode,
    required this.couponDiscount,
    required this.couponProblem,
    required this.deliveryCharge,
    required this.amountForFreeDelivery,
    required this.total,
    required this.storeOpen,
    required this.upiId,
    required this.credit,
    required this.problems,
    required this.canPlaceOrder,
  });

  final List<QuoteLine> lines;
  final int totalCases;
  final double subtotal;
  final String? couponCode;
  final double couponDiscount;
  final String? couponProblem;
  final double deliveryCharge;
  final double? amountForFreeDelivery;
  final double total;
  final bool storeOpen;
  final String upiId;
  final CreditInfo? credit;
  final List<String> problems;
  final bool canPlaceOrder;

  /// The coupon to send with the order: only one the server accepted.
  String? get appliedCoupon => couponCode != null && couponProblem == null ? couponCode : null;

  QuoteLine? lineFor(String productId) => lines.where((l) => l.productId == productId).firstOrNull;

  factory Quote.fromJson(Map<String, dynamic> json) => Quote(
        lines: (json['lines'] as List<dynamic>).map((e) => QuoteLine.fromJson(e as Map<String, dynamic>)).toList(),
        totalCases: json['totalCases'] as int,
        subtotal: _money(json['subtotal']),
        couponCode: json['couponCode'] as String?,
        couponDiscount: _money(json['couponDiscount']),
        couponProblem: json['couponProblem'] as String?,
        deliveryCharge: _money(json['deliveryCharge']),
        amountForFreeDelivery: _moneyOrNull(json['amountForFreeDelivery']),
        total: _money(json['total']),
        storeOpen: json['storeOpen'] as bool,
        upiId: json['upiId'] as String? ?? '',
        credit: json['credit'] == null ? null : CreditInfo.fromJson(json['credit'] as Map<String, dynamic>),
        problems: (json['problems'] as List<dynamic>).cast<String>(),
        canPlaceOrder: json['canPlaceOrder'] as bool,
      );
}

class Address {
  const Address({
    required this.id,
    required this.label,
    required this.fullName,
    required this.phone,
    required this.addressLine1,
    required this.addressLine2,
    required this.city,
    required this.state,
    required this.pincode,
    required this.isDefault,
  });

  final String id;
  final String label;
  final String fullName;
  final String phone;
  final String addressLine1;
  final String? addressLine2;
  final String city;
  final String state;
  final String pincode;
  final bool isDefault;

  String get oneLine => [addressLine1, ?addressLine2, '$city $pincode'].join(', ');

  factory Address.fromJson(Map<String, dynamic> json) => Address(
        id: json['id'] as String,
        label: json['label'] as String,
        fullName: json['fullName'] as String,
        phone: json['phone'] as String,
        addressLine1: json['addressLine1'] as String,
        addressLine2: json['addressLine2'] as String?,
        city: json['city'] as String,
        state: json['state'] as String,
        pincode: json['pincode'] as String,
        isDefault: json['isDefault'] as bool,
      );
}

enum PaymentMethod {
  cod('COD', 'Cash on delivery'),
  upi('UPI', 'UPI'),
  credit('CREDIT', 'Credit');

  const PaymentMethod(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static PaymentMethod? fromApi(String? value) => PaymentMethod.values.where((m) => m.apiValue == value).firstOrNull;
}

/// Order status as the shop owner sees it.
enum OrderStatus {
  placed('PLACED', 'Placed'),
  confirmed('CONFIRMED', 'Confirmed'),
  processing('PROCESSING', 'Processing'),
  packed('PACKED', 'Packed'),
  shipped('SHIPPED', 'Shipped'),
  outForDelivery('OUT_FOR_DELIVERY', 'Out for delivery'),
  delivered('DELIVERED', 'Delivered'),
  cancelled('CANCELLED', 'Cancelled'),
  returned('RETURNED', 'Returned');

  const OrderStatus(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static OrderStatus fromApi(String value) =>
      OrderStatus.values.firstWhere((s) => s.apiValue == value, orElse: () => OrderStatus.placed);
}

String paymentStatusLabel(String status) => switch (status) {
      'PENDING' => 'Payment pending',
      'PENDING_VERIFICATION' => 'Payment being checked',
      'PAID' => 'Paid',
      'FAILED' => 'Payment failed',
      'REFUNDED' => 'Refunded',
      _ => status,
    };

class OrderSummary {
  const OrderSummary({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.total,
    required this.totalCases,
    required this.createdAt,
  });

  final String id;
  final String orderNumber;
  final OrderStatus status;
  final String paymentMethod;
  final String paymentStatus;
  final double total;
  final int totalCases;
  final DateTime createdAt;

  factory OrderSummary.fromJson(Map<String, dynamic> json) => OrderSummary(
        id: json['id'] as String,
        orderNumber: json['orderNumber'] as String,
        status: OrderStatus.fromApi(json['status'] as String),
        paymentMethod: json['paymentMethod'] as String,
        paymentStatus: json['paymentStatus'] as String,
        total: _money(json['total']),
        totalCases: json['totalCases'] as int,
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      );
}

class OrderItem {
  const OrderItem({required this.productName, required this.quantity, required this.price, required this.total});

  final String productName;
  final int quantity;
  final double price;
  final double total;

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
        productName: json['productName'] as String,
        quantity: json['quantity'] as int,
        price: _money(json['price']),
        total: _money(json['total']),
      );
}

class OrderDetail {
  const OrderDetail({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.paymentMethod,
    required this.paymentStatus,
    required this.paymentTerms,
    required this.subtotal,
    required this.couponCode,
    required this.discount,
    required this.deliveryCharge,
    required this.total,
    required this.totalCases,
    required this.address,
    required this.notes,
    required this.createdAt,
    required this.items,
  });

  final String id;
  final String orderNumber;
  final OrderStatus status;
  final String paymentMethod;
  final String paymentStatus;
  final String paymentTerms;
  final double subtotal;
  final String? couponCode;
  final double discount;
  final double deliveryCharge;
  final double total;
  final int totalCases;
  final Map<String, dynamic>? address;
  final String? notes;
  final DateTime createdAt;
  final List<OrderItem> items;

  factory OrderDetail.fromJson(Map<String, dynamic> json) => OrderDetail(
        id: json['id'] as String,
        orderNumber: json['orderNumber'] as String,
        status: OrderStatus.fromApi(json['status'] as String),
        paymentMethod: json['paymentMethod'] as String,
        paymentStatus: json['paymentStatus'] as String,
        paymentTerms: json['paymentTerms'] as String,
        subtotal: _money(json['subtotal']),
        couponCode: json['couponCode'] as String?,
        discount: _money(json['discount']),
        deliveryCharge: _money(json['deliveryCharge']),
        total: _money(json['total']),
        totalCases: json['totalCases'] as int,
        address: json['address'] as Map<String, dynamic>?,
        notes: json['notes'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
        items: (json['items'] as List<dynamic>).map((e) => OrderItem.fromJson(e as Map<String, dynamic>)).toList(),
      );
}
