import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pcadmin/admin_home.dart';
import 'package:pcadmin/user_detail_page.dart';
import 'package:pcadmin/users.dart';
import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';

class ViewUserScreen extends StatefulWidget {
  final String companyName;

  const ViewUserScreen({super.key, required this.companyName});

  @override
  State<ViewUserScreen> createState() => _ViewUserScreenState();
}

class _ViewUserScreenState extends State<ViewUserScreen> {
  List<String> selectedUserList = [];
  bool isSelectMode = false;
  bool isSelectAll = false;

  TextEditingController searchController = TextEditingController();
  bool isSearching = false;
  String searchQuery = "";

  // Filter variables
  String? selectedDesignation;
  String? selectedDepartment;

  List<String> designations = [];
  List<String> departments = [];

  Future<void> deleteUserFromFirebase(String docId) async {
    try {
      await FirebaseFirestore.instance.collection('Users').doc(docId).delete();
      setState(() {});
    } catch (e) {
      print("Error deleting item: $e");
    }
  }

  Future<void> inactivateUserFromFirebase(String docId) async {
    try {
      await FirebaseFirestore.instance
          .collection('Users')
          .doc(docId)
          .update({"isActive": false});
      setState(() {});
    } catch (e) {
      print("Error inactivating item: $e");
    }
  }

