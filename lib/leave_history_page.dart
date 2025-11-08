// leave_history_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

class LeaveHistoryPage extends StatefulWidget {
  final String companyName;

  const LeaveHistoryPage({super.key, required this.companyName});

  @override
  State<LeaveHistoryPage> createState() => _LeaveHistoryPageState();
}

class _LeaveHistoryPageState extends State<LeaveHistoryPage> {
  String _selectedStatus = "All";
  String _searchQuery = "";
  String _selectedMonth = "All";
  bool _selectionMode = false;
  bool _selectAll = false;
  final Set<String> _selectedUsers = {};

  String formatDate(dynamic date) {
    try {
      if (date == null) return "N/A";
      DateTime parsedDate;
      if (date is Timestamp) {
        parsedDate = date.toDate();
      } else if (date is String) {
        parsedDate = DateTime.tryParse(date) ?? DateTime.now();
      } else if (date is DateTime) {
        parsedDate = date;
      } else {
        return "N/A";
      }
      return DateFormat('dd-MMM-yyyy').format(parsedDate);
    } catch (e) {
      return "Invalid";
    }
  }

  int calculateTotalDays(dynamic start, dynamic end) {
    try {
      DateTime startDate;
      DateTime endDate;
      if (start is Timestamp) {
        startDate = start.toDate();
      } else if (start is String) {
        startDate = DateTime.tryParse(start) ?? DateTime.now();
      } else {
        startDate = start;
      }
      if (end is Timestamp) {
        endDate = end.toDate();
      } else if (end is String) {
        endDate = DateTime.tryParse(end) ?? DateTime.now();
      } else {
        endDate = end;
      }
      return endDate.difference(startDate).inDays + 1;
    } catch (e) {
      return 0;
    }
  }

  // 🔹 Build month list like ["All", "November 2025", "October 2025", ...]
  List<String> _generateMonthYearList() {
    final now = DateTime.now();
    final months = <String>["All"];
    for (int i = 0; i < 12; i++) {
      final date = DateTime(now.year, now.month - i, 1);
      months.add(DateFormat('MMMM yyyy').format(date));
    }
    return months;
  }

