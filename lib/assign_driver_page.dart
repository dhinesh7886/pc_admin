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

          // Fetch drivers list
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('drivers').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Error loading drivers'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final drivers = snapshot.data!.docs;

                if (drivers.isEmpty) {
                  return const Center(child: Text('No drivers found'));
                }

                return ListView.builder(
                  itemCount: drivers.length,
                  itemBuilder: (context, index) {
                    final driver = drivers[index];
                    final data = driver.data() as Map<String, dynamic>;
                    final driverId = driver.id;

                    return RadioListTile<String>(
                      title: Text(data['name'] ?? 'Unknown Driver'),
                      subtitle: Text(data['phone'] ?? ''),
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

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: selectedDriverId == null ? null : _assignDriver,
              icon: const Icon(Icons.check_circle_outline),
              label: const Text("Assign Driver"),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _assignDriver() async {
    if (selectedDriverId == null) return;

    final driverRef = FirebaseFirestore.instance.collection('drivers').doc(selectedDriverId);
    final bookingRef = FirebaseFirestore.instance.collection('bookings');

    final driverDoc = await driverRef.get();
    final driverData = driverDoc.data();

    if (driverData == null) return;

    for (String bookingId in widget.bookingIds) {
      await bookingRef.doc(bookingId).update({
        'assignedDriver': driverData['name'] ?? '',
        'driverId': selectedDriverId,
        'status': 'Assigned',
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver assigned successfully')),
      );
      Navigator.pop(context);
    }
  }
}
