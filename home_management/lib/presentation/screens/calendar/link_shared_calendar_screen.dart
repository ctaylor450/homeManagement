import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:googleapis/calendar/v3.dart' as gcal;
import '../../../data/repositories/household_repository.dart';
import '../../providers/auth_provider.dart' hide googleCalendarDataSourceProvider;
import '../../providers/household_provider.dart';
import '../../providers/calendar_provider.dart';

class LinkSharedCalendarScreen extends ConsumerStatefulWidget {
  const LinkSharedCalendarScreen({super.key});

  @override
  ConsumerState<LinkSharedCalendarScreen> createState() =>
      _LinkSharedCalendarScreenState();
}

class _LinkSharedCalendarScreenState
    extends ConsumerState<LinkSharedCalendarScreen> {
  bool _isLoading = true;
  List<gcal.CalendarListEntry> _calendars = [];
  String? _selectedCalendarId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadCalendars();
  }

  Future<void> _loadCalendars() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final calendarDataSource = ref.read(googleCalendarDataSourceProvider);
      
      // Check if user is signed in to Google
      final isSignedIn = await calendarDataSource.isSignedIn();
      
      if (!isSignedIn) {
        // User needs to link Google Calendar first
        setState(() {
          _error = 'Please link your Google Calendar first in Settings';
          _isLoading = false;
        });
        return;
      }

      // Load all calendars the user has access to
      final calendars = await calendarDataSource.listCalendars();
      
      // Get current household to check if already linked
      final household = await ref.read(currentHouseholdProvider.future);
      
      setState(() {
        _calendars = calendars;
        _selectedCalendarId = household?.sharedGoogleCalendarId;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading calendars: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _linkCalendar() async {
    if (_selectedCalendarId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a calendar')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final householdId = ref.read(currentHouseholdIdProvider);
      if (householdId == null) {
        throw Exception('No household found');
      }

      final householdRepo = ref.read(householdRepositoryProvider);
      
      // Link the calendar to the household
      await householdRepo.linkSharedCalendar(householdId, _selectedCalendarId!);

      // Trigger initial sync
      final syncService = ref.read(calendarSyncServiceProvider);
      await syncService.syncSharedGoogleCalendar(
        householdId,
        _selectedCalendarId!,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shared calendar linked successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error linking calendar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _unlinkCalendar() async {
    setState(() => _isLoading = true);

    try {
      final householdId = ref.read(currentHouseholdIdProvider);
      if (householdId == null) {
        throw Exception('No household found');
      }

      final householdRepo = ref.read(householdRepositoryProvider);
      await householdRepo.unlinkSharedCalendar(householdId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Shared calendar unlinked'),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error unlinking calendar: $e'),
            backgroundColor: Colors.red,
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
        title: const Text('Link Shared Calendar'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 64,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Go Back'),
                        ),
                      ],
                    ),
                  ),
                )
              : _buildCalendarList(),
    );
  }

  Widget _buildCalendarList() {
    if (_calendars.isEmpty) {
      return const Center(
        child: Text('No calendars found'),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue[700]),
                      const SizedBox(width: 8),
                      const Text(
                        'About Shared Calendars',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select your family\'s shared Google Calendar. All events from this calendar will be visible to everyone in your household.',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: _calendars.length,
            itemBuilder: (context, index) {
              final calendar = _calendars[index];
              final isSelected = _selectedCalendarId == calendar.id;
              final isPrimary = calendar.primary ?? false;
              
              return RadioListTile<String>(
                value: calendar.id!,
                groupValue: _selectedCalendarId,
                onChanged: (value) {
                  setState(() {
                    _selectedCalendarId = value;
                  });
                },
                title: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: calendar.backgroundColor != null
                            ? Color(int.parse(
                                calendar.backgroundColor!.replaceAll('#', '0xFF'),
                              ))
                            : Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        calendar.summary ?? 'Unnamed Calendar',
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                    if (isPrimary)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Primary',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[900],
                          ),
                        ),
                      ),
                  ],
                ),
                subtitle: calendar.description != null
                    ? Text(calendar.description!)
                    : null,
              );
            },
          ),
        ),
        Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              if (_selectedCalendarId != null &&
                  ref.read(currentHouseholdProvider).value
                          ?.sharedGoogleCalendarId !=
                      null) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _unlinkCalendar,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                    ),
                    child: const Text('Unlink Calendar'),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: ElevatedButton(
                  onPressed: _selectedCalendarId != null ? _linkCalendar : null,
                  child: const Text('Link Calendar'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}