  Future<void> showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Confirm"),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      onConfirm();
    }
  }

  // ===== XLSX EXPORT =====
  Future<void> exportToExcel(List<QueryDocumentSnapshot> users) async {
    try {
      var excel = Excel.createExcel();
      Sheet sheet = excel['Users'];

      // Headers
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

      // Add rows
      for (var u in users) {
        final data = u.data() as Map<String, dynamic>;
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

      // Save file in app documents directory
      Directory dir = await getApplicationDocumentsDirectory();
      String filePath =
          '${dir.path}/Users_${DateTime.now().millisecondsSinceEpoch}.xlsx';
      File(filePath)
        ..createSync(recursive: true)
        ..writeAsBytesSync(excel.encode()!);

      // Share file
      await Share.shareXFiles([XFile(filePath)], text: 'User Details');
    } catch (e) {
      print("Error exporting Excel: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Failed to export Excel")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    return Scaffold(
      appBar: AppBar(
        title: isSearching
            ? TextField(
                controller: searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search by Name or ID',
                  border: InputBorder.none,
                ),
                onChanged: (value) {
                  setState(() {
                    searchQuery = value.toLowerCase();
                  });
                },
              )
            : const Text("View Users"),
        backgroundColor: Colors.pinkAccent,
        actions: [
          if (!isSearching)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => setState(() => isSearching = true),
            ),
          if (isSearching)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () => setState(() {
                isSearching = false;
                searchQuery = "";
                searchController.clear();
              }),
            ),
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Export & Share XLSX',
            onPressed: () async {
              var snapshot = await FirebaseFirestore.instance
                  .collection('Users')
                  .where('isActive', isEqualTo: true)
                  .where('companyName', isEqualTo: widget.companyName)
                  .get();

              var users = snapshot.docs;

              // Apply search filter
              if (searchQuery.isNotEmpty) {
                users = users.where((doc) {
                  final name = doc['name'].toString().toLowerCase();
                  final id = doc['id'].toString().toLowerCase();
                  return name.contains(searchQuery) || id.contains(searchQuery);
                }).toList();
              }

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

              await exportToExcel(users);
            },
          ),
          if (!isSelectMode)
            TextButton(
              onPressed: () => setState(() => isSelectMode = true),
              child: const Text("Select", style: TextStyle(color: Colors.white)),
            ),
          if (isSelectMode)
            TextButton(
              onPressed: () {
                setState(() {
                  isSelectAll = true;
                });
              },
              child: const Text("All", style: TextStyle(color: Colors.white)),
            ),
          if (isSelectMode)
            TextButton(
              onPressed: () => setState(() {
                isSelectMode = false;
                selectedUserList.clear();
              }),
              child: const Text("Cancel", style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('Users')
            .where('isActive', isEqualTo: true)
            .where('companyName', isEqualTo: widget.companyName)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Column(
              children: [
                _buildFilterRow(),
                const SizedBox(height: 20),
                const Center(child: Text("No users found.")),
              ],
            );
          }

          var users = snapshot.data!.docs;

          // Populate filter dropdowns dynamically
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

          // Apply search filter
          if (searchQuery.isNotEmpty) {
            users = users.where((doc) {
              final name = doc['name'].toString().toLowerCase();
              final id = doc['id'].toString().toLowerCase();
              return name.contains(searchQuery) || id.contains(searchQuery);
            }).toList();
          }

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

          // Sort alphabetically
          users.sort((a, b) => a['name']
              .toString()
              .toLowerCase()
              .compareTo(b['name'].toString().toLowerCase()));

          // Select All logic
          if (isSelectAll) {
            selectedUserList = users.map((u) => u.id).toList(); // ✅ use doc ID
            isSelectAll = false;
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(10),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Column(
                children: [
                  _buildFilterRow(),
                  const SizedBox(height: 10),
                  if (users.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 20),
                      child: Center(
                        child: Text("No users match your search or filters."),
                      ),
                    )
                  else
                    isWideScreen
                        ? GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: screenWidth > 900 ? 3 : 2,
                              childAspectRatio: 3,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: users.length,
                            itemBuilder: (context, index) {
                              final user = users[index];
                              return _buildUserCard(user);
                            },
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: users.length,
                            itemBuilder: (context, index) {
                              final user = users[index];
                              return _buildUserCard(user);
                            },
                          ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: selectedUserList.isEmpty
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: "deleteBtn",
                  onPressed: () {
                    showConfirmationDialog(
                      context: context,
                      title: "Delete Confirmation",
                      content: "Are you sure you want to delete selected users?",
                      onConfirm: () async {
                        for (var docId in selectedUserList) {
                          await deleteUserFromFirebase(docId);
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text("User(s) deleted successfully")),
                        );
                        setState(() {
                          selectedUserList.clear();
                        });
                      },
                    );
                  },
                  backgroundColor: Colors.red,
                  child: const Icon(Icons.delete),
                ),
                const SizedBox(width: 12),
                FloatingActionButton(
                  heroTag: "inactivateBtn",
                  onPressed: () {
                    showConfirmationDialog(
                      context: context,
                      title: "Inactivate Confirmation",
                      content:
                          "Are you sure you want to inactivate selected users?",
                      onConfirm: () async {
                        for (var docId in selectedUserList) {
                          await inactivateUserFromFirebase(docId);
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text("User(s) inactivated successfully")),
                        );
                        setState(() {
                          selectedUserList.clear();
                        });
                      },
                    );
                  },
                  backgroundColor: Colors.blue,
                  child: const Icon(Icons.close),
                ),
              ],
            ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1,
        selectedItemColor: Colors.pinkAccent,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    AdminHomePage(companyName: widget.companyName),
              ),
            );
          } else if (index == 1) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    UsersPage(companyName: widget.companyName),
              ),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: "Users"),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            value: selectedDesignation,
            hint: const Text("Select Designation"),
            items: designations
                .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                .toList(),
            onChanged: (value) => setState(() {
              selectedDesignation = value;
            }),
            isExpanded: true,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: selectedDepartment,
            hint: const Text("Select Department"),
            items: departments
                .map((d) => DropdownMenuItem(value: d, child: Text(d)))
                .toList(),
            onChanged: (value) => setState(() {
              selectedDepartment = value;
            }),
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
    );
  }

  Widget _buildUserCard(QueryDocumentSnapshot user) {
    final userData = user.data() as Map<String, dynamic>;

    return GestureDetector(
      onTap: () {
        if (!isSelectMode) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => UserDetailPage(
                userDetail: userData,
                isActive: true,
                companyName: widget.companyName,
              ),
            ),
          );
        } else {
          setState(() {
            if (selectedUserList.contains(user.id)) {
              selectedUserList.remove(user.id);
            } else {
              selectedUserList.add(user.id);
            }
          });
        }
      },
      child: Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        color: Colors.blue.shade50,
        margin: const EdgeInsets.symmetric(vertical: 6),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              if (isSelectMode)
                Checkbox(
                  value: selectedUserList.contains(user.id),
                  onChanged: (value) {
                    setState(() {
                      if (value == true) {
                        selectedUserList.add(user.id);
                      } else {
                        selectedUserList.remove(user.id);
                      }
                    });
                  },
                ),
              CircleAvatar(
                radius: 28,
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
                    Text("ID: ${userData['id'] ?? ''}",
                        style: const TextStyle(fontSize: 14)),
                    if (userData['designation'] != null)
                      Text("Designation: ${userData['designation']}",
                          style: const TextStyle(fontSize: 14)),
                    if (userData['department'] != null)
                      Text("Dept: ${userData['department']}",
                          style: const TextStyle(fontSize: 14)),
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
