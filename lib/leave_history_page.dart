import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class LeaveHistoryPage extends StatefulWidget {
  final String companyName;

  const LeaveHistoryPage({super.key, required this.companyName});

  @override
  State<LeaveHistoryPage> createState() => _LeaveHistoryPageState();
}

class _LeaveHistoryPageState extends State<LeaveHistoryPage> {
  String _selectedStatus = "All";
  String _sortOrder = "Newest First";
  String _searchQuery = "";

  // 🔹 Format Firestore Timestamp or String into DD-MMM-YYYY
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

  // 🔹 Calculate total days between start and end
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
      ),
      body: Column(
        children: [
          // 🔹 Filters Section
          Padding(
            padding: EdgeInsets.all(padding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search by Name or ID
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

                // Filter and Sort Dropdowns
                Row(
                  children: [
                    // Filter dropdown
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedStatus,
                        decoration: const InputDecoration(
                          labelText: "Filter by Status",
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: "All", child: Text("All")),
                          DropdownMenuItem(value: "Approved", child: Text("Approved")),
                          DropdownMenuItem(value: "Rejected", child: Text("Rejected")),
                          DropdownMenuItem(value: "Pending", child: Text("Pending")),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedStatus = value!);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Sort dropdown
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _sortOrder,
                        decoration: const InputDecoration(
                          labelText: "Sort by Date",
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(value: "Newest First", child: Text("Newest First")),
                          DropdownMenuItem(value: "Oldest First", child: Text("Oldest First")),
                        ],
                        onChanged: (value) {
                          setState(() => _sortOrder = value!);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 🔹 Leave History List
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection("Users")
                  .where("companyName", isEqualTo: widget.companyName)
                  .snapshots(),
              builder: (context, usersSnapshot) {
                if (usersSnapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!usersSnapshot.hasData || usersSnapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No users found"));
                }

                final users = usersSnapshot.data!.docs;

                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: _fetchLeaveHistory(users),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(
                        child: Text("No leave records found"),
                      );
                    }

                    var leaveList = snapshot.data!;

                    // 🔹 Apply Search
                    if (_searchQuery.isNotEmpty) {
                      leaveList = leaveList.where((l) {
                        final name = l["userName"].toString().toLowerCase();
                        final empId = l["empId"].toString().toLowerCase();
                        return name.contains(_searchQuery) || empId.contains(_searchQuery);
                      }).toList();
                    }

                    // 🔹 Apply Status Filter
                    if (_selectedStatus != "All") {
                      leaveList = leaveList
                          .where((l) => l["status"] == _selectedStatus)
                          .toList();
                    }

                    // 🔹 Sort by Date
                    leaveList.sort((a, b) {
                      final dateA = a["startDate"] ?? DateTime.now();
                      final dateB = b["startDate"] ?? DateTime.now();
                      return _sortOrder == "Newest First"
                          ? dateB.compareTo(dateA)
                          : dateA.compareTo(dateB);
                    });

                    return ListView.builder(
                      padding: EdgeInsets.symmetric(horizontal: padding),
                      itemCount: leaveList.length,
                      itemBuilder: (context, index) {
                        final leave = leaveList[index];
                        final userName = leave["userName"];
                        final empId = leave["empId"];
                        final reason = leave["reason"];
                        final startDate = formatDate(leave["startDate"]);
                        final endDate = formatDate(leave["endDate"]);
                        final totalDays =
                            calculateTotalDays(leave["startDate"], leave["endDate"]);
                        final status = leave["status"];

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.all(12),
                            title: Text(
                              "$userName ($empId)",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: textSize + 1,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 4),
                                Text("Reason: $reason", style: TextStyle(fontSize: textSize)),
                                Text("From: $startDate", style: TextStyle(fontSize: textSize)),
                                Text("To: $endDate", style: TextStyle(fontSize: textSize)),
                                Text("Total Days: $totalDays",
                                    style: TextStyle(fontSize: textSize)),
                                const SizedBox(height: 6),
                                Text(
                                  "Status: $status",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: status == "Approved"
                                        ? Colors.green
                                        : status == "Rejected"
                                            ? Colors.red
                                            : Colors.orange,
                                    fontSize: textSize,
                                  ),
                                ),
                              ],
                            ),
                            onTap: () {
                              _showLeaveDetails(context, leave);
                            },
                          ),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 🔹 Fetch leave data from all users
  Future<List<Map<String, dynamic>>> _fetchLeaveHistory(
      List<QueryDocumentSnapshot> users) async {
    List<Map<String, dynamic>> allLeaves = [];

    for (var userDoc in users) {
      final userId = userDoc.id;
      final userData = userDoc.data() as Map<String, dynamic>;
      final userName = userData['name'] ?? userId;
      final empId = userData['id'] ?? userId; // ✅ Corrected field

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

  // 🔹 Show Leave Details in Dialog
  void _showLeaveDetails(BuildContext context, Map<String, dynamic> leave) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("${leave['userName']} (${leave['empId']})"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Reason: ${leave['reason']}"),
            Text("From: ${formatDate(leave['startDate'])}"),
            Text("To: ${formatDate(leave['endDate'])}"),
            Text(
              "Status: ${leave['status']}",
              style: TextStyle(
                color: leave['status'] == "Approved"
                    ? Colors.green
                    : leave['status'] == "Rejected"
                        ? Colors.red
                        : Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      ),
    );
  }
}
