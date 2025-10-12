import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/household_provider.dart';
import '../screens/calendar/link_shared_calendar_screen.dart';

/// Widget to display and manage shared calendar settings
/// Add this to your SettingsScreen in the household section
class SharedCalendarSettingsTile extends ConsumerWidget {
  const SharedCalendarSettingsTile({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final household = ref.watch(currentHouseholdProvider);

    return household.when(
      data: (householdData) {
        if (householdData == null) {
          return const SizedBox.shrink();
        }

        final hasSharedCalendar = householdData.sharedGoogleCalendarId != null;

        return ListTile(
          leading: Icon(
            hasSharedCalendar ? Icons.calendar_today : Icons.calendar_today_outlined,
            color: hasSharedCalendar ? Colors.green : null,
          ),
          title: const Text('Shared Family Calendar'),
          subtitle: Text(
            hasSharedCalendar
                ? 'Syncing with Google Calendar'
                : 'Not configured',
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hasSharedCalendar)
                IconButton(
                  icon: const Icon(Icons.sync),
                  onPressed: () async {
                    // Show loading indicator
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (context) => const Center(
                        child: CircularProgressIndicator(),
                      ),
                    );

                    try {
                      final actions = ref.read(householdActionsProvider);
                      await actions.syncSharedCalendar();
                      
                      if (context.mounted) {
                        Navigator.of(context).pop(); // Close loading
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Calendar synced successfully!'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        Navigator.of(context).pop(); // Close loading
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Sync failed: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  tooltip: 'Sync now',
                ),
              const Icon(Icons.chevron_right),
            ],
          ),
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const LinkSharedCalendarScreen(),
              ),
            );
          },
        );
      },
      loading: () => const ListTile(
        leading: CircularProgressIndicator(),
        title: Text('Loading...'),
      ),
      error: (error, stack) => ListTile(
        leading: const Icon(Icons.error, color: Colors.red),
        title: const Text('Error loading household'),
        subtitle: Text(error.toString()),
      ),
    );
  }
}