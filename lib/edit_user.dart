import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pcadmin/admin_home.dart';
import 'package:url_launcher/url_launcher.dart';

class EditUserPage extends StatefulWidget {
  final Map<String, dynamic> userDetail;
  final String companyName;

  const EditUserPage({
    super.key,
    required this.userDetail,
    required this.companyName,
  });

  @override
  State<EditUserPage> createState() => _EditUserPageState();
}

class _EditUserPageState extends State<EditUserPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _designationController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();

  File? _selectedImage;
  String imageUrl = "";
  String uid = "";
  String _selectedGender = "Male";

  final List<String> _genders = ["Male", "Female", "Other"];
  bool _loadingUid = false;

  @override
  void initState() {
    super.initState();

    // Debug print of incoming map so you can see what's missing
    debugPrint('EditUserPage.userDetail: ${widget.userDetail}');

    // Safe defaults for all fields
    _nameController.text = (widget.userDetail['name'] ?? '').toString();
    _idController.text = (widget.userDetail['id'] ?? '').toString();
    _emailController.text = (widget.userDetail['email'] ?? '').toString();
    _addressController.text = (widget.userDetail['address'] ?? '').toString();
    _designationController.text =
        (widget.userDetail['designation'] ?? '').toString();
    _contactController.text = (widget.userDetail['contact'] ?? '').toString();
    _departmentController.text = (widget.userDetail['department'] ?? '').toString();
    imageUrl = (widget.userDetail['imageUrl'] ?? '').toString();

    // uid might be the document id or a stored uuid field; accept both cases
    uid = (widget.userDetail['uuid'] ?? widget.userDetail['uid'] ?? '').toString();

    // Gender fallback
    String? genderValue = widget.userDetail['gender']?.toString();
    if (genderValue == null || !_genders.contains(genderValue)) {
      _selectedGender = "Male";
    } else {
      _selectedGender = genderValue;
    }

    // If uid is empty, attempt to resolve it by querying the Users collection using id field.
    if (uid.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _resolveUidIfMissing();
      });
    }
  }

  /// If uid is not present, search Users for a document where 'id' == employeeId and use that doc id.
  Future<void> _resolveUidIfMissing() async {
    final empId = _idController.text.trim();
    if (empId.isEmpty) return;

    setState(() => _loadingUid = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Users')
          .where('id', isEqualTo: empId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        uid = snapshot.docs.first.id;
        debugPrint('Resolved uid from query: $uid');
      } else {
        debugPrint('No document found by id field for $empId. uid remains empty.');
      }
    } catch (e, st) {
      debugPrint('Error resolving uid: $e\n$st');
    } finally {
      if (mounted) setState(() => _loadingUid = false);
    }
  }

  Future<void> _openMap() async {
    const String googleMapsUrl = 'https://www.google.com/maps';
    final uri = Uri.parse(googleMapsUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Cannot open maps')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Map open error: $e')));
    }
  }

  Future<String> uploadToFirebaseStorage() async {
    if (_selectedImage == null) return imageUrl;
    try {
      // make filename safe
      final safeName = _nameController.text.replaceAll(RegExp(r'[^\w\s-]'), '');
      final fileName = '${safeName}_$uid.png';
      final ref = FirebaseStorage.instance.ref().child('profile_pic/$fileName');
      final uploadTask = await ref.putFile(_selectedImage!);
      final url = await uploadTask.ref.getDownloadURL();
      return url;
    } catch (e, st) {
      debugPrint('Image upload error: $e\n$st');
      return imageUrl; // fallback to previous url
    }
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Camera'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(source: ImageSource.camera);
                  if (picked != null) {
                    setState(() => _selectedImage = File(picked.path));
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Gallery'),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final picker = ImagePicker();
                  final picked = await picker.pickImage(source: ImageSource.gallery);
                  if (picked != null) {
                    setState(() => _selectedImage = File(picked.path));
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;

    // Show small loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // If uid is empty, try to resolve again before saving
      if (uid.isEmpty) {
        await _resolveUidIfMissing();
      }

      // upload image if selected
      String imgUrl = imageUrl;
      if (_selectedImage != null) {
        imgUrl = await uploadToFirebaseStorage();
      }

      final userInfo = <String, dynamic>{
        'name': _nameController.text.trim(),
        'id': _idController.text.trim(),
        'email': _emailController.text.trim(),
        'designation': _designationController.text.trim(),
        'department': _departmentController.text.trim(),
        'contact': _contactController.text.trim(),
        'address': _addressController.text.trim(),
        'imageUrl': imgUrl,
        'gender': _selectedGender,
        // keep uuid if available
      };

      final usersRef = FirebaseFirestore.instance.collection('Users');

      if (uid.isNotEmpty) {
        // update existing document
        await usersRef.doc(uid).update({
          ...userInfo,
          'uuid': uid, // keep uuid consistent
        });
        debugPrint('Updated Users/$uid');
      } else {
        // create a new document and remember its id
        final docRef = await usersRef.add({
          ...userInfo,
          'uuid': '', // will update below
        });
        uid = docRef.id;
        await docRef.update({'uuid': uid});
        debugPrint('Created new Users/${docRef.id}');
      }

      if (mounted) {
        Navigator.of(context).pop(); // close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User details saved successfully')),
        );
        Navigator.of(context).pop(); // go back
      }
    } catch (e, st) {
      debugPrint('Save error: $e\n$st');
      if (mounted) {
        Navigator.of(context).pop(); // close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save user: $e')),
        );
      }
    }
  }

  void _cancelForm() {
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _designationController.dispose();
    _departmentController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isResolving = _loadingUid;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit User Detail'),
        backgroundColor: Colors.grey,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'View Users'),
        ],
        onTap: (index) {
          if (index == 0) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => AdminHomePage(companyName: widget.companyName),
              ),
            );
          }
        },
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (isResolving) const LinearProgressIndicator(),
              _buildTextField('Employee Name', _nameController),
              _buildTextField('Employee ID', _idController),
              _buildTextField('Designation', _designationController),
              _buildTextField('Department', _departmentController),
              _buildTextField('Email ID', _emailController, inputType: TextInputType.emailAddress),
              _buildTextField('Contact Number', _contactController, inputType: TextInputType.phone),
              DropdownButtonFormField<String>(
                value: _selectedGender,
                items: _genders
                    .map((gender) => DropdownMenuItem(value: gender, child: Text(gender)))
                    .toList(),
                onChanged: (newValue) {
                  if (newValue != null) setState(() => _selectedGender = newValue);
                },
                decoration: const InputDecoration(labelText: 'Gender'),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(labelText: 'Address'),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Please enter address' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _openMap,
                    icon: const Icon(Icons.map),
                    label: const Text('Map'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => _showImageSourceActionSheet(context),
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.grey.shade200,
                  ),
                  child: _selectedImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.file(_selectedImage!, fit: BoxFit.cover),
                        )
                      : (imageUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(imageUrl, fit: BoxFit.cover),
                            )
                          : const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.camera_alt, size: 30),
                                  SizedBox(height: 5),
                                  Text("Upload Photo"),
                                ],
                              ),
                            )),
                ),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: _saveForm,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 10)),
                    child: const Text(
                      'Save',
                      style: TextStyle(fontSize: 20, color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _cancelForm,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 10)),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontSize: 20, color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {TextInputType inputType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        keyboardType: inputType,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        validator: (value) =>
            value == null || value.isEmpty ? 'Please enter $label' : null,
      ),
    );
  }
}
