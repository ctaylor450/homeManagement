import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../data/datasources/firebase_datasource.dart';
import '../../data/datasources/google_calendar_datasource.dart';
import '../../data/repositories/user_repository.dart';
import '../../data/models/user_model.dart';

/// Providers
final firebaseDataSourceProvider = Provider<FirebaseDataSource>((ref) {
  return FirebaseDataSource();
});

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository();
});

final googleSignInProvider = Provider<GoogleSignIn>((ref) {
  return GoogleSignIn.instance;
});

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final googleCalendarDataSourceProvider = Provider<GoogleCalendarDataSource>((ref) {
  return GoogleCalendarDataSource();
});

final authStateProvider = StreamProvider<User?>((ref) {
  final dataSource = ref.watch(firebaseDataSourceProvider);
  return dataSource.authStateChanges;
});

final currentUserIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) => user?.uid,
    loading: () => null,
    error: (_, __) => null,
  );
});

final currentUserProvider = StreamProvider<UserModel?>((ref) {
  final userId = ref.watch(currentUserIdProvider);

  if (userId == null) {
    return Stream.value(null);
  }

  final repository = ref.watch(userRepositoryProvider);
  return repository.getUserStream(userId);
});

final currentHouseholdIdProvider = Provider<String?>((ref) {
  final user = ref.watch(currentUserProvider);
  return user.when(
    data: (userData) => userData?.householdId,
    loading: () => null,
    error: (_, __) => null,
  );
});

final authActionsProvider = Provider<AuthActions>((ref) {
  return AuthActions(ref);
});

// Provider to check if Google Calendar is connected
final isGoogleCalendarConnectedProvider = FutureProvider<bool>((ref) async {
  final storage = ref.watch(secureStorageProvider);
  final accessToken = await storage.read(key: 'google_access_token');
  return accessToken != null && accessToken.isNotEmpty;
});

