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
  bool isSelectMode = false;

  // Filters
  String? selectedDesignation;
  String? selectedDepartment;
  List<String> designations = [];
  List<String> departments = [];

  // Keep latest visible users (after applying filters) so AppBar buttons can act on them
  List<QueryDocumentSnapshot> currentVisibleUsers = [];

  Future<void> deleteUserFromFirebase(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('Users').doc(uid).delete();
    } catch (e) {
      print("Error while deleting an item: $e");
    }
  }

  Future<void> activateUserFromFirebase(String uid) async {
    try {
      await FirebaseFirestore.instance.collection('Users').doc(uid).update({
        "isActive": true,
      });
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
        final uid = data['uuid'] ?? u.id;
        if (selectedUserList.contains(uid)) {
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
        [XFile(filePath)],
        text: 'Selected Inactive Users List',
      );
    } catch (e) {
      print("Error exporting Excel: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to export Excel")),
        );
      }
    }
  }

  void _toggleSelectAllVisible() {
    final ids = currentVisibleUsers
        .map((u) {
          final data = u.data() as Map<String, dynamic>;
          return (data['uuid'] ?? u.id).toString();
        })
        .toSet()
        .toList();

    final allSelected = ids.every((id) => selectedUserList.contains(id));

    setState(() {
      if (allSelected) {
        selectedUserList.removeWhere((id) => ids.contains(id));
      } else {
        final current = selectedUserList.toSet();
        current.addAll(ids);
        selectedUserList = current.toList();
      }
    });
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
          if (isSelectMode)
            IconButton(
              tooltip: "Export & Share Selected",
              icon: const Icon(Icons.download),
              onPressed: () async {
                var snapshot = await FirebaseFirestore.instance
                    .collection('Users')
                    .where('isActive', isEqualTo: false)
                    .where('companyName', isEqualTo: widget.companyName)
                    .get();

                var users = snapshot.docs;

                if (selectedDesignation != null) {
                  users = users
                      .where((u) =>
                          (u['designation'] ?? '') == selectedDesignation)
                      .toList();
                }
                if (selectedDepartment != null) {
                  users = users
                      .where(
                          (u) => (u['department'] ?? '') == selectedDepartment)
                      .toList();
                }

                await exportSelectedToExcel(users);
              },
            ),
          if (!isSelectMode)
            TextButton(
              onPressed: () => setState(() => isSelectMode = true),
              child: const Text("Select", style: TextStyle(color: Colors.white)),
            ),
          if (isSelectMode)
            TextButton(
              onPressed: () => setState(() {
                isSelectMode = false;
                selectedUserList.clear();
              }),
              child: const Text("Cancel", style: TextStyle(color: Colors.white)),
            ),
          if (isSelectMode)
            TextButton(
              onPressed: _toggleSelectAllVisible,
              child: const Text("All", style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Users')
            .where('isActive', isEqualTo: false)
            .where('companyName', isEqualTo: widget.companyName)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            currentVisibleUsers = [];
            return const Center(child: Text("No inactive users found."));
          }

          var users = snapshot.data!.docs;

          designations = users
              .map((u) => (u['designation'] ?? '').toString())
              .where((s) => s.isNotEmpty)
              .toSet()
              .toList();

          departments = users
              .map((u) => (u['department'] ?? '').toString())
              .where((s) => s.isNotEmpty)
              .toSet()
              .toList();

          if (selectedDesignation != null) {
            users = users
                .where((u) => (u['designation'] ?? '') == selectedDesignation)
                .toList();
          }
          if (selectedDepartment != null) {
            users = users
                .where((u) => (u['department'] ?? '') == selectedDepartment)
                .toList();
          }

          currentVisibleUsers = users;

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
                            .map((d) =>
                                DropdownMenuItem(value: d, child: Text(d)))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => selectedDesignation = value),
                        isExpanded: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedDepartment,
                        hint: const Text("Filter by Department"),
                        items: departments
                            .map((d) =>
                                DropdownMenuItem(value: d, child: Text(d)))
                            .toList(),
                        onChanged: (value) =>
                            setState(() => selectedDepartment = value),
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
                    bool confirmed = await showConfirmationDialog(
                        "Confirm Delete", "Delete selected users?");
                    if (confirmed) {
                      for (var uid in selectedUserList) {
                        await deleteUserFromFirebase(uid);
                      }
                      selectedUserList.clear();
                      setState(() {});
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
                      setState(() {});
                    }
                  },
                  child: const Icon(Icons.done),
                ),
              ],
            ),
    );
  }

  Widget _buildUserCard(QueryDocumentSnapshot user) {
    final data = user.data() as Map<String, dynamic>;
    final uid = (data['uuid'] ?? user.id).toString();
    final isSelected = selectedUserList.contains(uid);

    return GestureDetector(
      onTap: () {
        if (!isSelectMode) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => UserDetailPage(
              userDetail: data,
              isActive: false,
              companyName: widget.companyName,
            ),
          ));
        } else {
          setState(() {
            if (isSelected) {
              selectedUserList.remove(uid);
            } else {
              selectedUserList.add(uid);
            }
          });
        }
      },
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
        color: isSelected ? Colors.lightBlue.shade100 : Colors.blue.shade50,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (isSelectMode)
                Checkbox(
                  value: isSelected,
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        if (!selectedUserList.contains(uid)) {
                          selectedUserList.add(uid);
                        }
                      } else {
                        selectedUserList.remove(uid);
                      }
                    });
                  },
                ),
              CircleAvatar(
                radius: 25,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: (data['imageUrl'] != null &&
                        data['imageUrl'] is String &&
                        (data['imageUrl'] as String).isNotEmpty)
                    ? NetworkImage(data['imageUrl'] as String)
                    : null,
                onBackgroundImageError: (_, __) {},
                child: (data['imageUrl'] == null ||
                        (data['imageUrl'] is String &&
                            (data['imageUrl'] as String).isEmpty))
                    ? const Icon(Icons.person, color: Colors.grey)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data['name'] ?? '',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text("ID: ${data['id'] ?? ''}"),
                    if ((data['designation'] ?? null) != null)
                      Text("Designation: ${data['designation']}"),
                    if ((data['department'] ?? null) != null)
                      Text("Dept: ${data['department']}"),
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
