import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/task_provider.dart';
import '../../widgets/task_card.dart';
import '../../widgets/loading_widget.dart';
import 'create_task_screen.dart';

class PublicTasksScreen extends ConsumerWidget {
  const PublicTasksScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final publicTasks = ref.watch(publicTasksProvider);

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(publicTasksProvider);
        },
        child: publicTasks.when(
          data: (tasks) {
            if (tasks.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.public_off,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No public tasks',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Create a task and make it public!',
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
                  onClaim: () {
                    ref.read(taskActionsProvider).claimTask(task.id);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Task claimed!')),
                    );
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
                  onPressed: () => ref.invalidate(publicTasksProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
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
}