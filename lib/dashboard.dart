import 'package:flutter/material.dart';
import 'package:pcadmin/leave_requests.dart';
import 'view_attendance.dart'; // AdminAttendancePage import

class DashboardPage extends StatelessWidget {
  final String companyName;

  const DashboardPage({super.key, required this.companyName});

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    // Responsive settings
    int crossAxisCount = 1;
    double childAspectRatio = 3;
    double iconSize = 40;
    double fontSize = 18;
    double spacing = 8;

    if (screenWidth > 1200) {
      crossAxisCount = 3;
      childAspectRatio = 1.2;
      iconSize = 50;
      fontSize = 20;
      spacing = 10;
    } else if (screenWidth > 800) {
      crossAxisCount = 2;
      childAspectRatio = 1.3;
      iconSize = 45;
      fontSize = 19;
      spacing = 9;
    }

    final List<_DashboardItem> items = [
      _DashboardItem(
        title: "Attendance Data",
        icon: Icons.access_time,
        color: Colors.blue,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  AdminAttendancePage(companyName: companyName),
            ),
          );
        },
      ),
      _DashboardItem(
        title: "Leave Request",
        icon: Icons.beach_access,
        color: Colors.green,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) =>
                  LeaveRequestsPage(companyName: companyName),
            ),
          );
        },
      ),
      _DashboardItem(
        title: "Permission Request",
        icon: Icons.assignment_turned_in,
        color: Colors.orange,
        onTap: () {},
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text("Dashboard - $companyName"),
        backgroundColor: Colors.teal,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: GridView.builder(
          shrinkWrap: true, // ✅ wrap content
          padding: const EdgeInsets.all(16.0),
          itemCount: items.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 20,
            crossAxisSpacing: 20,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return GestureDetector(
              onTap: item.onTap,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [item.color.withOpacity(0.8), item.color],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: item.color.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(item.icon, size: iconSize, color: Colors.white),
                      SizedBox(height: spacing),
                      Text(
                        item.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: fontSize,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _DashboardItem {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  _DashboardItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}
