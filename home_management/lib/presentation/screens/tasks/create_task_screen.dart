import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../data/models/task_model.dart';
import '../../../core/utils/validators.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/task_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class CreateTaskScreen extends ConsumerStatefulWidget {
  const CreateTaskScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends ConsumerState<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  DateTime _selectedDeadline = DateTime.now().add(const Duration(days: 1));
  TaskPriority _selectedPriority = TaskPriority.medium;
  TaskStatus _selectedStatus = TaskStatus.public;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDeadline() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDeadline,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null && mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_selectedDeadline),
      );

      if (time != null) {
        setState(() {
          _selectedDeadline = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
        });
      }
    }
  }

  Future<void> _createTask() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = ref.read(currentUserProvider).value;
      final householdId = user?.householdId;

      if (householdId == null) {
        throw Exception('No household found');
      }

      final task = TaskModel(
        id: '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        status: _selectedStatus,
        householdId: householdId,
        deadline: _selectedDeadline,
        priority: _selectedPriority,
        createdBy: user!.id,
        createdAt: DateTime.now(),
      );

      await ref.read(taskActionsProvider).createTask(task);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Task created successfully!')),
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
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Task'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            CustomTextField(
              controller: _titleController,
              label: 'Task Title',
              hint: 'e.g., Buy groceries',
              validator: Validators.validateTaskTitle,
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: _descriptionController,
              label: 'Description (optional)',
              hint: 'Add more details...',
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            Text(
              'Deadline',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            ListTile(
              tileColor: AppTheme.surfaceColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              leading: const Icon(Icons.calendar_today),
              title: Text(
                DateFormat('MMM dd, yyyy • hh:mm a').format(_selectedDeadline),
              ),
              trailing: const Icon(Icons.edit),
              onTap: _selectDeadline,
            ),
            const SizedBox(height: 24),
            Text(
              'Priority',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SegmentedButton<TaskPriority>(
              segments: const [
                ButtonSegment(
                  value: TaskPriority.low,
                  label: Text('Low'),
                  icon: Icon(Icons.arrow_downward),
                ),
                ButtonSegment(
                  value: TaskPriority.medium,
                  label: Text('Medium'),
                  icon: Icon(Icons.remove),
                ),
                ButtonSegment(
                  value: TaskPriority.high,
                  label: Text('High'),
                  icon: Icon(Icons.arrow_upward),
                ),
              ],
              selected: {_selectedPriority},
              onSelectionChanged: (Set<TaskPriority> selected) {
                setState(() => _selectedPriority = selected.first);
              },
            ),
            const SizedBox(height: 24),
            Text(
              'Task Type',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SegmentedButton<TaskStatus>(
              segments: const [
                ButtonSegment(
                  value: TaskStatus.public,
                  label: Text('Public'),
                  icon: Icon(Icons.public),
                ),
                ButtonSegment(
                  value: TaskStatus.assigned,
                  label: Text('Assigned'),
                  icon: Icon(Icons.person),
                ),
              ],
              selected: {_selectedStatus},
              onSelectionChanged: (Set<TaskStatus> selected) {
                setState(() => _selectedStatus = selected.first);
              },
            ),
            const SizedBox(height: 8),
            Text(
              _selectedStatus == TaskStatus.public
                  ? 'Anyone can claim this task'
                  : 'Task will be assigned to a specific person',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 32),
            CustomButton(
              text: 'Create Task',
              onPressed: _createTask,
              isLoading: _isLoading,
              icon: Icons.add,
            ),
          ],
        ),
      ),
    );
  }
}