// lib/presentation/widgets/edit_event_dialouge.dart
// NOTE: File name matches the user's request ("dialouge").
// If you prefer correct spelling, rename to edit_event_dialog.dart and update imports accordingly.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// TODO: Adjust these imports to your actual project structure.
import '../../data/models/calendar_event_model.dart';
// If your notifier/provider has a different name or path, update this import:
import '../providers/calendar_provider.dart'; // exposes calendarControllerProvider (or similar)

class EditEventDialog extends ConsumerStatefulWidget {
  const EditEventDialog({
    super.key,
    required this.event,
  });

  final CalendarEventModel event;

  @override
  ConsumerState<EditEventDialog> createState() => _EditEventDialogState();
}

class _EditEventDialogState extends ConsumerState<EditEventDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;

  late DateTime _start;
  late DateTime _end;
  late bool _allDay;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.event.title ?? '');
    _descCtrl = TextEditingController(text: widget.event.description ?? '');

    _start = widget.event.startTime;
    _end = widget.event.endTime;
    _allDay = _isAllDayFromTimes(_start, _end);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  bool _isAllDayFromTimes(DateTime start, DateTime end) {
    return start.hour == 0 &&
        start.minute == 0 &&
        end.hour == 23 &&
        end.minute >= 55; // tolerate 23:59 or 23:55 rounding
  }

  String _formatDate(DateTime dt) {
    return '${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 24;
    final m = dt.minute;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _start = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _allDay ? 0 : _start.hour,
          _allDay ? 0 : _start.minute,
        );
        if (_start.isAfter(_end)) {
          _end = _allDay
              ? DateTime(picked.year, picked.month, picked.day, 23, 59)
              : _start.add(const Duration(hours: 1));
        }
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _end,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        _end = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _allDay ? 23 : _end.hour,
          _allDay ? 59 : _end.minute,
        );
        if (_end.isBefore(_start)) {
          _start = _allDay
              ? DateTime(picked.year, picked.month, picked.day, 0, 0)
              : _end.subtract(const Duration(hours: 1));
        }
      });
    }
  }

  Future<void> _pickStartTime() async {
    if (_allDay) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _start.hour, minute: _start.minute),
    );
    if (picked != null) {
      setState(() {
        _start = DateTime(
          _start.year,
          _start.month,
          _start.day,
          picked.hour,
          picked.minute,
        );
        if (!_end.isAfter(_start)) {
          _end = _start.add(const Duration(hours: 1));
        }
      });
    }
  }

  Future<void> _pickEndTime() async {
    if (_allDay) return;
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _end.hour, minute: _end.minute),
    );
    if (picked != null) {
      setState(() {
        _end = DateTime(
          _end.year,
          _end.month,
          _end.day,
          picked.hour,
          picked.minute,
        );
        if (!_end.isAfter(_start)) {
          _start = _end.subtract(const Duration(hours: 1));
        }
      });
    }
  }

  Map<String, dynamic> _buildUpdates(CalendarEventModel original) {
    final updates = <String, dynamic>{};

    // Title
    final newTitle = _titleCtrl.text.trim();
    if (newTitle != (original.title ?? '').trim()) {
      updates['title'] = newTitle;
    }

    // Description
    final newDesc = _descCtrl.text.trim();
    if (newDesc != (original.description ?? '').trim()) {
      updates['description'] = newDesc;
    }

    // All-day normalization
    DateTime newStart = _start;
    DateTime newEnd = _end;
    if (_allDay) {
      newStart = DateTime(newStart.year, newStart.month, newStart.day, 0, 0);
      newEnd = DateTime(newEnd.year, newEnd.month, newEnd.day, 23, 59);
    }

    if (!newStart.isAtSameMomentAs(original.startTime)) {
      updates['startTime'] = newStart.toUtc();
    }
    if (!newEnd.isAtSameMomentAs(original.endTime)) {
      updates['endTime'] = newEnd.toUtc();
    }

    return updates;
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (!_allDay && !_end.isAfter(_start)) {
      _showSnack('End time must be after start time.');
      return;
    }

    final updates = _buildUpdates(widget.event);
    if (updates.isEmpty) {
      Navigator.of(context).pop(); // nothing changed
      return;
    }

    setState(() => _saving = true);
    try {
      // IMPORTANT:
      // If your provider name differs, update here.
      final controller = ref.read(calendarActionsProvider);
      await controller.updateEvent(
        widget.event.id,
        updates,
        // Leave null to respect user's two-way sync preference.
        syncToGoogle: true, // Uncomment to force immediate Google sync.
      );

      if (mounted) {
        Navigator.of(context).pop(true); // indicate success
        _showSnack('Event updated');
      }
    } catch (e) {
      _showSnack('Failed to update event: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Event'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    hintText: 'Event title',
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Title is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    hintText: 'Optional',
                  ),
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  value: _allDay,
                  onChanged: (val) {
                    setState(() {
                      _allDay = val;
                      if (_allDay) {
                        _start = DateTime(_start.year, _start.month, _start.day, 0, 0);
                        _end = DateTime(_end.year, _end.month, _end.day, 23, 59);
                      }
                    });
                  },
                  title: const Text('All-day'),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _DateTimeField(
                        label: 'Start date',
                        value: _formatDate(_start),
                        onTap: _pickStartDate,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DateTimeField(
                        label: 'End date',
                        value: _formatDate(_end),
                        onTap: _pickEndDate,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (!_allDay)
                  Row(
                    children: [
                      Expanded(
                        child: _DateTimeField(
                          label: 'Start time',
                          value: _formatTime(_start),
                          onTap: _pickStartTime,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _DateTimeField(
                          label: 'End time',
                          value: _formatTime(_end),
                          onTap: _pickEndTime,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

class _DateTimeField extends StatelessWidget {
  const _DateTimeField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            value,
            style: theme.textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }
}
