import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EmployeeAttendanceDetailPage extends StatelessWidget {
  final String employeeName;
  final List<Map<String, dynamic>> records;

  const EmployeeAttendanceDetailPage({
    super.key,
    required this.employeeName,
    required this.records,
  });

  String formatHours(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final DateFormat timeFormat = DateFormat('HH:mm');
    final DateFormat dateFormat = DateFormat('dd-MMM-yy');

    // Group records by date
    Map<String, List<Map<String, dynamic>>> groupedByDate = {};
    for (var record in records) {
      String dateKey = DateFormat('yyyy-MM-dd').format(record['timestamp']);
      groupedByDate.putIfAbsent(dateKey, () => []).add(record);
    }

    int totalMinutesAllDays = 0;
    int totalOTAllDays = 0;

    // Pre-calculate totals
    groupedByDate.forEach((date, dayRecords) {
      dayRecords.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));
      final punchIn = dayRecords.first['timestamp'] as DateTime;
      final punchOut = dayRecords.length > 1 ? dayRecords.last['timestamp'] as DateTime : punchIn;
      final totalMinutes = punchOut.difference(punchIn).inMinutes;
      final otMinutes = totalMinutes > (12 * 60) ? totalMinutes - (12 * 60) : 0;
      totalMinutesAllDays += totalMinutes;
      totalOTAllDays += otMinutes;
    });

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(title: Text(employeeName), backgroundColor: Colors.indigo),
      body: Column(
        children: [
          // Sticky Summary Container
          Container(
            width: double.infinity,
            color: Colors.indigo.shade50,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Summary', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 8),
                Text('Total Days: ${groupedByDate.length}', style: const TextStyle(fontSize: 14)),
                Text('Total Hours: ${formatHours(totalMinutesAllDays)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                Text('Total OT Hours: ${formatHours(totalOTAllDays)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Scrollable Daily Records
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: groupedByDate.entries.map((entry) {
                final dayRecords = entry.value;
                dayRecords.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));

                final punchIn = dayRecords.first['timestamp'] as DateTime;
                final punchOut = dayRecords.length > 1 ? dayRecords.last['timestamp'] as DateTime : punchIn;

                final punchInAddress = dayRecords.first['address'] ?? 'Not Available';
                final punchOutAddress = dayRecords.last['address'] ?? 'Not Available';

                final totalMinutes = punchOut.difference(punchIn).inMinutes;
                final otMinutes = totalMinutes > (12 * 60) ? totalMinutes - (12 * 60) : 0;

                return Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Date: ${dateFormat.format(punchIn)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        Text('Punch In: ${timeFormat.format(punchIn)}', style: const TextStyle(color: Colors.green, fontSize: 14)),
                        Text('Punch In Location: $punchInAddress', style: const TextStyle(fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('Punch Out: ${timeFormat.format(punchOut)}', style: const TextStyle(color: Colors.red, fontSize: 14)),
                        Text('Punch Out Location: $punchOutAddress', style: const TextStyle(fontSize: 14)),
                        const SizedBox(height: 4),
                        Text('Total Hours: ${formatHours(totalMinutes)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                        Text('OT Hours: ${formatHours(otMinutes)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
