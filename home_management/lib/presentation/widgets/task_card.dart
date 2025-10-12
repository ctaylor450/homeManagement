import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../../data/models/task_model.dart';
import '../../core/utils/date_utils.dart';
import '../../core/theme/app_theme.dart';

class TaskCard extends StatelessWidget {
  final TaskModel task;
  final VoidCallback? onClaim;
  final VoidCallback? onComplete;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  const TaskCard({
    Key? key,
    required this.task,
    this.onClaim,
    this.onComplete,
    this.onTap,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Slidable(
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        children: [
          if (task.status == TaskStatus.public && onClaim != null)
            SlidableAction(
              onPressed: (_) => onClaim?.call(),
              backgroundColor: AppTheme.publicTaskColor,
              foregroundColor: Colors.white,
              icon: Icons.volunteer_activism,
              label: 'Claim',
            ),
          if ((task.status == TaskStatus.claimed ||
                  task.status == TaskStatus.assigned) &&
              onComplete != null)
            SlidableAction(
              onPressed: (_) => onComplete?.call(),
              backgroundColor: AppTheme.successColor,
              foregroundColor: Colors.white,
              icon: Icons.check,
              label: 'Complete',
            ),
          if (onDelete != null)
            SlidableAction(
              onPressed: (_) => onDelete?.call(),
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
              icon: Icons.delete,
              label: 'Delete',
            ),
        ],
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        task.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              decoration: task.status == TaskStatus.completed
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildPriorityChip(),
                  ],
                ),
                if (task.description != null && task.description!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      task.description!,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 16,
                      color: _getDeadlineColor(),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      DateTimeUtils.formatDateTime(task.deadline),
                      style: TextStyle(
                        fontSize: 12,
                        color: _getDeadlineColor(),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '(${DateTimeUtils.formatRelativeTime(task.deadline)})',
                      style: TextStyle(
                        fontSize: 11,
                        color: _getDeadlineColor(),
                      ),
                    ),
                    const Spacer(),
                    _buildStatusChip(),
                  ],
                ),
                if (task.tags.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: task.tags
                          .map((tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  tag,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPriorityChip() {
    Color color;
    switch (task.priority) {
      case TaskPriority.high:
        color = AppTheme.highPriorityColor;
        break;
      case TaskPriority.medium:
        color = AppTheme.mediumPriorityColor;
        break;
      case TaskPriority.low:
        color = AppTheme.lowPriorityColor;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        task.priority.name.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    String label;
    Color color;

    switch (task.status) {
      case TaskStatus.public:
        label = 'Public';
        color = AppTheme.publicTaskColor;
        break;
      case TaskStatus.assigned:
        label = 'Assigned';
        color = AppTheme.assignedTaskColor;
        break;
      case TaskStatus.claimed:
        label = 'In Progress';
        color = AppTheme.claimedTaskColor;
        break;
      case TaskStatus.completed:
        label = 'Completed';
        color = AppTheme.completedTaskColor;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Color _getDeadlineColor() {
    if (DateTimeUtils.isOverdue(task.deadline)) {
      return AppTheme.errorColor;
    } else if (DateTimeUtils.isDueSoon(task.deadline)) {
      return AppTheme.warningColor;
    } else {
      return AppTheme.textSecondaryColor;
    }
  }
}