import 'api.dart';

class AppleProductMapping {
  const AppleProductMapping._(this.productId, this.planId, this.period);

  final String productId;
  final int planId;
  final String period;
}

class AppleBillingConfig {
  const AppleBillingConfig._({
    required this.enabled,
    required this.configured,
    required this.products,
    required this.preparePath,
    required this.verifyPath,
    required this.environment,
    required this.managementUri,
    required this.accountId,
  });

  factory AppleBillingConfig.parse(dynamic value) {
    if (value is! Json ||
        value['enabled'] is! bool ||
        value['configured'] is! bool ||
        value['account_id'] is! String ||
        (value['account_id'] as String).isEmpty ||
        value['products'] is! Map ||
        !{'Production', 'Sandbox'}.contains(value['environment']) ||
        value['management_url'] !=
            'https://apps.apple.com/account/subscriptions') {
      throw const ClientFailure('invalid_apple_config');
    }
    String path(String key) {
      final path = value[key];
      final expected = key == 'prepare_path'
          ? '/api/v1/zolnit-apple/prepare'
          : '/api/v1/zolnit-apple/verify';
      if (path != expected) {
        throw const ClientFailure('invalid_apple_config');
      }
      return path as String;
    }

    final products = <AppleProductMapping>[];
    final ids = <String>{};
    final mappings = value['products'] as Map;
    if (mappings.length > 256) {
      throw const ClientFailure('invalid_apple_config');
    }
    for (final entry in mappings.entries) {
      final product = entry.value;
      final productId = entry.key;
      if (product is! Json ||
          productId is! String ||
          productId.length > 255 ||
          !RegExp(r'^[A-Za-z0-9._-]+$').hasMatch(productId) ||
          product['plan_id'] is! int ||
          (product['plan_id'] as int) <= 0 ||
          !{
            'monthly',
            'quarterly',
            'half_yearly',
            'yearly',
          }.contains(product['period']) ||
          product['type'] != 'Auto-Renewable Subscription') {
        throw const ClientFailure('invalid_apple_config');
      }
      final id = productId;
      final plan = product['plan_id'] as int;
      final period = product['period'] as String;
      if (!ids.add(id)) {
        throw const ClientFailure('invalid_apple_config');
      }
      products.add(AppleProductMapping._(id, plan, period));
    }
    return AppleBillingConfig._(
      enabled: value['enabled'] as bool,
      configured: value['configured'] as bool,
      products: List.unmodifiable(products),
      preparePath: path('prepare_path'),
      verifyPath: path('verify_path'),
      environment: value['environment'] as String,
      managementUri: Uri.parse(value['management_url'] as String),
      accountId: value['account_id'] as String,
    );
  }

  final bool enabled;
  final bool configured;
  final List<AppleProductMapping> products;
  final String preparePath;
  final String verifyPath;
  final String environment;
  final Uri managementUri;
  final String accountId;

  bool get available => enabled && configured && products.isNotEmpty;
  Set<String> get productIds =>
      Set.unmodifiable(products.map((p) => p.productId));

  AppleProductMapping? productFor(int planId, String period) {
    AppleProductMapping? found;
    for (final product in products) {
      if (product.planId == planId && product.period == period) {
        if (found != null) return null;
        found = product;
      }
    }
    return found;
  }
}
