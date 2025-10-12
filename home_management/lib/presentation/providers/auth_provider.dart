import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;

import '../../data/datasources/firebase_datasource.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/models/user_model.dart';

/// -------------------------------
/// Providers
/// -------------------------------

/// Firebase datasource provider
final firebaseDataSourceProvider = Provider<FirebaseDataSource>((ref) {
  return FirebaseDataSource();
});

/// User repository provider
final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

/// GoogleSignIn provider (scopes can be extended later e.g. calendar)
final googleSignInProvider = Provider<GoogleSignIn>((ref) {
  return GoogleSignIn.instance;
});

/// Auth state provider
final authStateProvider = StreamProvider<User?>((ref) {
  final dataSource = ref.watch(firebaseDataSourceProvider);
  return dataSource.authStateChanges;
});

/// Current user ID provider
final currentUserIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) => user?.uid,
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Current user data provider
final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final userId = ref.watch(currentUserIdProvider);

  if (userId == null) {
    return Stream.value(null);
  }

  final repository = ref.watch(userRepositoryProvider);
  return repository.getUserStream(userId);
});

/// Current household ID provider
final currentHouseholdIdProvider = Provider<String?>((ref) {
  final user = ref.watch(currentUserProvider);
  return user.when(
    data: (userData) => userData?.householdId,
    loading: () => null,
    error: (_, __) => null,
  );
});

/// Auth actions provider
final authActionsProvider = Provider<AuthActions>((ref) {
  return AuthActions(ref);
});

/// -------------------------------
/// AuthActions
/// -------------------------------
class AuthActions {
  final Ref ref;

  AuthActions(this.ref);