/// AuthActions
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

      final userCredential = await dataSource.signUpWithEmail(email, password);

      if (userCredential.user != null) {
        final user = UserModel(
          id: userCredential.user!.uid,
          name: name,
          email: email,
          createdAt: DateTime.now(),
        );

        await userRepository.createUser(user);
      }
    } catch (e) {
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
      print('Error in sign in: $e');
      rethrow;
    }
  }

  /// Google Sign-In with Calendar Access
  Future<void> signInWithGoogle() async {
    try {
      final googleSignIn = ref.read(googleSignInProvider);
      final userRepository = ref.read(userRepositoryProvider);
      final storage = ref.read(secureStorageProvider);

      // Authenticate with Google
      final account = await googleSignIn.authenticate();

      // Request Calendar + basic profile/email scopes
      const scopes = <String>[
        'https://www.googleapis.com/auth/calendar',
        'https://www.googleapis.com/auth/userinfo.email',
        'https://www.googleapis.com/auth/userinfo.profile',
      ];

      final authorization =
          await account.authorizationClient.authorizeScopes(scopes);
      final String accessToken = authorization.accessToken;

      // Store access token securely
      await storage.write(key: 'google_access_token', value: accessToken);
      
      // Get refresh token if available (for long-term access)
      final auth = await account.authentication;
      if (auth.idToken != null) {
        await storage.write(key: 'google_refresh_token', value: auth.idToken!);
      }

      // Create Firebase credential
      final credential = GoogleAuthProvider.credential(
        idToken: auth.idToken,
        accessToken: accessToken,
      );

      // Sign in to Firebase
      final userCred = await FirebaseAuth.instance.signInWithCredential(credential);

      // Initialize Google Calendar API
      
      final calendarDataSource = ref.read(googleCalendarDataSourceProvider);
      await calendarDataSource.initialize(accessToken);

      // Get primary calendar ID
      final calendarId = await calendarDataSource.getPrimaryCalendarId();

      // Upsert Firestore profile with calendar ID
      final fbUser = userCred.user;
      if (fbUser != null) {
        final profile = UserModel(
          id: fbUser.uid,
          name: fbUser.displayName ?? account.displayName ?? '',
          email: fbUser.email ?? account.email,
          googleCalendarId: calendarId,
          createdAt: DateTime.now(),
        );
        
        try {
          await userRepository.createUser(profile);
        } catch (_) {
          // User already exists, update with calendar ID
          await userRepository.updateUser(fbUser.uid, {
            'googleCalendarId': calendarId,
          });
        }
      }
    } on FirebaseAuthException catch (e) {
      print('FirebaseAuthException in signInWithGoogle: ${e.code} ${e.message}');
      rethrow;
    } catch (e) {
      print('Error in signInWithGoogle: $e');
      rethrow;
    }
  }

  /// Link Google Calendar to existing account
  Future<void> linkGoogleCalendar() async {
    try {
      final current = FirebaseAuth.instance.currentUser;
      if (current == null) {
        throw Exception('No user is currently signed in');
      }

      final googleSignIn = ref.read(googleSignInProvider);
      final userRepository = ref.read(userRepositoryProvider);
      final storage = ref.read(secureStorageProvider);

      // Authenticate with Google
      final account = await googleSignIn.authenticate();

      // Request Calendar scopes
      const scopes = <String>[
        'https://www.googleapis.com/auth/calendar',
        'https://www.googleapis.com/auth/userinfo.email',
        'https://www.googleapis.com/auth/userinfo.profile',
      ];

      final authorization =
          await account.authorizationClient.authorizeScopes(scopes);
      final String accessToken = authorization.accessToken;

      // Store access token
      await storage.write(key: 'google_access_token', value: accessToken);

      // Initialize Google Calendar API
      final calendarDataSource = ref.read(googleCalendarDataSourceProvider);
      await calendarDataSource.initialize(accessToken);

      // Get primary calendar ID
      final calendarId = await calendarDataSource.getPrimaryCalendarId();

      // Update user with calendar ID
      if (calendarId != null) {
        await userRepository.updateGoogleCalendarId(current.uid, calendarId);
      }

      print('Google Calendar linked successfully');
    } catch (e) {
      print('Error linking Google Calendar: $e');
      rethrow;
    }
  }

  /// Disconnect Google Calendar
  Future<void> disconnectGoogleCalendar() async {
    try {
      final current = FirebaseAuth.instance.currentUser;
      if (current == null) return;

      final storage = ref.read(secureStorageProvider);
      final userRepository = ref.read(userRepositoryProvider);
      final calendarDataSource = ref.read(googleCalendarDataSourceProvider);

      // Sign out from Google Calendar
      await calendarDataSource.signOut();

      // Remove stored tokens
      await storage.delete(key: 'google_access_token');
      await storage.delete(key: 'google_refresh_token');

      // Update user record
      await userRepository.updateUser(current.uid, {
        'googleCalendarId': null,
      });

      print('Google Calendar disconnected');
    } catch (e) {
      print('Error disconnecting Google Calendar: $e');
      rethrow;
    }
  }

  /// Refresh Google Calendar access token
  Future<String?> refreshGoogleAccessToken() async {
    try {
      final googleSignIn = ref.read(googleSignInProvider);
      final storage = ref.read(secureStorageProvider);

      final account = await googleSignIn.signInSilently();
      if (account == null) return null;

      const scopes = <String>[
        'https://www.googleapis.com/auth/calendar',
      ];

      final authorization =
          await account.authorizationClient.authorizeScopes(scopes);
      final String accessToken = authorization.accessToken;

      await storage.write(key: 'google_access_token', value: accessToken);

      // Re-initialize calendar API
      final calendarDataSource = ref.read(googleCalendarDataSourceProvider);
      await calendarDataSource.initialize(accessToken);

      return accessToken;
    } catch (e) {
      print('Error refreshing access token: $e');
      return null;
    }
  }

  /// Sign Out
  Future<void> signOut() async {
    try {
      final dataSource = ref.read(firebaseDataSourceProvider);
      final googleSignIn = ref.read(googleSignInProvider);
      final storage = ref.read(secureStorageProvider);
      final calendarDataSource = ref.read(googleCalendarDataSourceProvider);

      // Sign out from Google Calendar
      await calendarDataSource.signOut();
      
      // Clear stored tokens
      await storage.delete(key: 'google_access_token');
      await storage.delete(key: 'google_refresh_token');

      // Sign out from Google
      await googleSignIn.signOut();

      // Sign out from Firebase
      await dataSource.signOut();
    } catch (e) {
      print('Error signing out: $e');
      rethrow;
    }
  }
}