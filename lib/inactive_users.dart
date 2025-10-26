import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pcadmin/user_detail_page.dart';
import 'package:share_plus/share_plus.dart';

class InactiveUsers extends StatefulWidget {
  final String companyName;

  const InactiveUsers({super.key, required this.companyName});

  @override
  State<InactiveUsers> createState() => _InactiveUsersState();
}

class _InactiveUsersState extends State<InactiveUsers> {
  List<String> selectedUserList = [];
  bool isSelect = false;
  bool isSelectAll = false;

  // Filters
  String? selectedDesignation;
  String? selectedDepartment;
  List<String> designations = [];
  List<String> departments = [];

  Future<void> deleteUserFromFirebase(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('Users').doc(uid).delete();
      setState(() {});
    } catch (e) {
      print("Error while deleting an item: $e");
    }
  }

  Future<void> activateUserFromFirebase(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('Users').doc(uid).update({
        "isActive": true,
      });
      setState(() {});
    } catch (e) {
      print("Error while activating an item: $e");
    }
  }

  Future<bool> showConfirmationDialog(String title, String content) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(content),
            actions: [
              TextButton(
                child: const Text("Cancel"),
                onPressed: () => Navigator.of(context).pop(false),
              ),
              ElevatedButton(
                child: const Text("Confirm"),
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> exportSelectedToExcel(List<QueryDocumentSnapshot> users) async {
    if (selectedUserList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Select at least one user to export.")),
      );
      return;
    }

    try {
      var excel = Excel.createExcel();
      Sheet sheet = excel['InactiveUsers'];

      sheet.appendRow([
        'Name',
        'ID',
        'Designation',
        'Department',
        'Email',
        'Contact',
        'Address',
        'Company Name',
        'Gender',
        'SubDivision'
      ]);

      for (var u in users) {
        final data = u.data() as Map<String, dynamic>;
        if (selectedUserList.contains(data['uuid'])) {
          sheet.appendRow([
            data['name'] ?? '',
            data['id'] ?? '',
            data['designation'] ?? '',
            data['department'] ?? '',
            data['email'] ?? '',
            data['contact'] ?? '',
            data['address'] ?? '',
            data['companyName'] ?? '',
            data['gender'] ?? '',
            data['subDivision'] ?? '',
          ]);
        }
      }

      Directory dir = await getApplicationDocumentsDirectory();
      String filePath =
          '${dir.path}/InactiveUsers_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(excel.encode()!);

      await Share.shareXFiles(
          [XFile(filePath)], text: 'Selected Inactive Users List');
    } catch (e) {
      print("Error exporting Excel: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to export Excel")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Inactive Users"),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.pinkAccent, Colors.deepPurpleAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          if (isSelect)
            IconButton(
              tooltip: "Export & Share Selected",
              icon: const Icon(Icons.download),
              onPressed: () async {
                var snapshot = await FirebaseFirestore.instance
                    .collection('Users')
                    .where('isActive', isEqualTo: false)
                    .where('companyName', isEqualTo: widget.companyName) // ✅ company filter
                    .get();

                var users = snapshot.docs;

                if (selectedDesignation != null) {
                  users = users
                      .where((u) => u['designation'] == selectedDesignation)
                      .toList();
                }
                if (selectedDepartment != null) {
                  users = users
                      .where((u) => u['department'] == selectedDepartment)
                      .toList();
                }

                await exportSelectedToExcel(users);
              },
            ),
          if (!isSelect)
            TextButton(
              onPressed: () => setState(() => isSelect = true),
              child: const Text("Select", style: TextStyle(color: Colors.white)),
            ),
          if (isSelect)
            TextButton(
              onPressed: () => setState(() => isSelectAll = true),
              child: const Text("All", style: TextStyle(color: Colors.white)),
            ),
          if (isSelect)
            TextButton(
              onPressed: () => setState(() {
                isSelect = false;
                selectedUserList.clear();
              }),
              child: const Text("Cancel", style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Users')
            .where('isActive', isEqualTo: false)
            .where('companyName', isEqualTo: widget.companyName) // ✅ only current company
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No inactive users found."));
          }

          var users = snapshot.data!.docs;

          // Populate filters dynamically
          designations = users
              .map((u) => u['designation']?.toString() ?? "")
              .toSet()
              .toList();
          designations.removeWhere((d) => d.isEmpty);

          departments = users
              .map((u) => u['department']?.toString() ?? "")
              .toSet()
              .toList();
          departments.removeWhere((d) => d.isEmpty);

          // Apply filters
          if (selectedDesignation != null) {
            users = users
                .where((u) => u['designation'] == selectedDesignation)
                .toList();
          }
          if (selectedDepartment != null) {
            users = users
                .where((u) => u['department'] == selectedDepartment)
                .toList();
          }

          // Select All logic
          if (isSelectAll) {
            selectedUserList =
                users.map((u) => u['uuid'].toString()).toList();
            isSelectAll = false;
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedDesignation,
                        hint: const Text("Filter by Designation"),
                        items: designations
                            .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                            .toList(),
                        onChanged: (value) => setState(() => selectedDesignation = value),
                        isExpanded: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedDepartment,
                        hint: const Text("Filter by Department"),
                        items: departments
                            .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                            .toList(),
                        onChanged: (value) => setState(() => selectedDepartment = value),
                        isExpanded: true,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => setState(() {
                        selectedDesignation = null;
                        selectedDepartment = null;
                      }),
                    )
                  ],
                ),
              ),
              Expanded(
                child: isWideScreen
                    ? GridView.builder(
                        padding: const EdgeInsets.all(10),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: screenWidth > 900 ? 3 : 2,
                          childAspectRatio: 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          return _buildUserCard(users[index]);
                        },
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(10),
                        itemCount: users.length,
                        itemBuilder: (context, index) {
                          return _buildUserCard(users[index]);
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: selectedUserList.isEmpty
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: "deleteBtn",
                  backgroundColor: Colors.red,
                  onPressed: () async {
                    bool confirmed =
                        await showConfirmationDialog("Confirm Delete", "Delete selected users?");
                    if (confirmed) {
                      for (var uid in selectedUserList) {
                        await deleteUserFromFirebase(uid);
                      }
                      selectedUserList.clear();
                    }
                  },
                  child: const Icon(Icons.delete),
                ),
                const SizedBox(width: 12),
                FloatingActionButton(
                  heroTag: "activateBtn",
                  backgroundColor: Colors.green,
                  onPressed: () async {
                    bool confirmed = await showConfirmationDialog(
                        "Confirm Activation", "Activate selected users?");
                    if (confirmed) {
                      for (var uid in selectedUserList) {
                        await activateUserFromFirebase(uid);
                      }
                      selectedUserList.clear();
                    }
                  },
                  child: const Icon(Icons.done),
                ),
              ],
            ),
    );
  }

  Widget _buildUserCard(QueryDocumentSnapshot user) {
    final userData = user.data() as Map<String, dynamic>;

    return GestureDetector(
      onTap: () {
        if (!isSelect) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => UserDetailPage(
                userDetail: userData,
                isActive: false,
                companyName: widget.companyName,
              ),
            ),
          );
        } else {
          setState(() {
            if (selectedUserList.contains(userData['uuid'])) {
              selectedUserList.remove(userData['uuid']);
            } else {
              selectedUserList.add(userData['uuid']);
            }
          });
        }
      },
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        color: Colors.blue.shade50,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (isSelect)
                Checkbox(
                  value: selectedUserList.contains(userData['uuid']),
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        selectedUserList.add(userData['uuid']);
                      } else {
                        selectedUserList.remove(userData['uuid']);
                      }
                    });
                  },
                ),
              CircleAvatar(
                radius: 25,
                backgroundImage: NetworkImage(userData['imageUrl'] ?? ''),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(userData['name'] ?? '',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text("ID: ${userData['id'] ?? ''}"),
                    if (userData['designation'] != null)
                      Text("Designation: ${userData['designation']}"),
                    if (userData['department'] != null)
                      Text("Dept: ${userData['department']}"),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
