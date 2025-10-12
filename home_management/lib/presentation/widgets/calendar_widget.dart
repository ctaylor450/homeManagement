import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/calendar_event_model.dart';
import '../../data/models/task_model.dart';
import '../../core/utils/date_utils.dart' as app_date_utils;

class CalendarWidget extends ConsumerStatefulWidget {
  final List<CalendarEventModel> events;
  final List<TaskModel>? tasks;
  final Function(DateTime)? onDaySelected;
  final Function(DateTime, DateTime)? onRangeSelected;
  final bool showEventList;
  final CalendarFormat initialFormat;

  const CalendarWidget({
    Key? key,
    required this.events,
    this.tasks,
    this.onDaySelected,
    this.onRangeSelected,
    this.showEventList = true,
    this.initialFormat = CalendarFormat.month,
  }) : super(key: key);

  @override
  ConsumerState<CalendarWidget> createState() => _CalendarWidgetState();
}

class _CalendarWidgetState extends ConsumerState<CalendarWidget> {
  late DateTime _focusedDay;
  DateTime? _selectedDay;
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  CalendarFormat _calendarFormat = CalendarFormat.month;
  RangeSelectionMode _rangeSelectionMode = RangeSelectionMode.toggledOff;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
    _calendarFormat = widget.initialFormat;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildCalendar(),
        if (widget.showEventList) ...[
          const Divider(height: 1),
          Expanded(child: _buildEventsList()),
        ],
      ],
    );
  }

  Widget _buildCalendar() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        rangeStartDay: _rangeStart,
        rangeEndDay: _rangeEnd,
        calendarFormat: _calendarFormat,
        rangeSelectionMode: _rangeSelectionMode,
        startingDayOfWeek: StartingDayOfWeek.monday,
        
        // Calendar Style
        calendarStyle: CalendarStyle(
          // Today's date style
          todayDecoration: BoxDecoration(
            color: AppTheme.primaryColor.withOpacity(0.3),
            shape: BoxShape.circle,
          ),
          todayTextStyle: const TextStyle(
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.bold,
          ),
          
          // Selected date style
          selectedDecoration: const BoxDecoration(
            color: AppTheme.primaryColor,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
          
          // Range selection style
          rangeStartDecoration: const BoxDecoration(
            color: AppTheme.primaryColor,
            shape: BoxShape.circle,
          ),
          rangeEndDecoration: const BoxDecoration(
            color: AppTheme.primaryColor,
            shape: BoxShape.circle,
          ),
          rangeHighlightColor: AppTheme.primaryColor.withOpacity(0.1),
          
          // Weekend style
          weekendTextStyle: const TextStyle(
            color: AppTheme.errorColor,
          ),
          
          // Outside month days
          outsideDaysVisible: false,
          
          // Event markers
          markersMaxCount: 3,
          markerDecoration: const BoxDecoration(
            color: AppTheme.accentColor,
            shape: BoxShape.circle,
          ),
          markerSize: 6,
          markerMargin: const EdgeInsets.symmetric(horizontal: 1),
          
          // Cell decoration
          defaultDecoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.transparent,
              width: 1,
            ),
          ),
          
          // Cell padding
          cellMargin: const EdgeInsets.all(4),
        ),
        
        // Header Style
        headerStyle: HeaderStyle(
          titleCentered: true,
          formatButtonVisible: true,
          formatButtonShowsNext: false,
          titleTextStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimaryColor,
          ),
          formatButtonTextStyle: const TextStyle(
            fontSize: 14,
            color: AppTheme.primaryColor,
          ),
          formatButtonDecoration: BoxDecoration(
            border: Border.all(color: AppTheme.primaryColor),
            borderRadius: BorderRadius.circular(8),
          ),
          leftChevronIcon: const Icon(
            Icons.chevron_left,
            color: AppTheme.primaryColor,
          ),
          rightChevronIcon: const Icon(
            Icons.chevron_right,
            color: AppTheme.primaryColor,
          ),
          headerPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        
        // Days of week style
        daysOfWeekStyle: const DaysOfWeekStyle(
          weekdayStyle: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.textSecondaryColor,
          ),
          weekendStyle: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppTheme.errorColor,
          ),
        ),
        
        // Event loader
        eventLoader: _getEventsForDay,
        
        // Callbacks
        onDaySelected: _onDaySelected,
        onRangeSelected: _onRangeSelected,
        onFormatChanged: (format) {
          if (_calendarFormat != format) {
            setState(() => _calendarFormat = format);
          }
        },
        onPageChanged: (focusedDay) {
          _focusedDay = focusedDay;
        },
        
        // Calendar builders for custom styling
        calendarBuilders: CalendarBuilders(
          // Custom marker builder
          markerBuilder: (context, date, events) {
            if (events.isEmpty) return const SizedBox();
            
            return Positioned(
              bottom: 1,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: events.take(3).map((event) {
                  Color markerColor = AppTheme.accentColor;
                  
                  if (event is CalendarEventModel) {
                    markerColor = event.type == EventType.task
                        ? AppTheme.primaryColor
                        : AppTheme.secondaryColor;
                  } else if (event is TaskModel) {
                    markerColor = _getTaskMarkerColor(event);
                  }
                  
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: markerColor,
                      shape: BoxShape.circle,
                    ),
                  );
                }).toList(),
              ),
            );
          },
          
          // Custom day builder
          defaultBuilder: (context, date, focusedDay) {
            final events = _getEventsForDay(date);
            final hasEvents = events.isNotEmpty;
            
            return Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: hasEvents
                    ? Border.all(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        width: 1,
                      )
                    : null,
              ),
              child: Center(
                child: Text(
                  '${date.day}',
                  style: TextStyle(
                    color: AppTheme.textPrimaryColor,
                    fontWeight: hasEvents ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ),
            );
          },
          
          // Today builder
          todayBuilder: (context, date, focusedDay) {
            return Container(
              margin: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  '${date.day}',
                  style: const TextStyle(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEventsList() {
    final selectedEvents = _selectedDay != null
        ? _getEventsForDay(_selectedDay!)
        : <dynamic>[];

    if (selectedEvents.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.event_busy,
                size: 64,
                color: AppTheme.textSecondaryColor.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                _selectedDay != null
                    ? 'No events on this day'
                    : 'Select a day to view events',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.textSecondaryColor,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: selectedEvents.length,
      itemBuilder: (context, index) {
        final event = selectedEvents[index];
        
        if (event is CalendarEventModel) {
          return _buildEventCard(event);
        } else if (event is TaskModel) {
          return _buildTaskCard(event);
        }
        
        return const SizedBox();
      },
    );
  }

  Widget _buildEventCard(CalendarEventModel event) {
    final isTask = event.type == EventType.task;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: (isTask ? AppTheme.primaryColor : AppTheme.secondaryColor)
                .withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            isTask ? Icons.task_alt : Icons.event,
            color: isTask ? AppTheme.primaryColor : AppTheme.secondaryColor,
          ),
        ),
        title: Text(
          event.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: AppTheme.textSecondaryColor,
                ),
                const SizedBox(width: 4),
                Text(
                  '${_formatTime(event.startTime)} - ${_formatTime(event.endTime)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ),
            if (event.description != null && event.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                event.description!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textSecondaryColor,
                ),
              ),
            ],
          ],
        ),
        trailing: event.isShared
            ? Tooltip(
                message: 'Shared event',
                child: Icon(
                  Icons.group,
                  size: 20,
                  color: AppTheme.accentColor,
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildTaskCard(TaskModel task) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _getTaskStatusColor(task.status).withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getTaskStatusIcon(task.status),
            color: _getTaskStatusColor(task.status),
          ),
        ),
        title: Text(
          task.title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            decoration: task.status == TaskStatus.completed
                ? TextDecoration.lineThrough
                : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: _getDeadlineColor(task.deadline),
                ),
                const SizedBox(width: 4),
                Text(
                  app_date_utils.DateTimeUtils.formatTime(task.deadline),
                  style: TextStyle(
                    fontSize: 12,
                    color: _getDeadlineColor(task.deadline),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                _buildPriorityBadge(task.priority),
              ],
            ),
          ],
        ),
        trailing: _buildStatusBadge(task.status),
      ),
    );
  }

  Widget _buildPriorityBadge(TaskPriority priority) {
    Color color;
    String label;
    
    switch (priority) {
      case TaskPriority.high:
        color = AppTheme.highPriorityColor;
        label = 'HIGH';
        break;
      case TaskPriority.medium:
        color = AppTheme.mediumPriorityColor;
        label = 'MED';
        break;
      case TaskPriority.low:
        color = AppTheme.lowPriorityColor;
        label = 'LOW';
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(TaskStatus status) {
    Color color;
    IconData icon;
    
    switch (status) {
      case TaskStatus.public:
        color = AppTheme.publicTaskColor;
        icon = Icons.public;
        break;
      case TaskStatus.assigned:
        color = AppTheme.assignedTaskColor;
        icon = Icons.person;
        break;
      case TaskStatus.claimed:
        color = AppTheme.claimedTaskColor;
        icon = Icons.schedule;
        break;
      case TaskStatus.completed:
        color = AppTheme.completedTaskColor;
        icon = Icons.check_circle;
        break;
    }
    
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }

  List<dynamic> _getEventsForDay(DateTime day) {
    final events = widget.events
        .where((event) => isSameDay(event.startTime, day))
        .toList();
    
    final tasks = widget.tasks
            ?.where((task) => isSameDay(task.deadline, day))
            .toList() ??
        [];
    
    return [...events, ...tasks];
  }

  Color _getTaskMarkerColor(TaskModel task) {
    switch (task.priority) {
      case TaskPriority.high:
        return AppTheme.highPriorityColor;
      case TaskPriority.medium:
        return AppTheme.mediumPriorityColor;
      case TaskPriority.low:
        return AppTheme.lowPriorityColor;
    }
  }

  Color _getTaskStatusColor(TaskStatus status) {
    switch (status) {
      case TaskStatus.public:
        return AppTheme.publicTaskColor;
      case TaskStatus.assigned:
        return AppTheme.assignedTaskColor;
      case TaskStatus.claimed:
        return AppTheme.claimedTaskColor;
      case TaskStatus.completed:
        return AppTheme.completedTaskColor;
    }
  }

  IconData _getTaskStatusIcon(TaskStatus status) {
    switch (status) {
      case TaskStatus.public:
        return Icons.public;
      case TaskStatus.assigned:
        return Icons.person;
      case TaskStatus.claimed:
        return Icons.schedule;
      case TaskStatus.completed:
        return Icons.check_circle;
    }
  }

  Color _getDeadlineColor(DateTime deadline) {
    if (app_date_utils.DateTimeUtils.isOverdue(deadline)) {
      return AppTheme.errorColor;
    } else if (app_date_utils.DateTimeUtils.isDueSoon(deadline)) {
      return AppTheme.warningColor;
    } else {
      return AppTheme.textSecondaryColor;
    }
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
        _rangeStart = null;
        _rangeEnd = null;
        _rangeSelectionMode = RangeSelectionMode.toggledOff;
      });
      
      widget.onDaySelected?.call(selectedDay);
    }
  }

  void _onRangeSelected(DateTime? start, DateTime? end, DateTime focusedDay) {
    setState(() {
      _selectedDay = null;
      _focusedDay = focusedDay;
      _rangeStart = start;
      _rangeEnd = end;
      _rangeSelectionMode = RangeSelectionMode.toggledOn;
    });
    
    if (start != null && end != null) {
      widget.onRangeSelected?.call(start, end);
    }
  }
}