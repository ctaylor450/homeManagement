// Create this file: lib/core/services/auto_sync_service.dart

import 'dart:async';
import 'package:flutter/foundation.dart';

class AutoSyncService {
  Timer? _timer;
  final Future<void> Function() onSync;
  final Duration interval;

  AutoSyncService({
    required this.onSync,
    this.interval = const Duration(minutes: 30),
  });

  /// Start periodic auto-sync
  void start() {
    if (_timer != null && _timer!.isActive) {
      debugPrint('Auto-sync already running');
      return;
    }

    debugPrint('Starting auto-sync service (interval: ${interval.inMinutes} minutes)');
    
    // Run initial sync
    _performSync();
    
    // Schedule periodic syncs
    _timer = Timer.periodic(interval, (_) {
      _performSync();
    });
  }

  /// Stop periodic auto-sync
  void stop() {
    _timer?.cancel();
    _timer = null;
    debugPrint('Auto-sync service stopped');
  }

  /// Perform a single sync
  Future<void> _performSync() async {
    try {
      debugPrint('Auto-sync triggered');
      await onSync();
      debugPrint('Auto-sync completed successfully');
    } catch (e) {
      debugPrint('Auto-sync failed: $e');
      // Don't rethrow - auto-sync should fail silently
    }
  }

  /// Check if service is running
  bool get isRunning => _timer != null && _timer!.isActive;

  /// Dispose resources
  void dispose() {
    stop();
  }
}