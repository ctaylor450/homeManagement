import 'package:intl/intl.dart';

class DateTimeUtils {
  static String formatDate(DateTime date) {
    return DateFormat('MMM dd, yyyy').format(date);
  }
  
  static String formatTime(DateTime date) {
    return DateFormat('hh:mm a').format(date);
  }
  
  static String formatDateTime(DateTime date) {
    return DateFormat('MMM dd, yyyy • hh:mm a').format(date);
  }
  
  static String formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = date.difference(now);
    
    if (difference.isNegative) {
      final absDifference = difference.abs();
      if (absDifference.inDays > 0) {
        return '${absDifference.inDays} days ago';
      } else if (absDifference.inHours > 0) {
        return '${absDifference.inHours} hours ago';
      } else if (absDifference.inMinutes > 0) {
        return '${absDifference.inMinutes} minutes ago';
      } else {
        return 'Just now';
      }
    } else {
      if (difference.inDays > 0) {
        return 'in ${difference.inDays} days';
      } else if (difference.inHours > 0) {
        return 'in ${difference.inHours} hours';
      } else if (difference.inMinutes > 0) {
        return 'in ${difference.inMinutes} minutes';
      } else {
        return 'Now';
      }
    }
  }
  
  static bool isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year &&
           date.month == now.month &&
           date.day == now.day;
  }
  
  static bool isTomorrow(DateTime date) {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return date.year == tomorrow.year &&
           date.month == tomorrow.month &&
           date.day == tomorrow.day;
  }
  
  static bool isOverdue(DateTime date) {
    return date.isBefore(DateTime.now());
  }
  
  static bool isDueSoon(DateTime date, {int hours = 24}) {
    final now = DateTime.now();
    final difference = date.difference(now);
    return difference.inHours < hours && !difference.isNegative;
  }
}