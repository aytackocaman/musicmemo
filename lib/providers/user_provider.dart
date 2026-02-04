import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/database_service.dart';
import 'auth_provider.dart';

/// Provider for user profile
final userProfileProvider = FutureProvider<UserProfile?>((ref) async {
  final authState = ref.watch(authProvider);

  // Only fetch profile if authenticated
  if (!authState.isAuthenticated) {
    return null;
  }

  return DatabaseService.getProfile();
});

/// Provider for user subscription
final subscriptionProvider = FutureProvider<UserSubscription>((ref) async {
  final authState = ref.watch(authProvider);

  // Return free subscription if not authenticated
  if (!authState.isAuthenticated) {
    return UserSubscription.free();
  }

  return DatabaseService.getSubscription();
});

/// Convenience provider for checking premium status
final isPremiumProvider = Provider<AsyncValue<bool>>((ref) {
  return ref.watch(subscriptionProvider).whenData(
    (subscription) => subscription.canAccessPremiumFeatures,
  );
});

/// Provider for daily game counts
final dailyGameCountsProvider = FutureProvider<DailyGameCounts>((ref) async {
  final authState = ref.watch(authProvider);

  if (!authState.isAuthenticated) {
    return DailyGameCounts.zero();
  }

  return DatabaseService.getDailyGameCounts();
});

/// Provider to check if user can play a specific game mode
final canPlayGameModeProvider = FutureProvider.family<bool, String>((ref, gameMode) async {
  final authState = ref.watch(authProvider);

  if (!authState.isAuthenticated) {
    return false;
  }

  return DatabaseService.canPlayGameMode(gameMode);
});

/// Notifier for managing user profile updates
class UserProfileNotifier extends StateNotifier<AsyncValue<UserProfile?>> {
  final Ref ref;

  UserProfileNotifier(this.ref) : super(const AsyncValue.loading()) {
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    state = const AsyncValue.loading();
    try {
      final profile = await DatabaseService.getProfile();
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<bool> updateDisplayName(String name) async {
    final success = await DatabaseService.updateProfile(displayName: name);
    if (success) {
      await _loadProfile();
    }
    return success;
  }

  Future<void> refresh() async {
    await _loadProfile();
  }
}

/// Provider for user profile with mutation capabilities
final userProfileNotifierProvider =
    StateNotifierProvider<UserProfileNotifier, AsyncValue<UserProfile?>>((ref) {
  return UserProfileNotifier(ref);
});

/// User stats provider
final userStatsProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final authState = ref.watch(authProvider);

  if (!authState.isAuthenticated) {
    return null;
  }

  // This would need a method in DatabaseService to fetch user_stats
  // For now, returning null - will implement when needed
  return null;
});
