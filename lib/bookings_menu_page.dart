import 'package:flutter/material.dart';
import 'package:pcadmin/booking_list_page.dart';

class BookingsMenuPage extends StatelessWidget {
  final String companyName;

  const BookingsMenuPage({super.key, required this.companyName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Bookings"),
        backgroundColor: Colors.pinkAccent,
        centerTitle: true,
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(20),
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        children: [
          _buildMenuCard(
            context,
            "Pending Bookings",
            Icons.pending_actions,
            Colors.orangeAccent,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BookingListPage(
                  companyName: companyName,
                  filterStatus: "Pending",
                ),
              ),
            ),
          ),
          _buildMenuCard(
            context,
            "Assigned Bookings",
            Icons.directions_car,
            Colors.green,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BookingListPage(
                  companyName: companyName,
                  filterStatus: "Assigned",
                ),
              ),
            ),
          ),
          _buildMenuCard(
            context,
            "Today Trips",
            Icons.today,
            Colors.lightBlue,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BookingListPage(
                  companyName: companyName,
                  filterStatus: "Today",
                ),
              ),
            ),
          ),
          _buildMenuCard(
            context,
            "Upcoming Trips",
            Icons.upcoming,
            Colors.purple,
            () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => BookingListPage(
                  companyName: companyName,
                  filterStatus: "Upcoming",
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, String label, IconData icon,
      Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black26,
              blurRadius: 8,
              offset: const Offset(2, 4),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 50, color: Colors.white),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
