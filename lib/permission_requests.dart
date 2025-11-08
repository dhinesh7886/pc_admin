import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PermissionRequestsPage extends StatefulWidget {
  final String companyName;

  const PermissionRequestsPage({super.key, required this.companyName});

  @override
  State<PermissionRequestsPage> createState() => _PermissionRequestsPageState();
}

class _PermissionRequestsPageState extends State<PermissionRequestsPage> {
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

  String formatDate(dynamic date) {
    try {
      final dt = parseToDateTime(date);
      if (dt == null) return "N/A";
      return DateFormat('dd-MMM-yyyy').format(dt);
    } catch (e) {
      return "Invalid";
    }
  }

  String formatTime(dynamic date) {
    try {
      final dt = parseToDateTime(date);
      if (dt == null) return "N/A";
      return DateFormat('hh:mm a').format(dt);
    } catch (e) {
      return "Invalid";
    }
  }

  Future<void> updatePermissionStatus(
      String userId, String requestId, String status) async {
    try {
      await FirebaseFirestore.instance
          .collection("Users")
          .doc(userId)
          .collection("permission_request")
          .doc(requestId)
          .update({"status": status});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Permission request $status successfully")),
        );
        // 🔁 Refresh the UI
        setState(() {});
      }
    } catch (e) {
      debugPrint("Error updating status: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to update status: $e")),
      );
    }
  }

  Future<bool?> showConfirmationDialog(String action) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("$action Confirmation"),
        content:
            Text("Are you sure you want to $action this permission request?"),
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
        title: const Text("Permission Requests for Approval"),
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
                        "No permission requests pending for approval",
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

  Future<List<Widget>> _buildPendingRequests(
      List<QueryDocumentSnapshot> users, double padding) async {
    List<Widget> pendingRequests = [];

    for (var userDoc in users) {
      final userId = userDoc.id;
      final userData = userDoc.data() as Map<String, dynamic>;
      final userName = userData['name'] ?? userId;
      final employeeId = userData['id'] ?? "N/A"; // ✅ added Employee ID

      final permissionSnapshot = await FirebaseFirestore.instance
          .collection("Users")
          .doc(userId)
          .collection("permission_request")
          .where("status", isEqualTo: "Pending")
          .get();

      if (permissionSnapshot.docs.isEmpty) continue;

      for (var permissionDoc in permissionSnapshot.docs) {
        final permissionData = permissionDoc.data();
        final requestId = permissionDoc.id;

        final date = formatDate(permissionData['date']);
        final fromTime = formatTime(permissionData['fromTime']);
        final toTime = formatTime(permissionData['toTime']);
        final reason = permissionData['reason'] ?? "No reason provided";
        final department = permissionData['department'] ?? "N/A";
        final designation = permissionData['designation'] ?? "N/A";

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
                  // ✅ Employee Name + ID
                  Text(
                    "$userName ($employeeId)",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text("Department: $department",
                      style: const TextStyle(fontSize: 13)),
                  Text("Designation: $designation",
                      style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 6),
                  Text("Date: $date", style: const TextStyle(fontSize: 13)),
                  Text("From: $fromTime  To: $toTime",
                      style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 6),
                  Text("Reason: $reason", style: const TextStyle(fontSize: 14)),
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
                            await updatePermissionStatus(
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
                            await updatePermissionStatus(
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
