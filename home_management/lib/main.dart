import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme/app_theme.dart';
import 'core/services/notification_service.dart';
import 'core/services/auto_sync_service.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/providers/calendar_provider.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/home/home_screen.dart';
import 'package:google_sign_in/google_sign_in.dart';

const kWebClientId = '955299526376-8o87c88o9s61rt1kgjhccdh00qjt5p46.apps.googleusercontent.com';

// Global auto-sync service instance
AutoSyncService? _autoSyncService;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await Firebase.initializeApp();
  
  // Initialize Notification Service
  await NotificationService().initialize();

  // Initialize Google Sign-In 
  await GoogleSignIn.instance.initialize(
    serverClientId: kWebClientId
  );
  
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> with WidgetsBindingObserver {
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize auto-sync when app starts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAutoSync();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoSyncService?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Sync when app comes to foreground
    if (state == AppLifecycleState.resumed) {
      _performAutoSyncIfEnabled();
    }
  }

  Future<void> _initializeAutoSync() async {
    try {
      // Check if auto-sync is enabled
      final prefs = await ref.read(calendarPreferencesProvider.future);
      
      if (prefs.autoSyncEnabled) {
        _startAutoSync();
      }
    } catch (e) {
      debugPrint('Error initializing auto-sync: $e');
    }
  }

  void _startAutoSync() {
    // Stop existing service if any
    _autoSyncService?.dispose();
    
    // Create new auto-sync service
    _autoSyncService = AutoSyncService(
      onSync: () async {
        await ref.read(calendarActionsProvider).autoSyncIfDue();
      },
      interval: const Duration(minutes: 30),
    );
    
    _autoSyncService?.start();
  }

  Future<void> _performAutoSyncIfEnabled() async {
    try {
      await ref.read(calendarActionsProvider).autoSyncIfDue();
    } catch (e) {
      debugPrint('Error in auto-sync: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    // Listen to auto-sync preference changes
    ref.listen<AsyncValue<bool>>(autoSyncEnabledProvider, (previous, next) {
      next.whenData((enabled) {
        if (enabled) {
          _startAutoSync();
        } else {
          _autoSyncService?.stop();
        }
      });
    });

    return MaterialApp(
      title: 'Home Organizer',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: authState.when(
        data: (user) {
          if (user != null) {
            return const HomeScreen();
          }
          return const LoginScreen();
        },
        loading: () => const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
        error: (error, stack) => Scaffold(
          body: Center(
            child: Text('Error: $error'),
          ),
        ),
      ),
    );
  }
}