import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/household_provider.dart';
import '../auth/login_screen.dart';
import '../calendar/calander_settings_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final household = ref.watch(currentHouseholdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          user.when(
            data: (userData) => _buildUserSection(context, userData?.name),
            loading: () => const ListTile(
              leading: CircularProgressIndicator(),
              title: Text('Loading...'),
            ),
            error: (_, __) => const ListTile(
              leading: Icon(Icons.error),
              title: Text('Error loading user'),
            ),
          ),
          const Divider(),
          household.when(
            data: (householdData) =>
                _buildHouseholdSection(context, ref, householdData),
            loading: () => const ListTile(
              leading: CircularProgressIndicator(),
              title: Text('Loading household...'),
            ),
            error: (_, __) => const ListTile(
              leading: Icon(Icons.error),
              title: Text('Error loading household'),
            ),
          ),
          const Divider(),
          _buildNotificationSection(context),
          const Divider(),
          _buildAccountSection(context, ref),
        ],
      ),
    );
  }

  Widget _buildUserSection(BuildContext context, String? userName) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Profile',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        ListTile(
          leading: CircleAvatar(
            backgroundColor: AppTheme.primaryColor,
            child: Text(
              userName?.substring(0, 1).toUpperCase() ?? 'U',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          title: Text(userName ?? 'User'),
          subtitle: const Text('View Profile'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // TODO: Navigate to profile screen
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile screen coming soon!')),
            );
          },
        ),
      ],
    );
  }

  Widget _buildHouseholdSection(
    BuildContext context,
    WidgetRef ref,
    dynamic householdData,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Household',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        if (householdData != null) ...[
          ListTile(
            leading: const Icon(Icons.home),
            title: Text(householdData.name),
            subtitle: Text('Invite Code: ${householdData.inviteCode}'),
            trailing: IconButton(
              icon: const Icon(Icons.copy),
              onPressed: () {
                // TODO: Copy invite code to clipboard
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invite code copied!')),
                );
              },
            ),
          ),
          ListTile(
            leading: const Icon(Icons.people),
            title: const Text('Members'),
            subtitle: Text('${householdData.memberIds.length} members'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              // TODO: Show members list
            },
          ),
          ListTile(
            leading: const Icon(Icons.exit_to_app),
            title: const Text('Leave Household'),
            textColor: AppTheme.errorColor,
            iconColor: AppTheme.errorColor,
            onTap: () => _showLeaveHouseholdDialog(context, ref),
          ),
        ] else
          const ListTile(
            leading: Icon(Icons.home_outlined),
            title: Text('No household'),
            subtitle: Text('Create or join a household'),
          ),
      ],
    );
  }

  Widget _buildNotificationSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Notifications',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        SwitchListTile(
          secondary: const Icon(Icons.notifications),
          title: const Text('Push Notifications'),
          subtitle: const Text('Receive task reminders'),
          value: true,
          onChanged: (value) {
            // TODO: Toggle notifications
          },
        ),
        ListTile(
          leading: const Icon(Icons.schedule),
          title: const Text('Reminder Time'),
          subtitle: const Text('30 minutes before deadline'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            // TODO: Change reminder time
          },
        ),
      ],
    );
  }

  Widget _buildAccountSection(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Account',
            style: Theme.of(context).textTheme.titleLarge,
          ),
        ),
        ListTile(
          leading: const Icon(Icons.calendar_month),
          title: const Text('Calender Settings'),
          subtitle: const Text('Sync with Google Calendar'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const CalendarSettingsScreen(),
              ),
            );
            // ScaffoldMessenger.of(context).showSnackBar(
            //   const SnackBar(
            //       content: Text('Google Calendar sync coming soon!')),
            // );
          },
        ),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('About'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            showAboutDialog(
              context: context,
              applicationName: 'Home Organizer',
              applicationVersion: '1.0.0',
              applicationIcon: const Icon(Icons.home_work, size: 48),
              children: [
                const Text(
                  'A collaborative home organization app for managing tasks and schedules.',
                ),
              ],
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.logout),
          title: const Text('Sign Out'),
          textColor: AppTheme.errorColor,
          iconColor: AppTheme.errorColor,
          onTap: () => _showSignOutDialog(context, ref),
        ),
      ],
    );
  }

  void _showLeaveHouseholdDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Household'),
        content: const Text(
          'Are you sure you want to leave this household? You will need an invite code to rejoin.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await ref.read(householdActionsProvider).leaveHousehold();
                if (context.mounted) {
                  Navigator.pop(context);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Left household')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
  }

  void _showSignOutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref.read(authActionsProvider).signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
  }
}