import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/task_provider.dart';
import '../../widgets/task_card.dart';
import '../../widgets/loading_widget.dart';

class PersonalTasksScreen extends ConsumerWidget {
  const PersonalTasksScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personalTasks = ref.watch(personalTasksProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(personalTasksProvider);
        },
        child: personalTasks.when(
          data: (tasks) {
            if (tasks.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.task_alt,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No personal tasks',
                        style: Theme.of(context).textTheme.titleLarge,
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

            return ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 80),
              itemCount: tasks.length,
              itemBuilder: (context, index) {
                final task = tasks[index];
                return TaskCard(
                  task: task,
                  onComplete: () {
                    ref.read(taskActionsProvider).completeTask(task.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Task completed!')),
                    );
                  },
onDelete: () {
                    _showDeleteDialog(context, ref, task.id);
                  },
                );
              },
            );
          },
          loading: () => const LoadingWidget(message: 'Loading tasks...'),
          error: (error, stack) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error: $error'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(personalTasksProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref, String taskId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Task'),
        content: const Text('Are you sure you want to delete this task?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref.read(taskActionsProvider).deleteTask(taskId);
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Task deleted!')),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}