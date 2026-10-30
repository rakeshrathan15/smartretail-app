import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_exception.dart';
import '../../core/providers.dart';

/// The signed-in shop's delivery route, from /api/me/delivery-route.
class MyDeliveryRoute {
  const MyDeliveryRoute({required this.assigned, this.name, this.days = const [], this.nextDeliveryDate});

  final bool assigned;
  final String? name;
  final List<String> days;
  final DateTime? nextDeliveryDate;

  factory MyDeliveryRoute.fromJson(Map<String, dynamic> json) {
    final next = json['nextDeliveryDate'] as String?;
    return MyDeliveryRoute(
      assigned: json['assigned'] as bool? ?? false,
      name: json['name'] as String?,
      days: (json['days'] as List<dynamic>? ?? const []).cast<String>(),
      nextDeliveryDate: next == null ? null : DateTime.parse(next),
    );
  }

  /// "Mon, Thu"
  String get daysLabel => days.map((d) => d.substring(0, 1) + d.substring(1).toLowerCase()).join(', ');

  /// "Thu 5 Nov"
  String? get nextDeliveryLabel {
    final date = nextDeliveryDate;
    if (date == null) return null;
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${weekdays[date.weekday - 1]} ${date.day} ${months[date.month - 1]}';
  }
}

final deliveryRouteProvider = FutureProvider<MyDeliveryRoute>((ref) async {
  try {
    final response = await ref.watch(dioProvider).get<Map<String, dynamic>>('/api/me/delivery-route');
    return MyDeliveryRoute.fromJson(response.data!);
  } on DioException catch (e) {
    throw ApiException.fromDio(e);
  }
});
