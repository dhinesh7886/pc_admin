import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'assign_driver_page.dart';

class BookingListPage extends StatefulWidget {
  final String companyName;
  final String filterStatus; // <-- added filter field

  const BookingListPage({
    super.key,
    required this.companyName,
    required this.filterStatus,
  });

  @override
  State<BookingListPage> createState() => _BookingListPageState();
}

class _BookingListPageState extends State<BookingListPage> {
  final CollectionReference bookings =
      FirebaseFirestore.instance.collection('bookings');

  final Set<String> _selectedBookings = {};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.filterStatus} Bookings'),
        backgroundColor: Colors.pinkAccent,
        centerTitle: true,
        actions: [
          if (_selectedBookings.isNotEmpty &&
              widget.filterStatus == "Pending") // Assign only pending
            TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => AssignDriverPage(
                      bookingIds: _selectedBookings.toList(),
                      companyName: widget.companyName,
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.directions_car, color: Colors.white),
              label: const Text(
                'Assign Driver',
                style: TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _getFilteredStream(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading bookings'));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final bookingDocs = snapshot.data!.docs;

          if (bookingDocs.isEmpty) {
            return Center(
              child: Text('No ${widget.filterStatus} bookings found'),
            );
          }

          return ListView.builder(
            itemCount: bookingDocs.length,
            itemBuilder: (context, index) {
              final doc = bookingDocs[index];
              final data = doc.data() as Map<String, dynamic>;
              final bookingId = doc.id;
              final isSelected = _selectedBookings.contains(bookingId);

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: CheckboxListTile(
                  value: isSelected,
                  onChanged: (selected) {
                    if (widget.filterStatus == "Pending") {
                      setState(() {
                        if (selected == true) {
                          _selectedBookings.add(bookingId);
                        } else {
                          _selectedBookings.remove(bookingId);
                        }
                      });
                    }
                  },
                  title: Text(
                    data['companyName'] ?? 'Unknown Company',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Name: ${data['name'] ?? '-'}'),
                      Text('Department: ${data['department'] ?? '-'}'),
                      Text('Designation: ${data['designation'] ?? '-'}'),
                      Text('Pickup: ${data['pickupPlace'] ?? '-'}'),
                      Text('Drop: ${data['dropPlace'] ?? '-'}'),
                      Text('Amount: ₹${data['amount'] ?? 0}'),
                      Text('Start Date: ${data['startDate'] ?? '-'}'),
                      const SizedBox(height: 4),
                      Text(
                        'Status: ${data['status'] ?? 'Pending'}',
                        style: const TextStyle(
                            fontSize: 13, color: Colors.blueGrey),
                      ),
                      Text(
                        'Created At: ${data['createdAt'] ?? '-'}',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Stream<QuerySnapshot> _getFilteredStream() {
    final baseQuery = bookings
        .where('companyName', isEqualTo: widget.companyName)
        .orderBy('createdAt', descending: true);

    if (widget.filterStatus == "Pending") {
      return baseQuery.where('status', isEqualTo: 'Pending').snapshots();
    } else if (widget.filterStatus == "Assigned") {
      return baseQuery.where('status', isEqualTo: 'Assigned').snapshots();
    } else if (widget.filterStatus == "Today") {
      final today = DateTime.now().toString().split(' ')[0];
      return baseQuery.where('startDate', isEqualTo: today).snapshots();
    } else if (widget.filterStatus == "Upcoming") {
      final today = DateTime.now().toString().split(' ')[0];
      return baseQuery.where('startDate', isGreaterThan: today).snapshots();
    } else {
      return baseQuery.snapshots();
    }
  }
}
