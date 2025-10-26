import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pcadmin/attendance_summary.dart';
import 'package:pcadmin/employee_attendance_detail_page.dart';

class AdminAttendancePage extends StatefulWidget {
  final String companyName;
  const AdminAttendancePage({super.key, required this.companyName});

  @override
  State<AdminAttendancePage> createState() => _AdminAttendancePageState();
}

class _AdminAttendancePageState extends State<AdminAttendancePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, List<Map<String, dynamic>>> _employeeMap = {};
  Map<String, Map<String, dynamic>> _employeeInfo = {};
  Map<String, bool> _selectedEmployees = {};
  DateTime? _startDate;
  DateTime? _endDate;
  bool _selectionMode = false;
  bool _filtersExpanded = true;

  String _searchQuery = "";
  String? _selectedDepartment;
  String? _selectedDesignation;

  List<String> _departments = [];
  List<String> _designations = [];

  @override
  void initState() {
    super.initState();
    _fetchFilters();
    _refreshEmployeeData();
  }

  // 🔹 Fetch all departments and designations for dropdowns
  Future<void> _fetchFilters() async {
    final usersSnapshot = await _firestore
        .collection('Users')
        .where('companyName', isEqualTo: widget.companyName)
        .where('isActive', isEqualTo: true)
        .get();

    Set<String> departments = {};
    Set<String> designations = {};

    for (var doc in usersSnapshot.docs) {
      if (doc['department'] != null) departments.add(doc['department']);
      if (doc['designation'] != null) designations.add(doc['designation']);
    }

    setState(() {
      _departments = departments.toList();
      _designations = designations.toList();
    });
  }

  // 🔹 Refresh employee attendance data
  Future<void> _refreshEmployeeData() async {
    final employeeMap = await _getAttendanceGroupedByEmployee();
    setState(() {
      _employeeMap = employeeMap;
    });
  }

  // 🔹 Fetch attendance records grouped by employee
  Future<Map<String, List<Map<String, dynamic>>>> _getAttendanceGroupedByEmployee() async {
    Map<String, List<Map<String, dynamic>>> employeeMap = {};
    _employeeInfo.clear();

    final usersSnapshot = await _firestore
        .collection('Users')
        .where('companyName', isEqualTo: widget.companyName)
        .where('isActive', isEqualTo: true)
        .get();

    for (var userDoc in usersSnapshot.docs) {
      final employeeId = userDoc['id'] ?? userDoc.id;
      final employeeName = userDoc['name'] ?? 'Unknown';
      final department = userDoc['department'] ?? '';
      final designation = userDoc['designation'] ?? '';
      final subDivision = userDoc['subDivision'] ?? '';

      if ((_selectedDepartment != null && department != _selectedDepartment) ||
          (_selectedDesignation != null && designation != _selectedDesignation)) continue;

      _employeeInfo['$employeeName|$employeeId'] = {
        'companyName': widget.companyName,
        'subDivision': subDivision,
        'department': department,
        'designation': designation,
      };

      final recordsSnapshot = await _firestore
          .collection('attendance')
          .doc(employeeId)
          .collection('records')
          .orderBy('timestamp')
          .get();

      if (recordsSnapshot.docs.isEmpty) continue;

      List<Map<String, dynamic>> records = [];

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

        if (_startDate != null && timestamp.isBefore(_startDate!)) continue;
        if (_endDate != null && timestamp.isAfter(_endDate!)) continue;

        records.add({
          'timestamp': timestamp,
          'lat': data['lat'] ?? 0,
          'lng': data['lng'] ?? 0,
          'type': data['type'] ?? '',
          'address': data['address'] ?? '',
        });
      }

      if (records.isNotEmpty) employeeMap['$employeeName|$employeeId'] = records;
    }

    return employeeMap;
  }

  // 🔹 Pick date range
  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _refreshEmployeeData();
    }
  }

  // 🔹 Toggle select all employees
  void _toggleSelectAll(bool selectAll) {
    setState(() {
      if (!selectAll) {
        _selectionMode = false;
        _selectedEmployees.clear();
      } else {
        _selectionMode = true;
        for (var key in _employeeMap.keys) {
          _selectedEmployees[key] = true;
        }
      }
    });
  }

  // 🔹 Download Excel and share
  Future<void> _downloadAndShare() async {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a date range first.')),
      );
      return;
    }

    if (_selectedEmployees.isEmpty || !_selectedEmployees.containsValue(true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one employee.')),
      );
      return;
    }

    final excel = Excel.createExcel();
    final sheet = excel['Attendance'];

    sheet.appendRow([
      'Company Name',
      'Sub-Division',
      'Department',
      'Designation',
      'Employee Name',
      'Employee ID',
      'Date',
      'Punch In',
      'Punch Out',
      'Total Hours',
      'OT Hours',
      'Punch In Address',
      'Punch Out Address'
    ]);

    for (var entry in _selectedEmployees.entries.where((e) => e.value)) {
      final key = entry.key;
      final records = _employeeMap[key]!;
      final info = _employeeInfo[key]!;

      Map<String, List<Map<String, dynamic>>> groupedByDate = {};
      for (var record in records) {
        String dateKey = DateFormat('yyyy-MM-dd').format(record['timestamp']);
        groupedByDate.putIfAbsent(dateKey, () => []).add(record);
      }

      for (var dateEntry in groupedByDate.entries) {
        final dayRecords = dateEntry.value;
        dayRecords.sort((a, b) => a['timestamp'].compareTo(b['timestamp']));
        final punchIn = dayRecords.first['timestamp'] as DateTime;
        final punchOut = dayRecords.length > 1 ? dayRecords.last['timestamp'] as DateTime : punchIn;

        final totalMinutes = punchOut.difference(punchIn).inMinutes;
        final otMinutes = totalMinutes > 12 * 60 ? totalMinutes - 12 * 60 : 0;

        final punchInAddress = dayRecords.first['address'] ?? '';
        final punchOutAddress = dayRecords.last['address'] ?? '';

        final split = key.split('|');
        final name = split[0];
        final id = split[1];

        sheet.appendRow([
          info['companyName'],
          info['subDivision'],
          info['department'],
          info['designation'],
          name,
          id,
          DateFormat('dd-MMM-yy').format(punchIn),
          DateFormat('HH:mm').format(punchIn),
          DateFormat('HH:mm').format(punchOut),
          '${totalMinutes ~/ 60}:${(totalMinutes % 60).toString().padLeft(2, '0')}',
          '${otMinutes ~/ 60}:${(otMinutes % 60).toString().padLeft(2, '0')}',
          punchInAddress,
          punchOutAddress,
        ]);
      }
    }

    final dir = await getTemporaryDirectory();
    final filePath = '${dir.path}/Attendance_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final fileBytes = excel.save();
    if (fileBytes == null) return;

    final file = File(filePath);
    await file.writeAsBytes(fileBytes, flush: true);
    await Share.shareXFiles([XFile(file.path)], text: 'Attendance Excel File');
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Employee Attendance', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color.fromARGB(255, 183, 231, 70),
        actions: [
          IconButton(icon: const Icon(Icons.date_range), onPressed: _pickDateRange),
          if (_selectionMode)
            IconButton(icon: const Icon(Icons.select_all), tooltip: "Select All", onPressed: () => _toggleSelectAll(true)),
          if (_selectionMode)
            IconButton(icon: const Icon(Icons.deselect), tooltip: "Deselect All", onPressed: () => _toggleSelectAll(false)),
          IconButton(
            icon: Icon(_filtersExpanded ? Icons.expand_less : Icons.expand_more),
            onPressed: () => setState(() => _filtersExpanded = !_filtersExpanded),
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                if (_filtersExpanded)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04, vertical: 8),
                    child: Column(
                      children: [
                        if (_startDate != null && _endDate != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade50,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 3))],
                            ),
                            child: Text(
                              "Selected Range: ${DateFormat('dd-MMM-yy').format(_startDate!)} → ${DateFormat('dd-MMM-yy').format(_endDate!)}",
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        // Search Field
                        TextField(
                          decoration: InputDecoration(
                            hintText: 'Search by Name or ID...',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            fillColor: Colors.white,
                            filled: true,
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      setState(() {
                                        _searchQuery = '';
                                        _selectedEmployees.clear();
                                        _selectionMode = false;
                                      });
                                      _refreshEmployeeData();
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                        ),
                        const SizedBox(height: 8),
                        // Filters Row
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                decoration: InputDecoration(
                                  labelText: 'Department',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                value: _selectedDepartment,
                                items: [null, ..._departments].map((dept) {
                                  return DropdownMenuItem(
                                    value: dept,
                                    child: Text(dept ?? 'All'),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() => _selectedDepartment = val);
                                  _refreshEmployeeData();
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                decoration: InputDecoration(
                                  labelText: 'Designation',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                value: _selectedDesignation,
                                items: [null, ..._designations].map((desig) {
                                  return DropdownMenuItem(
                                    value: desig,
                                    child: Text(desig ?? 'All'),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() => _selectedDesignation = val);
                                  _refreshEmployeeData();
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                // Employee List
                Expanded(
                  child: _employeeMap.isEmpty
                      ? const Center(child: CircularProgressIndicator())
                      : ListView(
                          padding: const EdgeInsets.only(bottom: 140),
                          children: _employeeMap.keys
                              .where((key) =>
                                  key.split('|')[0].toLowerCase().contains(_searchQuery) ||
                                  key.split('|')[1].toLowerCase().contains(_searchQuery))
                              .map((key) {
                            final split = key.split('|');
                            final name = split[0];
                            final id = split[1];
                            return Card(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 4,
                              margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                leading: CircleAvatar(
                                  backgroundColor: Colors.indigo.shade200,
                                  radius: 28,
                                  child: Text(name[0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ),
                                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                                subtitle: Text('ID: $id', style: const TextStyle(fontSize: 14, color: Colors.black87)),
                                trailing: _selectionMode
                                    ? Checkbox(
                                        value: _selectedEmployees[key] ?? false,
                                        onChanged: (val) => setState(() {
                                          _selectedEmployees[key] = val ?? false;
                                          if (_selectedEmployees.values.every((v) => !v)) {
                                            _selectionMode = false;
                                            _selectedEmployees.clear();
                                          }
                                        }),
                                      )
                                    : IconButton(
                                        icon: const Icon(Icons.arrow_forward_ios, color: Colors.indigo),
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (_) => EmployeeAttendanceDetailPage(
                                                employeeName: name,
                                                records: _employeeMap[key]!,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
            // Floating Buttons
            if (_selectionMode)
              Positioned(
                bottom: 90,
                right: 16,
                child: FloatingActionButton.extended(
                  backgroundColor: Colors.orangeAccent,
                  icon: const Icon(Icons.download),
                  label: const Text('Download & Share'),
                  onPressed: _downloadAndShare,
                ),
              ),
            if (!_selectionMode)
              Positioned(
                bottom: 80,
                right: 16,
                child: FloatingActionButton(
                  backgroundColor: const Color.fromARGB(255, 231, 70, 159),
                  child: const Icon(Icons.check),
                  onPressed: () {
                    setState(() {
                      _selectionMode = !_selectionMode;
                      if (!_selectionMode) _selectedEmployees.clear();
                    });
                  },
                ),
              ),
            if (!_selectionMode)
              Positioned(
                bottom: 16,
                left: screenWidth * 0.05,
                child: SizedBox(
                  width: screenWidth * 0.9,
                  height: 56,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromARGB(255, 183, 231, 70),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminAttendanceSummaryPage(companyName: widget.companyName),
                        ),
                      );
                    },
                    icon: const Icon(Icons.table_chart, size: 22, color: Colors.black),
                    label: const Text(
                      "View Summary",
                      style: TextStyle(fontSize: 20, color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