  /// Email/Password Sign Up
  Future<void> signUp({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      final dataSource = ref.read(firebaseDataSourceProvider);
      final userRepository = ref.read(userRepositoryProvider);

      // Create auth user
      final userCredential = await dataSource.signUpWithEmail(email, password);

      if (userCredential.user != null) {
        // Create user document in Firestore
        final user = UserModel(
          id: userCredential.user!.uid,
          name: name,
          email: email,
          createdAt: DateTime.now(),
        );

        await userRepository.createUser(user);
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error in sign up: $e');
      rethrow;
    }
  }

  /// Email/Password Sign In
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final dataSource = ref.read(firebaseDataSourceProvider);
      await dataSource.signInWithEmail(email, password);
    } catch (e) {
      // ignore: avoid_print
      print('Error in sign in: $e');
      rethrow;
    }
  }

  /// Google Sign-In (creates or signs in a Firebase user)
  // auth_provider.dart (inside AuthActions)

  Future<void> signInWithGoogle() async {
    try {
      final googleSignIn = ref.read(googleSignInProvider);
      final userRepository = ref.read(userRepositoryProvider);

      // 1) Pick account
      final account = await googleSignIn.authenticate();
      if (account == null) return;

      // 2) Request Calendar (read/write) + basic profile/email scopes
      const scopes = <String>[
        'https://www.googleapis.com/auth/calendar',
        'https://www.googleapis.com/auth/userinfo.email',
        'https://www.googleapis.com/auth/userinfo.profile',
      ];

      // Use authorizeScopes so the result is non-null (will prompt if needed)
      final authorization =
          await account.authorizationClient.authorizeScopes(scopes);
      final String accessToken = authorization.accessToken;

      // 3) Get ID token for Firebase
      final auth = await account.authentication;

      // 4) Create Firebase credential (idToken is what Firebase needs)
      final credential = GoogleAuthProvider.credential(
        idToken: auth.idToken,
        // optional: pass the access token; Firebase will safely ignore it
        accessToken: accessToken,
      );

      // 5) Sign in to Firebase
      final userCred =
          await FirebaseAuth.instance.signInWithCredential(credential);

      // 6) Upsert Firestore profile
      final fbUser = userCred.user;
      if (fbUser != null) {
        final profile = UserModel(
          id: fbUser.uid,
          name: fbUser.displayName ?? account.displayName ?? '',
          email: fbUser.email ?? account.email,
          createdAt: DateTime.now(),
        );
        try { await userRepository.createUser(profile); } catch (_) {}
      }

      // 7) Persist accessToken securely if you’ll call Calendar later
      // final storage = const FlutterSecureStorage();
      // await storage.write(key: 'google_access_token', value: accessToken);
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException in signInWithGoogle: ${e.code} ${e.message}');
      rethrow;
    } catch (e) {
      print('Error in signInWithGoogle: $e');
      rethrow;
    }
  }



  /// Link Google provider to the currently signed-in Firebase user (account linking)
  Future<void> linkGoogleToCurrentUser() async {
    try {
      final current = FirebaseAuth.instance.currentUser;
      if (current == null) {
        throw FirebaseAuthException(
          code: 'no-current-user',
          message: 'No user is currently signed in.',
        );
      }

      final googleSignIn = ref.read(googleSignInProvider);
      final account = await googleSignIn.authenticate();
      if (account == null) return;

      // Get ID token for linking
      final auth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        idToken: auth.idToken, // ✅ no accessToken on v7 auth object
      );
      await current.linkWithCredential(credential);

      // (Optional) Immediately request calendar access token too
      const scopes = <String>[
        'https://www.googleapis.com/auth/calendar',
        'https://www.googleapis.com/auth/userinfo.email',
        'https://www.googleapis.com/auth/userinfo.profile',
      ];
      final authorization =
          await account.authorizationClient.authorizeScopes(scopes);
      final String accessToken = authorization.accessToken;
      // Save accessToken if needed.

      await syncProfileFromAuth();
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException in linkGoogleToCurrentUser: ${e.code} ${e.message}');
      rethrow;
    } catch (e) {
      print('Error in linkGoogleToCurrentUser: $e');
      rethrow;
    }
  }


  /// Unlink Google provider (disconnect Google from this Firebase account)
  Future<void> unlinkGoogle() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await user.unlink('google.com');

      // Optional: also disconnect local GoogleSignIn client on device
      final googleSignIn = ref.read(googleSignInProvider);
      try {
        await googleSignIn.disconnect();
      } catch (_) {
        // ignore disconnect errors
      }

      // Optionally resync Firestore profile
      await syncProfileFromAuth();
    } on FirebaseAuthException catch (e) {
      // ignore: avoid_print
      print('FirebaseAuthException in unlinkGoogle: ${e.code} ${e.message}');
      rethrow;
    } catch (e) {
      // ignore: avoid_print
      print('Error in unlinkGoogle: $e');
      rethrow;
    }
  }

  /// Refresh Firestore profile fields from FirebaseAuth (name/email/photo, etc.)
  Future<void> syncProfileFromAuth() async {
    try {
      final userRepository = ref.read(userRepositoryProvider);
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await user.reload();
      final refreshed = FirebaseAuth.instance.currentUser;

      if (refreshed != null) {
        final updated = UserModel(
          id: refreshed.uid,
          name: refreshed.displayName ?? '',
          email: refreshed.email ?? '',
          createdAt: DateTime.now(), // repo can choose to ignore/merge this
        );

        // If your repo supports a dedicated update, prefer that.
        try {
          await userRepository.createUser(updated);
        } catch (_) {
          // If create fails because doc exists, you may add an update path in your repo.
          // For now we ignore errors to avoid breaking the flow.
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error in syncProfileFromAuth: $e');
      rethrow;
    }
  }

  /// Sign out (Firebase + local Google session)
  Future<void> signOut() async {
    try {
      final dataSource = ref.read(firebaseDataSourceProvider);
      // Sign out from Firebase
      await dataSource.signOut();

      // Also sign out of the local GoogleSignIn client so the chooser shows next time
      final googleSignIn = ref.read(googleSignInProvider);
      try {
        await googleSignIn.signOut();
      } catch (_) {
        // ignore signOut errors
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error in sign out: $e');
      rethrow;
    }
  }

  /// Password reset
  Future<void> resetPassword(String email) async {
    try {
      final dataSource = ref.read(firebaseDataSourceProvider);
      await dataSource.resetPassword(email);
    } catch (e) {
      // ignore: avoid_print
      print('Error resetting password: $e');
      rethrow;
    }
  }
}
