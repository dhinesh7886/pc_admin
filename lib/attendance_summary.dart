import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminAttendanceSummaryPage extends StatefulWidget {
  final String? companyName; // Nullable

  const AdminAttendanceSummaryPage({super.key, this.companyName});

  @override
  State<AdminAttendanceSummaryPage> createState() =>
      _AdminAttendanceSummaryPageState();
}

class _AdminAttendanceSummaryPageState
    extends State<AdminAttendanceSummaryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DateTime? _startDate;
  DateTime? _endDate;
  final dateFormat = DateFormat('dd-MMM-yy');

  String formatHours(double hours) {
    int h = hours.floor();
    int m = ((hours - h) * 60).round();
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<Map<String, Map<String, dynamic>>> _getAttendanceSummary() async {
    Map<String, Map<String, dynamic>> summaryMap = {};

    if (_startDate == null || _endDate == null) return summaryMap;

    final startTimestamp = Timestamp.fromDate(
        DateTime(_startDate!.year, _startDate!.month, _startDate!.day));
    final endTimestamp = Timestamp.fromDate(
        DateTime(_endDate!.year, _endDate!.month, _endDate!.day)
            .add(const Duration(days: 1)));

    final totalDays = _endDate!.difference(_startDate!).inDays + 1;

    final usersSnapshot = await _firestore
        .collection('Users')
        .where('companyName', isEqualTo: widget.companyName ?? "")
        .where('isActive', isEqualTo: true)
        .get();

    for (var userDoc in usersSnapshot.docs) {
      final employeeId = userDoc.data()['id'] ?? userDoc.id;
      final employeeName = userDoc.data()['name'] ?? 'Unknown';

      final recordsSnapshot = await _firestore
          .collection('attendance')
          .doc(employeeId)
          .collection('records')
          .where('timestamp', isGreaterThanOrEqualTo: startTimestamp)
          .where('timestamp', isLessThan: endTimestamp)
          .orderBy('timestamp')
          .get();

      if (recordsSnapshot.docs.isEmpty) {
        summaryMap[employeeName] = {
          'totalHours': 0.0,
          'otHours': 0.0,
          'totalDays': totalDays,
          'presentDays': 0,
          'absentDays': totalDays,
        };
        continue;
      }

      Map<String, List<DateTime>> dailyTimestamps = {};

      for (var recordDoc in recordsSnapshot.docs) {
        final data = recordDoc.data();
        DateTime timestamp;

        if (data['timestamp'] is Timestamp) {
          timestamp = (data['timestamp'] as Timestamp).toDate();
        } else if (data['timestamp'] is String) {
          try {
            timestamp = DateTime.parse(data['timestamp']);
          } catch (_) {
            timestamp = DateTime.now();
          }
        } else {
          timestamp = DateTime.now();
        }

        final dateKey = dateFormat.format(timestamp);
        dailyTimestamps.putIfAbsent(dateKey, () => []).add(timestamp);
      }

      double totalHours = 0;
      double otHours = 0;

      dailyTimestamps.forEach((date, times) {
        times.sort();
        final punchIn = times.first;
        final punchOut = times.length > 1 ? times.last : punchIn;
        final dayTotal = punchOut.difference(punchIn).inMinutes / 60.0;
        totalHours += dayTotal;
        if (dayTotal > 12) otHours += (dayTotal - 12);
      });

      final presentDays = dailyTimestamps.keys.length;
      final absentDays = totalDays - presentDays;

      summaryMap[employeeName] = {
        'totalHours': totalHours,
        'otHours': otHours,
        'totalDays': totalDays,
        'presentDays': presentDays,
        'absentDays': absentDays,
      };
    }

    return summaryMap;
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.companyName?.isNotEmpty == true ? widget.companyName : "Company"} Attendance Summary',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color.fromARGB(255, 183, 231, 70),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isWide ? 40 : 12,
              vertical: isWide ? 20 : 8,
            ),
            child: Column(
              children: [
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color.fromARGB(255, 183, 231, 70),
                          foregroundColor: Colors.black,
                        ),
                        onPressed: _pickStartDate,
                        icon: const Icon(Icons.date_range),
                        label: Text(
                          'Start: ${_startDate != null ? dateFormat.format(_startDate!) : 'Select'}',
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              const Color.fromARGB(255, 183, 231, 70),
                          foregroundColor: Colors.black,
                        ),
                        onPressed: _pickEndDate,
                        icon: const Icon(Icons.event),
                        label: Text(
                          'End: ${_endDate != null ? dateFormat.format(_endDate!) : 'Select'}',
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.indigo,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => setState(() {}),
                        icon: const Icon(Icons.search),
                        label: const Text('View Summary'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: FutureBuilder<Map<String, Map<String, dynamic>>>(
                    future: _getAttendanceSummary(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                            child: CircularProgressIndicator());
                      }

                      if (!snapshot.hasData || snapshot.data!.isEmpty) {
                        return const Center(
                          child: Text(
                            'No attendance data for selected range.',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w500),
                          ),
                        );
                      }

                      final summaryMap = snapshot.data!;
                      final employeeNames = summaryMap.keys.toList();

                      return GridView.builder(
                        gridDelegate:
                            SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isWide ? 2 : 1,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: isWide ? 2.6 : 1.9,
                        ),
                        itemCount: employeeNames.length,
                        itemBuilder: (context, index) {
                          final name = employeeNames[index];
                          final data = summaryMap[name]!;

                          return Card(
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                      'Total Hours: ${formatHours(data['totalHours'] ?? 0.0)}'),
                                  Text(
                                      'OT Hours: ${formatHours(data['otHours'] ?? 0.0)}'),
                                  Text(
                                      'Total Days: ${data['totalDays'] ?? 0}'),
                                  Text(
                                      'Present Days: ${data['presentDays'] ?? 0}'),
                                  Text(
                                      'Absent Days: ${data['absentDays'] ?? 0}'),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
