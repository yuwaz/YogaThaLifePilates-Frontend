class SubscriptionCatalog {
  final List<SubscriptionCatalogPlan> plans;

  const SubscriptionCatalog({required this.plans});

  factory SubscriptionCatalog.fromJson(Map<String, dynamic> json) {
    final rawPlans = json['plans'];
    if (rawPlans is! List) {
      throw const FormatException('Catalog plans must be a list.');
    }

    final plans = rawPlans
        .map((value) {
          if (value is! Map) {
            throw const FormatException(
              'Catalog plan entry must be an object.',
            );
          }

          return SubscriptionCatalogPlan.fromJson(
            value.map((key, val) => MapEntry(key.toString(), val)),
          );
        })
        .toList(growable: false);

    return SubscriptionCatalog(plans: plans);
  }

  SubscriptionCatalogPlan? findPlan(String plan) {
    final normalizedPlan = plan.trim().toLowerCase();
    if (normalizedPlan.isEmpty) {
      return null;
    }

    for (final item in plans) {
      if (item.plan.trim().toLowerCase() == normalizedPlan) {
        return item;
      }
    }
    return null;
  }

  List<String> appleProductIdsForPlan(String plan) {
    return findPlan(plan)?.apple?.productIds ?? const <String>[];
  }

  GooglePlaySubscriptionCatalogEntry? googlePlayConfigForPlan(String plan) {
    return findPlan(plan)?.googlePlay;
  }
}

class SubscriptionCatalogPlan {
  final String plan;
  final AppleSubscriptionCatalogEntry? apple;
  final GooglePlaySubscriptionCatalogEntry? googlePlay;

  const SubscriptionCatalogPlan({
    required this.plan,
    this.apple,
    this.googlePlay,
  });

  factory SubscriptionCatalogPlan.fromJson(Map<String, dynamic> json) {
    final plan = _readNonEmptyString(json['plan']);
    if (plan == null) {
      throw const FormatException('Catalog plan code is required.');
    }

    return SubscriptionCatalogPlan(
      plan: plan,
      apple: AppleSubscriptionCatalogEntry.tryParse(json['apple']),
      googlePlay: GooglePlaySubscriptionCatalogEntry.tryParse(
        json['googlePlay'],
      ),
    );
  }
}

class AppleSubscriptionCatalogEntry {
  final List<String> productIds;

  const AppleSubscriptionCatalogEntry({required this.productIds});

  static AppleSubscriptionCatalogEntry? tryParse(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is! Map) {
      throw const FormatException('Apple catalog entry must be an object.');
    }

    final json = value.map((key, val) => MapEntry(key.toString(), val));
    final rawProductIds = json['productIds'];
    if (rawProductIds is! List) {
      throw const FormatException('Apple productIds must be a list.');
    }

    final productIds = rawProductIds
        .map((item) {
          final productId = _readNonEmptyString(item);
          if (productId == null) {
            throw const FormatException(
              'Apple productIds must contain only non-empty strings.',
            );
          }
          return productId;
        })
        .toList(growable: false);

    if (productIds.isEmpty) {
      throw const FormatException('Apple productIds must not be empty.');
    }

    return AppleSubscriptionCatalogEntry(productIds: productIds);
  }
}

class GooglePlaySubscriptionCatalogEntry {
  final String productId;
  final String basePlanId;
  final String? offerId;

  const GooglePlaySubscriptionCatalogEntry({
    required this.productId,
    required this.basePlanId,
    this.offerId,
  });

  static GooglePlaySubscriptionCatalogEntry? tryParse(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is! Map) {
      throw const FormatException(
        'Google Play catalog entry must be an object.',
      );
    }

    final json = value.map((key, val) => MapEntry(key.toString(), val));
    final productId = _readNonEmptyString(json['productId']);
    final basePlanId = _readNonEmptyString(json['basePlanId']);
    if (productId == null || basePlanId == null) {
      throw const FormatException(
        'Google Play productId and basePlanId are required.',
      );
    }

    return GooglePlaySubscriptionCatalogEntry(
      productId: productId,
      basePlanId: basePlanId,
      offerId: _readNonEmptyString(json['offerId']),
    );
  }
}

String? _readNonEmptyString(dynamic value) {
  final asString = value?.toString().trim();
  if (asString == null || asString.isEmpty) {
    return null;
  }
  return asString;
}
