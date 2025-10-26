import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class LeaveRequestsPage extends StatefulWidget {
  final String companyName;

  const LeaveRequestsPage({super.key, required this.companyName});

  @override
  State<LeaveRequestsPage> createState() => _LeaveRequestsPageState();
}

class _LeaveRequestsPageState extends State<LeaveRequestsPage> {
  // Parse various date representations to DateTime (Timestamp, String, DateTime)
  DateTime? parseToDateTime(dynamic date) {
    try {
      if (date == null) return null;
      if (date is Timestamp) return date.toDate();
      if (date is DateTime) return date;
      if (date is String) {
        // Try ISO-8601 parse first
        final dt = DateTime.tryParse(date);
        if (dt != null) return dt;
        // If parsing fails, return null
        return null;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // Format to DD-MMM-YYYY
  String formatDate(dynamic date) {
    try {
      final dt = parseToDateTime(date);
      if (dt == null) return "N/A";
      return DateFormat('dd-MMM-yyyy').format(dt);
    } catch (e) {
      return "Invalid";
    }
  }

  // Calculate inclusive days between start and end (if possible)
  String computeDaysText(dynamic start, dynamic end) {
    final s = parseToDateTime(start);
    final e = parseToDateTime(end);
    if (s == null || e == null) return "";
    final diff = e.difference(s).inDays + 1; // inclusive
    if (diff <= 0) return "";
    return " • $diff ${diff == 1 ? 'day' : 'days'}";
  }

  // 🔹 Update leave status
  Future<void> updateLeaveStatus(
      String userId, String requestId, String status) async {
    try {
      await FirebaseFirestore.instance
          .collection("Users")
          .doc(userId)
          .collection("leave_requests")
          .doc(requestId)
          .update({"status": status});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Leave request $status successfully")),
      );
    } catch (e) {
      debugPrint("Error updating status: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update status: $e")),
      );
    }
  }

  // 🔹 Show confirmation dialog
  Future<bool?> showConfirmationDialog(String action) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("$action Confirmation"),
        content: Text("Are you sure you want to $action this leave request?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: action == "Approve" ? Colors.green : Colors.red,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(action),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Leave Requests for Approval"),
        centerTitle: true,
        backgroundColor: Colors.indigo,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final padding = width * 0.05;

          return StreamBuilder<QuerySnapshot>(
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

              return FutureBuilder<List<Widget>>(
                future: _buildPendingRequests(users, padding),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text(
                        "No leave requests waiting for approval",
                        style: TextStyle(fontSize: 18),
                      ),
                    );
                  }

                  return ListView(children: snapshot.data!);
                },
              );
            },
          );
        },
      ),
    );
  }

  // 🔹 Build pending requests dynamically
  Future<List<Widget>> _buildPendingRequests(
      List<QueryDocumentSnapshot> users, double padding) async {
    List<Widget> pendingRequests = [];

    for (var userDoc in users) {
      final userId = userDoc.id;
      final userData = userDoc.data() as Map<String, dynamic>;
      final userName = userData['name'] ?? userId;

      // Fetch only requests waiting for approval
      final leaveSnapshot = await FirebaseFirestore.instance
          .collection("Users")
          .doc(userId)
          .collection("leave_requests")
          .where("status", isEqualTo: "Waiting for Approval")
          .get();

      if (leaveSnapshot.docs.isEmpty) continue;

      for (var leaveDoc in leaveSnapshot.docs) {
        final leaveData = leaveDoc.data();
        final requestId = leaveDoc.id;

        // parse dates and compute days
        final startDateRaw = leaveData['startDate'];
        final endDateRaw = leaveData['endDate'];
        final startDateStr = formatDate(startDateRaw);
        final endDateStr = formatDate(endDateRaw);
        final daysSuffix = computeDaysText(startDateRaw, endDateRaw); // " • X days"

        final reason = leaveData['reason'] ?? "No reason provided";

        pendingRequests.add(
          Card(
            margin: EdgeInsets.symmetric(horizontal: padding, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    userName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Reason with days count shown inline
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          "Reason: $reason",
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      if (daysSuffix.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.indigo.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            daysSuffix.replaceFirst(" • ", ""), // show just "X days"
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: Colors.indigo,
                            ),
                          ),
                        )
                    ],
                  ),

                  const SizedBox(height: 6),

                  // From / To lines with formatted dates
                  Row(
                    children: [
                      Text("From: $startDateStr",
                          style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 12),
                      Text("To: $endDateStr", style: const TextStyle(fontSize: 13)),
                    ],
                  ),

                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green),
                        onPressed: () async {
                          final confirm =
                              await showConfirmationDialog("Approve");
                          if (confirm ?? false) {
                            await updateLeaveStatus(
                                userId, requestId, "Approved");
                          }
                        },
                        child: const Text("Approve"),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        style:
                            ElevatedButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () async {
                          final confirm = await showConfirmationDialog("Reject");
                          if (confirm ?? false) {
                            await updateLeaveStatus(
                                userId, requestId, "Rejected");
                          }
                        },
                        child: const Text("Reject"),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    return pendingRequests;
  }
}
