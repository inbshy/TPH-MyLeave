import 'package:intl/intl.dart';

class AppDateUtils {
  AppDateUtils._();

  static String formatDate(DateTime date) =>
      DateFormat.yMMMd().format(date.toLocal());

  static String formatDateRange(DateTime start, DateTime end) =>
      '${formatDate(start)} – ${formatDate(end)}';

  static int inclusiveDays(DateTime start, DateTime end) =>
      end.difference(start).inDays + 1;
}
