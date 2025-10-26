import 'package:flutter/material.dart';
import 'package:pcadmin/admin_home.dart';
import 'package:pcadmin/create_users.dart';
import 'package:pcadmin/inactive_users.dart';
import 'package:pcadmin/view_user.dart';

class UsersPage extends StatelessWidget {
  final String companyName;
  const UsersPage({super.key, required this.companyName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text(
          'Users',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.green,
        elevation: 4,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
        leading: IconButton(
          onPressed: () {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => AdminHomePage(companyName: companyName),
              ),
            );
          },
          icon: const Icon(Icons.arrow_back, color: Colors.white),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          bool isWide = constraints.maxWidth > 600; // tablet/web check
          return GridView.count(
            padding: const EdgeInsets.all(20),
            crossAxisCount: isWide ? 3 : 1,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: isWide ? 1.2 : 2.8,
            children: [
              _buildOptionCard(
                label: "Create Users",
                icon: Icons.person_add,
                color1: Colors.orangeAccent,
                color2: Colors.deepOrange,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          CreateUsersPage(companyName: companyName),
                    ),
                  );
                },
              ),
              _buildOptionCard(
                label: "View/Edit Users",
                icon: Icons.manage_accounts,
                color1: Colors.blueAccent,
                color2: Colors.indigo,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          ViewUserScreen(companyName: companyName),
                    ),
                  );
                },
              ),
              _buildOptionCard(
                label: "Inactive Users",
                icon: Icons.block,
                color1: Colors.yellow.shade700,
                color2: Colors.orange.shade800,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) =>
                          InactiveUsers(companyName: companyName),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildOptionCard({
    required String label,
    required IconData icon,
    required Color color1,
    required Color color2,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color1, color2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: color2.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 50, color: Colors.white),
            const SizedBox(height: 12),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1.1,
              ),
            )
          ],
        ),
      ),
    );
  }
}
