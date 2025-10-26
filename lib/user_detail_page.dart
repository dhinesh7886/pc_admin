import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:geocoding/geocoding.dart'; // No longer used, but keeping imports consistent
import 'package:pcadmin/admin_home.dart';
import 'package:pcadmin/edit_user.dart';
import 'package:pcadmin/users.dart';

class UserDetailPage extends StatefulWidget {
  final bool isActive;
  final Map<String, dynamic> userDetail;
  final String companyName;

  const UserDetailPage({
    super.key,
    required this.userDetail,
    required this.isActive,
    required this.companyName,
  });

  @override
  State<UserDetailPage> createState() => _UserDetailPageState();
}

class _UserDetailPageState extends State<UserDetailPage> {
  int _selectedIndex = 1; // Users tab selected by default

  @override
  void initState() {
    super.initState();
    // No data fetching is needed, so initState is simple.
  }

  // Helper function to safely extract and format coordinates for display
  String _getCoordinateDisplay(String geoKey) {
    // --- Geofencing 1 (Top-level lat/lng) ---
    if (geoKey == 'geofencing1') {
      final lat = widget.userDetail['lat'];
      final lng = widget.userDetail['lng'];
      if (lat != null && lng != null) {
        return 'Lat: $lat, Lng: $lng';
      }
      return 'N/A';
    }

    // --- Other geofences (2, 3, 4) stored as nested Maps ---
    final geoData = widget.userDetail[geoKey];

    if (geoData != null && geoData is Map<String, dynamic>) {
      final lat = geoData['lat'];
      final lng = geoData['lng'];
      if (lat != null && lng != null) {
        return 'Lat: $lat, Lng: $lng';
      }
      return 'Invalid Data Format';
    }

    // Returns 'N/A' if the geofencing field is null/missing/wrong type (as seen in screenshot)
    return 'N/A';
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (index == 0) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => AdminHomePage(companyName: widget.companyName),
        ),
      );
    } else if (index == 1) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (context) => UsersPage(companyName: widget.companyName),
        ),
      );
    }
  }

  Widget buildRow(String label, String? value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150.w,
            child: Text(
              label,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16.sp,
                  color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value?.isNotEmpty == true ? value! : '-',
              style: TextStyle(fontSize: 16.sp),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildUserInfoCard(Map<String, dynamic> user) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      margin: EdgeInsets.symmetric(vertical: 10.h, horizontal: 10.w),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            Center(
              child: CircleAvatar(
                radius: 60.r,
                backgroundColor: Colors.grey.shade200,
                backgroundImage: (user['imageUrl'] != null &&
                        user['imageUrl'].toString().isNotEmpty)
                    ? NetworkImage(user['imageUrl'])
                    : null,
                child: (user['imageUrl'] == null ||
                        user['imageUrl'].toString().isEmpty)
                    ? Icon(Icons.person, size: 60.r, color: Colors.grey)
                    : null,
              ),
            ),
            SizedBox(height: 20.h),
            Wrap(
              runSpacing: 12.h,
              spacing: 20.w,
              children: [
                SizedBox(width: 300.w, child: buildRow("Name", user['name'])),
                SizedBox(width: 300.w, child: buildRow("Gender", user['gender'])),
                SizedBox(width: 300.w, child: buildRow("Employee ID", user['id'])),
                SizedBox(width: 300.w, child: buildRow("Company Name", user['companyName'])),
                SizedBox(width: 300.w, child: buildRow("Division", user['subDivision'])),
                SizedBox(width: 300.w, child: buildRow("Department", user['department'])),
                SizedBox(width: 300.w, child: buildRow("Designation", user['designation'])),
                SizedBox(width: 300.w, child: buildRow("Cell Number", user['contact'])),
                SizedBox(width: 300.w, child: buildRow("Email ID", user['email'])),
                SizedBox(width: 300.w, child: buildRow("Address", user['address'])),

                // Display Geofencing Coordinates directly from userDetail
                for (int i = 1; i <= 4; i++)
                  SizedBox(
                    width: 300.w,
                    child: buildRow(
                        "Geofencing $i",
                        // Call the helper function to display the raw coordinates
                        _getCoordinateDisplay('geofencing$i')),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.userDetail;
    final screenWidth = MediaQuery.of(context).size.width;

    return ScreenUtilInit(
      designSize: const Size(360, 690),
      builder: (context, child) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.green,
            title: const Text("User Details"),
            actions: [
              if (widget.isActive)
                IconButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => EditUserPage(
                          userDetail: user,
                          companyName: widget.companyName,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.edit),
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: screenWidth > 800 ? 800 : screenWidth),
                child: buildUserInfoCard(user),
              ),
            ),
          ),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            selectedItemColor: Colors.green,
            unselectedItemColor: Colors.grey,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Users'),
            ],
          ),
        );
      },
    );
  }
}