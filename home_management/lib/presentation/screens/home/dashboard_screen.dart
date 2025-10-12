import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/task_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/task_card.dart';
import '../../widgets/loading_widget.dart';
import '../tasks/create_task_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personalTasks = ref.watch(personalTasksProvider);
    final overdueTasks = ref.watch(overdueTasksProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(personalTasksProvider);
          ref.invalidate(overdueTasksProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              user.when(
                data: (userData) => Text(
                  'Hello, ${userData?.name ?? "User"}!',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                loading: () => const Text('Hello!'),
                error: (_, __) => const Text('Hello!'),
              ),
              const SizedBox(height: 8),
              Text(
                'Here\'s your task overview',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              _buildStatsRow(context, ref),
              const SizedBox(height: 24),
              if (overdueTasks.value?.isNotEmpty ?? false) ...[
                Text(
                  'Overdue Tasks',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppTheme.errorColor,
                      ),
                ),
                const SizedBox(height: 12),
                overdueTasks.when(
                  data: (tasks) => Column(
                    children: tasks
                        .map((task) => TaskCard(
                              task: task,
                              onComplete: () {
                                ref
                                    .read(taskActionsProvider)
                                    .completeTask(task.id);
                              },
                            ))
                        .toList(),
                  ),
                  loading: () => const LoadingWidget(),
                  error: (error, _) => Text('Error: $error'),
                ),
                const SizedBox(height: 24),
              ],
              Text(
                'My Active Tasks',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              personalTasks.when(
                data: (tasks) {
                  if (tasks.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 64,
                              color: AppTheme.textSecondaryColor,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No active tasks',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Claim some tasks from the public board!',
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return Column(
                    children: tasks
                        .map((task) => TaskCard(
                              task: task,
                              onComplete: () {
                                ref
                                    .read(taskActionsProvider)
                                    .completeTask(task.id);
                              },
                            ))
                        .toList(),
                  );
                },
                loading: () => const LoadingWidget(),
                error: (error, _) => Center(child: Text('Error: $error')),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const CreateTaskScreen(),
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildStatsRow(BuildContext context, WidgetRef ref) {
    final personalTasks = ref.watch(personalTasksProvider);
    final publicTasks = ref.watch(publicTasksProvider);

    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            context,
            'My Tasks',
            personalTasks.value?.length.toString() ?? '0',
            Icons.person,
            AppTheme.primaryColor,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            context,
            'Public',
            publicTasks.value?.length.toString() ?? '0',
            Icons.public,
            AppTheme.secondaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: color,
                ),
          ),
        ],
      ),
    );
  }
}