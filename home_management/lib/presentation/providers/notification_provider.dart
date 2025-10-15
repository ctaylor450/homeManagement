import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../core/services/notification_service.dart';
import 'auth_provider.dart';

/// Bootstraps FCM token binding after auth changes.
/// (Household topic subscription not used in this build.)
final notificationBootstrapProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<User?>>(authStateProvider, (prev, next) async {
    final user = next.value;
    if (user != null) {
      // NotificationService.initialize() is already called in main()
      await NotificationService().bindUser(user.uid);
    } else {
      await NotificationService().unbindUser();
    }
  });
});