  // 🔹 Create Excel File
  Future<File> _createExcelFileFromList(List<Map<String, dynamic>> leaveList) async {
    final excel = Excel.createExcel();
    final sheet = excel['LeaveHistory'];

    sheet.appendRow([
      'Employee Name',
      'Employee ID',
      'Reason',
      'Start Date',
      'End Date',
      'Total Days',
      'Status'
    ]);

    for (var leave in leaveList) {
      sheet.appendRow([
        leave["userName"] ?? '',
        leave["empId"] ?? '',
        leave["reason"] ?? '',
        formatDate(leave["startDate"]),
        formatDate(leave["endDate"]),
        calculateTotalDays(leave["startDate"], leave["endDate"]).toString(),
        leave["status"] ?? '',
      ]);
    }

    // 🔹 Filename includes selected month
    String fileName;
    if (_selectedMonth != "All") {
      final safeMonth = _selectedMonth.replaceAll(' ', '_');
      fileName = 'Leave_History_$safeMonth.xlsx';
    } else {
      fileName = 'Leave_History_All_Months.xlsx';
    }

    // 🔹 Save file to Downloads
    Directory? dir;
    if (Platform.isAndroid) {
      dir = Directory('/storage/emulated/0/Download');
      if (!dir.existsSync()) {
        dir = await getTemporaryDirectory();
      }
    } else {
      dir = await getDownloadsDirectory();
      dir ??= await getTemporaryDirectory();
    }

    final filePath = '${dir.path}/$fileName';
    final file = File(filePath);
    final bytes = excel.encode();
    if (bytes == null) throw Exception('Failed to encode Excel');
    await file.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<void> _exportToExcelForSelected(List<Map<String, dynamic>> data) async {
    try {
      final file = await _createExcelFileFromList(data);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("✅ File saved to ${file.path}")),
      );
      await OpenFilex.open(file.path);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error exporting file: $e")),
      );
    }
  }

  Future<void> _shareExcelForSelected(List<Map<String, dynamic>> data) async {
    try {
      final file = await _createExcelFileFromList(data);
      final xFile = XFile(file.path);
      await Share.shareXFiles([xFile], text: 'Leave History Report ($_selectedMonth)');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("❌ Error sharing file: $e")),
      );
    }
  }

  Future<void> _handleShareOrDownload({required bool isDownload}) async {
    final usersSnapshot = await FirebaseFirestore.instance
        .collection("Users")
        .where("companyName", isEqualTo: widget.companyName)
        .get();
    final allData = await _fetchLeaveHistory(usersSnapshot.docs);

    final selectedData = allData
        .where((d) => _selectedUsers.contains("${d["userName"]} (${d["empId"]})"))
        .toList();

    if (selectedData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No data selected to export/share.')),
      );
      return;
    }

    // 🔹 Filter data by month before export
    List<Map<String, dynamic>> monthFilteredData = selectedData;
    if (_selectedMonth != "All") {
      monthFilteredData = selectedData.where((l) {
        final startDate = l["startDate"];
        DateTime date = startDate is Timestamp
            ? startDate.toDate()
            : (startDate is String
                ? DateTime.tryParse(startDate) ?? DateTime.now()
                : startDate);
        final monthYear = DateFormat('MMMM yyyy').format(date);
        return monthYear == _selectedMonth;
      }).toList();
    }

    if (monthFilteredData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No leave data in selected month.')),
      );
      return;
    }

    if (isDownload) {
      await _exportToExcelForSelected(monthFilteredData);
    } else {
      await _shareExcelForSelected(monthFilteredData);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isLargeScreen = width > 700;
    final padding = isLargeScreen ? 24.0 : 12.0;
    final textSize = isLargeScreen ? 18.0 : 14.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Leave History"),
        centerTitle: true,
        backgroundColor: Colors.indigo,
        actions: [
          if (_selectionMode)
            IconButton(
              icon: const Icon(Icons.cancel),
              tooltip: "Exit Selection",
              onPressed: () {
                setState(() {
                  _selectionMode = false;
                  _selectedUsers.clear();
                  _selectAll = false;
                });
              },
            ),
          if (!_selectionMode)
            IconButton(
              icon: const Icon(Icons.checklist),
              tooltip: "Select Employees",
              onPressed: () {
                setState(() => _selectionMode = true);
              },
            ),
          if (_selectedUsers.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.share),
              tooltip: "Share Selected (.xlsx)",
              onPressed: () async {
                await _handleShareOrDownload(isDownload: false);
              },
            ),
          if (_selectedUsers.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: "Download Selected (.xlsx)",
              onPressed: () async {
                await _handleShareOrDownload(isDownload: true);
              },
            ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.all(padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      labelText: "Search by Name or Employee ID",
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value.trim().toLowerCase());
                    },
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedStatus,
                          decoration: const InputDecoration(
                            labelText: "Filter by Status",
                            border: OutlineInputBorder(),
                          ),
                          isExpanded: true,
                          items: const [
                            DropdownMenuItem(value: "All", child: Text("All")),
                            DropdownMenuItem(value: "Approved", child: Text("Approved")),
                            DropdownMenuItem(value: "Rejected", child: Text("Rejected")),
                            DropdownMenuItem(
                                value: "Waiting for Approval",
                                child: Text("Waiting for Approval")),
                          ],
                          onChanged: (value) {
                            setState(() => _selectedStatus = value!);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _selectedMonth,
                          decoration: const InputDecoration(
                            labelText: "Filter by Month & Year",
                            border: OutlineInputBorder(),
                          ),
                          isExpanded: true,
                          items: _generateMonthYearList()
                              .map((m) =>
                                  DropdownMenuItem(value: m, child: Text(m)))
                              .toList(),
                          onChanged: (value) {
                            setState(() => _selectedMonth = value!);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: constraints.maxHeight - 250,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection("Users")
                          .where("companyName", isEqualTo: widget.companyName)
                          .snapshots(),
                      builder: (context, usersSnapshot) {
                        if (!usersSnapshot.hasData) {
                          return const Center(child: CircularProgressIndicator());
                        }

                        final users = usersSnapshot.data!.docs;
                        return FutureBuilder<List<Map<String, dynamic>>>(
                          future: _fetchLeaveHistory(users),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const Center(child: CircularProgressIndicator());
                            }

                            var leaveList = snapshot.data!;

                            if (_searchQuery.isNotEmpty) {
                              leaveList = leaveList.where((l) {
                                final name = l["userName"].toString().toLowerCase();
                                final empId = l["empId"].toString().toLowerCase();
                                return name.contains(_searchQuery) ||
                                    empId.contains(_searchQuery);
                              }).toList();
                            }

                            if (_selectedStatus != "All") {
                              leaveList = leaveList
                                  .where((l) => l["status"] == _selectedStatus)
                                  .toList();
                            }

                            if (_selectedMonth != "All") {
                              leaveList = leaveList.where((l) {
                                final startDate = l["startDate"];
                                DateTime date = startDate is Timestamp
                                    ? startDate.toDate()
                                    : (startDate is String
                                        ? DateTime.tryParse(startDate) ??
                                            DateTime.now()
                                        : startDate);
                                final monthYear =
                                    DateFormat('MMMM yyyy').format(date);
                                return monthYear == _selectedMonth;
                              }).toList();
                            }

                            final Map<String, List<Map<String, dynamic>>> groupedByUser = {};
                            for (var leave in leaveList) {
                              final key =
                                  "${leave["userName"]} (${leave["empId"]})";
                              groupedByUser.putIfAbsent(key, () => []);
                              groupedByUser[key]!.add(leave);
                            }

                            final userKeys = groupedByUser.keys.toList();

                            if (_selectionMode && userKeys.isNotEmpty) {
                              return Column(
                                children: [
                                  CheckboxListTile(
                                    title: const Text("Select All Employees"),
                                    value: _selectAll,
                                    onChanged: (value) {
                                      setState(() {
                                        _selectAll = value ?? false;
                                        if (_selectAll) {
                                          _selectedUsers.addAll(userKeys);
                                        } else {
                                          _selectedUsers.clear();
                                        }
                                      });
                                    },
                                  ),
                                  const Divider(),
                                  Expanded(
                                    child: _buildUserList(
                                        groupedByUser, userKeys, textSize),
                                  ),
                                ],
                              );
                            }

                            return _buildUserList(
                                groupedByUser, userKeys, textSize);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildUserList(Map<String, List<Map<String, dynamic>>> groupedByUser,
      List<String> userKeys, double textSize) {
    return ListView.builder(
      itemCount: userKeys.length,
      itemBuilder: (context, index) {
        final userKey = userKeys[index];
        final userLeaves = groupedByUser[userKey]!;
        final isSelected = _selectedUsers.contains(userKey);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          elevation: 3,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            leading: _selectionMode
                ? Checkbox(
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedUsers.add(userKey);
                        } else {
                          _selectedUsers.remove(userKey);
                        }
                      });
                    },
                  )
                : null,
            title: Text(
              userKey,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: textSize + 1),
            ),
            subtitle: Text(
              "Total Leaves: ${userLeaves.length}",
              style: TextStyle(fontSize: textSize),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: !_selectionMode
                ? () => _showEmployeeLeaveDetails(
                    context, userKey, userLeaves)
                : () {
                    setState(() {
                      if (isSelected) {
                        _selectedUsers.remove(userKey);
                      } else {
                        _selectedUsers.add(userKey);
                      }
                    });
                  },
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchLeaveHistory(
      List<QueryDocumentSnapshot> users) async {
    List<Map<String, dynamic>> allLeaves = [];
    for (var userDoc in users) {
      final userId = userDoc.id;
      final userData = userDoc.data() as Map<String, dynamic>;
      final userName = userData['name'] ?? userId;
      final empId = userData['id'] ?? userId;

      final leaveSnapshot = await FirebaseFirestore.instance
          .collection("Users")
          .doc(userId)
          .collection("leave_requests")
          .get();

      for (var leaveDoc in leaveSnapshot.docs) {
        final leaveData = leaveDoc.data();
        final status = leaveData['status'] ?? "N/A";

        allLeaves.add({
          "userName": userName,
          "empId": empId,
          "reason": leaveData['reason'] ?? "No reason provided",
          "startDate": leaveData['startDate'],
          "endDate": leaveData['endDate'],
          "status": status,
        });
      }
    }
    return allLeaves;
  }

  void _showEmployeeLeaveDetails(
      BuildContext context, String userKey, List<Map<String, dynamic>> leaves) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(userKey),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: leaves.length,
            itemBuilder: (context, index) {
              final leave = leaves[index];
              final reason = leave["reason"];
              final startDate = formatDate(leave["startDate"]);
              final endDate = formatDate(leave["endDate"]);
              final totalDays =
                  calculateTotalDays(leave["startDate"], leave["endDate"]);
              final status = leave["status"];

              return ListTile(
                title: Text("Reason: $reason"),
                subtitle: Text("From: $startDate → To: $endDate\nDays: $totalDays"),
                trailing: Text(
                  status,
                  style: TextStyle(
                    color: status == "Approved"
                        ? Colors.green
                        : status == "Rejected"
                            ? Colors.red
                            : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Close")),
        ],
      ),
    );
  }
}
