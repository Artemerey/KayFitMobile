sealed class SubscriptionState {
  const SubscriptionState();
}

final class SubscriptionActive extends SubscriptionState {
  const SubscriptionActive({
    required this.productId,
    required this.expiresAt,
  });
  final String productId;
  final DateTime expiresAt;
}

final class SubscriptionGracePeriod extends SubscriptionState {
  const SubscriptionGracePeriod({required this.expiresAt});
  final DateTime expiresAt;
}

final class SubscriptionPending extends SubscriptionState {
  const SubscriptionPending();
}

final class SubscriptionExpired extends SubscriptionState {
  const SubscriptionExpired();
}

final class SubscriptionUnknown extends SubscriptionState {
  const SubscriptionUnknown();
}
