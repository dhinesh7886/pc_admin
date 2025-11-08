import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EmployeeAttendanceDetailPage extends StatefulWidget {
  final String employeeName;
  final String employeeId;
  final List<Map<String, dynamic>> records;

  const EmployeeAttendanceDetailPage({
    super.key,
    required this.employeeName,
    required this.employeeId,
    required this.records,
  });

  @override
  State<EmployeeAttendanceDetailPage> createState() =>
      _EmployeeAttendanceDetailPageState();
}

class _EmployeeAttendanceDetailPageState
    extends State<EmployeeAttendanceDetailPage> {
  DateTimeRange? selectedDateRange;
  final DateFormat timeFormat = DateFormat('HH:mm');
  final DateFormat dateFormat = DateFormat('dd-MMM-yy');

  final Set<String> selectedDates = {}; // ✅ Store selected dates

  String formatHours(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
  }

  Future<void> pickDateRange() async {
    final now = DateTime.now();
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime(now.year + 1),
      initialDateRange: selectedDateRange ??
          DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now),
    );

    if (picked != null) {
      setState(() {
        selectedDateRange = picked;
      });
    }
  }

  Future<void> _editTime({
    required Map<String, dynamic> record,
    required bool isPunchIn,
  }) async {
    try {
      final oldTime = record['timestamp'] as DateTime;

      final DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: oldTime,
        firstDate: DateTime(2023),
        lastDate: DateTime(2100),
      );
      if (pickedDate == null) return;

      final TimeOfDay? pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(oldTime),
      );
      if (pickedTime == null) return;

      final DateTime newDateTime = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );

      if (!isPunchIn) {
        final punchInRecord = record['pairPunchIn'];
        if (punchInRecord != null &&
            newDateTime.isBefore(punchInRecord['timestamp'])) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('⚠️ Punch Out time cannot be earlier than Punch In.'),
            ),
          );
          return;
        }
      }

      final DateTime startRange = oldTime.subtract(const Duration(seconds: 1));
      final DateTime endRange = oldTime.add(const Duration(seconds: 1));

      final QuerySnapshot<Map<String, dynamic>> query = await FirebaseFirestore
          .instance
          .collection('attendance')
          .doc(widget.employeeId)
          .collection('records')
          .where('timestamp', isGreaterThanOrEqualTo: startRange)
          .where('timestamp', isLessThanOrEqualTo: endRange)
          .limit(1)
          .get();

      if (query.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Record not found in Firestore. Cannot update.'),
          ),
        );
        return;
      }

      final String recordId = query.docs.first.id;

      await FirebaseFirestore.instance
          .collection('attendance')
          .doc(widget.employeeId)
          .collection('records')
          .doc(recordId)
          .update({'timestamp': Timestamp.fromDate(newDateTime)});

      setState(() {
        record['timestamp'] = newDateTime;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              '${isPunchIn ? "Punch In" : "Punch Out"} time updated successfully!'),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating time: $e')),
      );
    }
  }

  // ✅ DELETE FUNCTION
  Future<void> _deleteSelectedRecords(
      Map<String, List<Map<String, dynamic>>> groupedByDate) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text(
            'Are you sure you want to delete selected records (${selectedDates.length})?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context, false),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
            onPressed: () => Navigator.pop(context, true),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      for (final dateKey in selectedDates) {
        final dayRecords = groupedByDate[dateKey] ?? [];
        for (final record in dayRecords) {
          final DateTime oldTime = record['timestamp'];
          final DateTime startRange =
              oldTime.subtract(const Duration(seconds: 1));
          final DateTime endRange = oldTime.add(const Duration(seconds: 1));

          final query = await FirebaseFirestore.instance
              .collection('attendance')
              .doc(widget.employeeId)
              .collection('records')
              .where('timestamp', isGreaterThanOrEqualTo: startRange)
              .where('timestamp', isLessThanOrEqualTo: endRange)
              .limit(1)
              .get();

          if (query.docs.isNotEmpty) {
            await query.docs.first.reference.delete();
          }
        }
      }

      setState(() {
        widget.records
            .removeWhere((r) => selectedDates.contains(DateFormat('yyyy-MM-dd').format(r['timestamp'])));
        selectedDates.clear();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Selected records deleted successfully!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting records: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Map<String, List<Map<String, dynamic>>> groupedByDate = {};

    for (var record in widget.records) {
      if (record['timestamp'] == null) continue;

      String dateKey = DateFormat('yyyy-MM-dd').format(record['timestamp']);
      if (record['type'] == 'punch_out' && record.containsKey('pairPunchIn')) {
        dateKey =
            DateFormat('yyyy-MM-dd').format(record['pairPunchIn']['timestamp']);
      }

      groupedByDate.putIfAbsent(dateKey, () => []).add(record);
    }

    Map<String, List<Map<String, dynamic>>> filteredRecords = {};
    if (selectedDateRange != null) {
      groupedByDate.forEach((key, value) {
        DateTime date = DateTime.parse(key);
        if (date.isAfter(selectedDateRange!.start
                .subtract(const Duration(days: 1))) &&
            date.isBefore(
                selectedDateRange!.end.add(const Duration(days: 1)))) {
          filteredRecords[key] = value;
        }
      });
    }

    int totalMinutesAllDays = 0;
    int totalOTAllDays = 0;

    filteredRecords.forEach((_, dayRecords) {
      dayRecords.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));
      final punchIn = dayRecords.first['timestamp'] as DateTime;
      final punchOut = dayRecords.length > 1
          ? dayRecords.last['timestamp'] as DateTime
          : punchIn;

      int totalMinutes = punchOut.difference(punchIn).inMinutes;
      if (punchOut.isBefore(punchIn)) totalMinutes += 24 * 60;

      final otMinutes = totalMinutes > (12 * 60) ? totalMinutes - (12 * 60) : 0;
      totalMinutesAllDays += totalMinutes;
      totalOTAllDays += otMinutes;

      if (dayRecords.length > 1) {
        dayRecords.last['pairPunchIn'] = dayRecords.first;
      }
    });

    bool allSelected =
        selectedDates.length == filteredRecords.keys.length && selectedDates.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('${widget.employeeName} (${widget.employeeId})'),
        backgroundColor: const Color.fromARGB(255, 166, 241, 105),
        actions: [
          if (selectedDates.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _deleteSelectedRecords(filteredRecords),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                const Text(
                  'Select Date Range:',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: pickDateRange,
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        selectedDateRange == null
                            ? 'Tap to select range'
                            : '${dateFormat.format(selectedDateRange!.start)} → ${dateFormat.format(selectedDateRange!.end)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ),
                if (selectedDateRange != null)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => selectedDateRange = null),
                  ),
              ],
            ),
          ),

          if (selectedDates.isNotEmpty || filteredRecords.isNotEmpty)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Checkbox(
                    value: allSelected,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          selectedDates.addAll(filteredRecords.keys);
                        } else {
                          selectedDates.clear();
                        }
                      });
                    },
                  ),
                  const Text('Select All', style: TextStyle(fontSize: 15)),
                ],
              ),
            ),

          const SizedBox(height: 6),

          Expanded(
            child: selectedDateRange == null
                ? const Center(
                    child: Text('Please select a date range to view records.'),
                  )
                : filteredRecords.isEmpty
                    ? const Center(
                        child: Text('No records found for selected period.'),
                      )
                    : ListView(
                        padding: const EdgeInsets.all(12),
                        children: filteredRecords.entries.map((entry) {
                          final dateKey = entry.key;
                          final dayRecords = entry.value;
                          dayRecords.sort(
                              (a, b) => a['timestamp'].compareTo(b['timestamp']));

                          final punchIn = dayRecords.first['timestamp'] as DateTime;
                          final punchOut = dayRecords.length > 1
                              ? dayRecords.last['timestamp'] as DateTime
                              : punchIn;

                          final punchInAddress =
                              dayRecords.first['address'] ?? 'Not Available';
                          final punchOutAddress =
                              dayRecords.last['address'] ?? 'Not Available';

                          int totalMinutes =
                              punchOut.difference(punchIn).inMinutes;
                          if (punchOut.isBefore(punchIn)) totalMinutes += 24 * 60;

                          final otMinutes = totalMinutes > (12 * 60)
                              ? totalMinutes - (12 * 60)
                              : 0;

                          String displayPunchOutTime = timeFormat.format(punchOut);
                          if (punchOut.day > punchIn.day ||
                              punchOut.isBefore(punchIn)) {
                            final diffHours =
                                punchOut.difference(punchIn).inHours;
                            final adjustedHours = 24 + diffHours;
                            final mins =
                                punchOut.difference(punchIn).inMinutes % 60;
                            displayPunchOutTime =
                                '${adjustedHours.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}';
                          }

                          return Card(
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              children: [
                                CheckboxListTile(
                                  value: selectedDates.contains(dateKey),
                                  onChanged: (val) {
                                    setState(() {
                                      if (val == true) {
                                        selectedDates.add(dateKey);
                                      } else {
                                        selectedDates.remove(dateKey);
                                      }
                                    });
                                  },
                                  title: Text(
                                      'Date: ${dateFormat.format(punchIn)}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                              'Punch In: ${timeFormat.format(punchIn)}',
                                              style: const TextStyle(
                                                  color: Colors.green)),
                                          IconButton(
                                            icon:
                                                const Icon(Icons.edit, size: 20),
                                            onPressed: () => _editTime(
                                                record: dayRecords.first,
                                                isPunchIn: true),
                                          ),
                                        ],
                                      ),
                                      Text(
                                          'Punch In Location: $punchInAddress'),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                              'Punch Out: $displayPunchOutTime',
                                              style: const TextStyle(
                                                  color: Colors.red)),
                                          IconButton(
                                            icon:
                                                const Icon(Icons.edit, size: 20),
                                            onPressed: () => _editTime(
                                                record: dayRecords.last,
                                                isPunchIn: false),
                                          ),
                                        ],
                                      ),
                                      Text(
                                          'Punch Out Location: $punchOutAddress'),
                                      Text(
                                          'Total Hours: ${formatHours(totalMinutes)}'),
                                      Text(
                                          'OT Hours: ${formatHours(otMinutes)}'),
                                    ],
                                  ),
                                ),
                              ],
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
