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
  // Parse any Firestore or string date
  DateTime? parseToDateTime(dynamic date) {
    try {
      if (date == null) return null;
      if (date is Timestamp) return date.toDate();
      if (date is DateTime) return date;
      if (date is String) return DateTime.tryParse(date);
      return null;
    } catch (_) {
      return null;
    }
  }

  // Format date to DD-MMM-YYYY
  String formatDate(dynamic date) {
    final dt = parseToDateTime(date);
    if (dt == null) return "N/A";
    return DateFormat('dd-MMM-yyyy').format(dt);
  }

  // Calculate leave duration (inclusive)
  String computeDaysText(dynamic start, dynamic end) {
    final s = parseToDateTime(start);
    final e = parseToDateTime(end);
    if (s == null || e == null) return "";
    final diff = e.difference(s).inDays + 1;
    return diff > 0 ? " • $diff ${diff == 1 ? 'day' : 'days'}" : "";
  }

  // Update leave status
  Future<void> updateLeaveStatus(
      String userId, String requestId, String status) async {
    await FirebaseFirestore.instance
        .collection("Users")
        .doc(userId)
        .collection("leave_requests")
        .doc(requestId)
        .update({"status": status});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Leave request $status successfully")),
    );

    setState(() {});
  }

  // Confirmation dialog
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

  // --- MAIN BUILD ---
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
          final padding = width > 600 ? width * 0.15 : width * 0.05; // responsive padding

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
                        "No current or upcoming leave requests",
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

  // --- BUILD REQUEST CARDS ---
  Future<List<Widget>> _buildPendingRequests(
      List<QueryDocumentSnapshot> users, double padding) async {
    List<Widget> pendingRequests = [];
    final today = DateTime.now();

    for (var userDoc in users) {
      final userId = userDoc.id;
      final userData = userDoc.data() as Map<String, dynamic>;
      final userName = userData['name'] ?? userId;
      final employeeId = userData['id'] ?? "N/A";

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

        final startDate = parseToDateTime(leaveData['startDate']);
        final endDate = parseToDateTime(leaveData['endDate']);
        final reason = leaveData['reason'] ?? "No reason provided";

        // Auto Reject past leave requests not acted on
        if (endDate != null && endDate.isBefore(today)) {
          await FirebaseFirestore.instance
              .collection("Users")
              .doc(userId)
              .collection("leave_requests")
              .doc(requestId)
              .update({"status": "Rejected"});
          continue; // skip past rejected ones
        }

        // Show only current and upcoming
        if (endDate != null && endDate.isAfter(today.subtract(const Duration(days: 1)))) {
          final startDateStr = formatDate(startDate);
          final endDateStr = formatDate(endDate);
          final daysSuffix = computeDaysText(startDate, endDate);

          pendingRequests.add(
            Card(
              margin: EdgeInsets.symmetric(horizontal: padding, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Employee Name + ID
                    Text(
                      "$userName ($employeeId)",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Reason + Days
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
                              daysSuffix.replaceFirst(" • ", ""),
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

                    // Dates
                    Row(
                      children: [
                        Text("From: ${formatDate(startDate)}",
                            style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 12),
                        Text("To: ${formatDate(endDate)}",
                            style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Buttons
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
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red),
                          onPressed: () async {
                            final confirm =
                                await showConfirmationDialog("Reject");
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
    }

    return pendingRequests;
  }
}
