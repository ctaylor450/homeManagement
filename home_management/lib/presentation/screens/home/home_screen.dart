import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/household_provider.dart';
import '../tasks/public_tasks_screen.dart';
import '../tasks/personal_tasks_screen.dart';
import '../calendar/shared_calendar_screen.dart';
import '../settings/settings_screen.dart';
import 'dashboard_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const PublicTasksScreen(),
    const PersonalTasksScreen(),
    const SharedCalendarScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final household = ref.watch(currentHouseholdProvider);

    return Scaffold(
      appBar: AppBar(
        title: household.when(
          data: (householdData) =>
              Text(householdData?.name ?? 'Home Organizer'),
          loading: () => const Text('Home Organizer'),
          error: (_, __) => const Text('Home Organizer'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SettingsScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: user.when(
        data: (userData) {
          if (userData?.householdId == null) {
            return _buildNoHouseholdView();
          }
          return _screens[_currentIndex];
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(child: Text('Error: $error')),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppTheme.primaryColor,
        unselectedItemColor: AppTheme.textSecondaryColor,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.public),
            label: 'Public',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'My Tasks',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Calendar',
          ),
        ],
      ),
    );
  }

  Widget _buildNoHouseholdView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.home_outlined,
              size: 100,
              color: AppTheme.textSecondaryColor,
            ),
            const SizedBox(height: 24),
            Text(
              'No Household Yet',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 16),
            Text(
              'Create a new household or join an existing one to get started',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => _showCreateHouseholdDialog(),
              child: const Text('Create Household'),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => _showJoinHouseholdDialog(),
              child: const Text('Join Household'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateHouseholdDialog() {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Household'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Household Name',
            hintText: 'e.g., Smith Family',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;

              try {
                await ref
                    .read(householdActionsProvider)
                    .createHousehold(nameController.text.trim());

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Household created successfully!'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showJoinHouseholdDialog() {
    final codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Join Household'),
        content: TextField(
          controller: codeController,
          decoration: const InputDecoration(
            labelText: 'Invite Code',
            hintText: 'Enter 6-character code',
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (codeController.text.trim().isEmpty) return;

              try {
                await ref
                    .read(householdActionsProvider)
                    .joinHousehold(codeController.text.trim());

                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Joined household successfully!'),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: ${e.toString()}'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              }
            },
            child: const Text('Join'),
          ),
        ],
      ),
    );
  }
}