import 'package:flutter/foundation.dart';

/// Precision of the revenue value reported by AdMob.
enum AdRevenuePrecision {
  unknown,
  estimated,
  publisherProvided,
  precise,
}

/// Domain value object representing impression-level revenue (ILRD/LTV).
@immutable
class AdRevenueValue {
  /// Revenue amount in micro-units (e.g. 1,000,000 micros = $1.00).
  final int micros;

  /// ISO 4217 currency code (e.g. 'USD', 'EUR').
  final String currencyCode;

  /// Precision type of the reported value.
  final AdRevenuePrecision precision;

  const AdRevenueValue({
    required this.micros,
    required this.currencyCode,
    this.precision = AdRevenuePrecision.unknown,
  });

  /// Revenue converted to standard currency units (e.g. 1.25 for $1.25 USD).
  double get value => micros / 1000000.0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdRevenueValue &&
          runtimeType == other.runtimeType &&
          micros == other.micros &&
          currencyCode == other.currencyCode &&
          precision == other.precision;

  @override
  int get hashCode =>
      micros.hashCode ^ currencyCode.hashCode ^ precision.hashCode;

  @override
  String toString() =>
      'AdRevenueValue($value $currencyCode, precision: ${precision.name})';
}
