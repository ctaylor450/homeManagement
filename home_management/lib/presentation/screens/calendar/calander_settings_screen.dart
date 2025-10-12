import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/calendar_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/loading_widget.dart';
import '../../../core/theme/app_theme.dart';

class CalendarSettingsScreen extends ConsumerStatefulWidget {
  const CalendarSettingsScreen({super.key});

  @override
  ConsumerState<CalendarSettingsScreen> createState() => _CalendarSettingsScreenState();
}

class _CalendarSettingsScreenState extends ConsumerState<CalendarSettingsScreen> {
  bool _isSyncing = false;

  Future<void> _handleGoogleCalendarLink() async {
    setState(() => _isSyncing = true);

    try {
      await ref.read(authActionsProvider).linkGoogleCalendar();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google Calendar connected successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to connect: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _handleGoogleCalendarDisconnect() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disconnect Google Calendar?'),
        content: const Text(
          'This will stop syncing with your Google Calendar. '
          'Events in the app will remain, but changes won\'t sync anymore.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSyncing = true);

    try {
      await ref.read(authActionsProvider).disconnectGoogleCalendar();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google Calendar disconnected'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to disconnect: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _handleSyncNow() async {
    setState(() => _isSyncing = true);

    try {
      await ref.read(calendarActionsProvider).syncGoogleCalendar();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Calendar synced successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Future<void> _toggleAutoSync(bool value) async {
    try {
      await ref.read(calendarActionsProvider).setAutoSync(value);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value 
                ? 'Auto-sync enabled. Calendar will sync every 30 minutes.' 
                : 'Auto-sync disabled',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to toggle auto-sync: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleTwoWaySync(bool value) async {
    try {
      await ref.read(calendarActionsProvider).setTwoWaySync(value);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value 
                ? 'Two-way sync enabled. Changes in the app will sync to Google Calendar.' 
                : 'Two-way sync disabled',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to toggle two-way sync: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isGoogleConnected = ref.watch(isGoogleCalendarConnectedProvider);
    final calendarPrefs = ref.watch(calendarPreferencesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar Settings'),
      ),
      body: user.when(
        data: (userData) {
          if (userData == null) {
            return const Center(child: Text('Please log in'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Google Calendar Connection Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              color: AppTheme.primaryColor,
                              size: 32,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Google Calendar',
                                    style: Theme.of(context).textTheme.titleLarge,
                                  ),
                                  const SizedBox(height: 4),
                                  isGoogleConnected.when(
                                    data: (connected) => Text(
                                      connected ? 'Connected' : 'Not connected',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            color: connected ? Colors.green : Colors.grey,
                                          ),
                                    ),
                                    loading: () => const Text('Checking...'),
                                    error: (_, __) => const Text('Error'),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Sync your events with Google Calendar for seamless integration across devices.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 16),
                        if (_isSyncing)
                          const Center(child: LoadingWidget())
                        else
                          isGoogleConnected.when(
                            data: (connected) => connected
                                ? Column(
                                    children: [
                                      CustomButton(
                                        text: 'Sync Now',
                                        onPressed: _handleSyncNow,
                                        icon: Icons.sync,
                                      ),
                                      const SizedBox(height: 8),
                                      SizedBox(
                                        width: double.infinity,
                                        child: ElevatedButton.icon(
                                          onPressed: _handleGoogleCalendarDisconnect,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(vertical: 16),
                                          ),
                                          icon: const Icon(Icons.link_off),
                                          label: const Text('Disconnect'),
                                        ),
                                      ),
                                    ],
                                  )
                                : CustomButton(
                                    text: 'Connect Google Calendar',
                                    onPressed: _handleGoogleCalendarLink,
                                    icon: Icons.link,
                                  ),
                            loading: () => const LoadingWidget(),
                            error: (_, __) => CustomButton(
                              text: 'Connect Google Calendar',
                              onPressed: _handleGoogleCalendarLink,
                              icon: Icons.link,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Sync Information
                if (userData.googleCalendarId != null) ...[
                  Text(
                    'Sync Information',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildInfoRow(
                            context,
                            'Calendar ID',
                            userData.googleCalendarId!,
                          ),
                          const Divider(height: 24),
                          _buildInfoRow(
                            context,
                            'Status',
                            'Active',
                            valueColor: Colors.green,
                          ),
                          calendarPrefs.when(
                            data: (prefs) {
                              if (prefs.lastSyncTime != null) {
                                return Column(
                                  children: [
                                    const Divider(height: 24),
                                    _buildInfoRow(
                                      context,
                                      'Last Synced',
                                      _formatLastSync(prefs.lastSyncTime!),
                                    ),
                                  ],
                                );
                              }
                              return const SizedBox.shrink();
                            },
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Sync Options
                  Text(
                    'Sync Options',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Column(
                      children: [
                        calendarPrefs.when(
                          data: (prefs) => SwitchListTile(
                            title: const Text('Auto-sync events'),
                            subtitle: const Text(
                              'Automatically sync Google Calendar every 30 minutes',
                            ),
                            value: prefs.autoSyncEnabled,
                            onChanged: _toggleAutoSync,
                          ),
                          loading: () => const SwitchListTile(
                            title: Text('Auto-sync events'),
                            subtitle: Text('Loading...'),
                            value: false,
                            onChanged: null,
                          ),
                          error: (_, __) => const SwitchListTile(
                            title: Text('Auto-sync events'),
                            subtitle: Text('Error loading preferences'),
                            value: false,
                            onChanged: null,
                          ),
                        ),
                        const Divider(height: 1),
                        calendarPrefs.when(
                          data: (prefs) => SwitchListTile(
                            title: const Text('Two-way sync'),
                            subtitle: const Text(
                              'Sync changes from app to Google Calendar',
                            ),
                            value: prefs.twoWaySyncEnabled,
                            onChanged: _toggleTwoWaySync,
                          ),
                          loading: () => const SwitchListTile(
                            title: Text('Two-way sync'),
                            subtitle: Text('Loading...'),
                            value: false,
                            onChanged: null,
                          ),
                          error: (_, __) => const SwitchListTile(
                            title: Text('Two-way sync'),
                            subtitle: Text('Error loading preferences'),
                            value: false,
                            onChanged: null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 24),

                // Help Section
                Text(
                  'Need Help?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How it works:',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        _buildHelpItem(
                          '1. Connect your Google account to enable calendar sync',
                        ),
                        _buildHelpItem(
                          '2. Enable "Auto-sync" to automatically import Google Calendar events',
                        ),
                        _buildHelpItem(
                          '3. Enable "Two-way sync" to push app events to Google Calendar',
                        ),
                        _buildHelpItem(
                          '4. Use "Sync Now" to manually sync your events anytime',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: LoadingWidget()),
        error: (error, _) => Center(
          child: Text('Error: $error'),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: valueColor,
                  fontWeight: FontWeight.w500,
                ),
            textAlign: TextAlign.end,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildHelpItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 16,
            color: Colors.green,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  String _formatLastSync(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hr ago';
    } else {
      return '${difference.inDays} days ago';
    }
  }
}