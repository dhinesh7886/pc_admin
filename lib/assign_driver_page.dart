import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AssignDriverPage extends StatefulWidget {
  final List<String> bookingIds;
  final String companyName;

  const AssignDriverPage({
    super.key,
    required this.bookingIds,
    required this.companyName,
  });

  @override
  State<AssignDriverPage> createState() => _AssignDriverPageState();
}

class _AssignDriverPageState extends State<AssignDriverPage> {
  String? selectedDriverId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Assign Driver - ${widget.companyName}"),
        backgroundColor: Colors.pinkAccent,
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          const Text(
            "Select a driver to assign bookings:",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),

          // 🔥 Fetch drivers from 'Users' collection
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('Users')
                  .where('designation', isEqualTo: 'Driver')
                  // Uncomment below if each user has companyName field
                  // .where('companyName', isEqualTo: widget.companyName)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  debugPrint("Firestore error: ${snapshot.error}");
                  return const Center(child: Text('Error loading drivers'));
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final driverDocs = snapshot.data?.docs ?? [];
                debugPrint("Drivers fetched: ${driverDocs.length}");

                if (driverDocs.isEmpty) {
                  return const Center(child: Text('No drivers found'));
                }

                return ListView.builder(
                  itemCount: driverDocs.length,
                  itemBuilder: (context, index) {
                    final driver = driverDocs[index];
                    final data = driver.data() as Map<String, dynamic>? ?? {};
                    final driverId = driver.id;
                    final driverName = data['name'] ?? 'Unknown Driver';
                    final driverPhone = data['phone'] ?? '';

                    return RadioListTile<String>(
                      title: Text(driverName),
                      subtitle: Text(driverPhone),
                      value: driverId,
                      groupValue: selectedDriverId,
                      onChanged: (value) {
                        setState(() {
                          selectedDriverId = value;
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),

          // ✅ Assign Driver Button
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: selectedDriverId == null ? null : _assignDriver,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text(
                "Assign Driver",
                style: TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 🚗 Assign selected driver to all selected bookings
  Future<void> _assignDriver() async {
    if (selectedDriverId == null) return;

    final driverRef = FirebaseFirestore.instance
        .collection('Users')
        .doc(selectedDriverId);
    final bookingRef = FirebaseFirestore.instance.collection('bookings');

    final driverDoc = await driverRef.get();
    final driverData = driverDoc.data();

    if (driverData == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver data not found')),
      );
      return;
    }

    for (String bookingId in widget.bookingIds) {
      await bookingRef.doc(bookingId).update({
        'assignedDriver': driverData['name'] ?? '',
        'driverId': selectedDriverId,
        'driverPhone': driverData['phone'] ?? '',
        'status': 'Assigned',
        'assignedAt': DateTime.now().toIso8601String(),
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Driver assigned successfully')),
      );
      Navigator.pop(context);
    }
  }
}
