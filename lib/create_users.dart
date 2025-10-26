import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class CreateUsersPage extends StatefulWidget {
  final String companyName;
  const CreateUsersPage({super.key, required this.companyName});

  @override
  State<CreateUsersPage> createState() => _CreateUsersPageState();
}

class _CreateUsersPageState extends State<CreateUsersPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _dojController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _contactController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();

  // Geofence Text Controllers
  final TextEditingController _geo1LatController = TextEditingController();
  final TextEditingController _geo1LngController = TextEditingController();
  final TextEditingController _geo2LatController = TextEditingController();
  final TextEditingController _geo2LngController = TextEditingController();
  final TextEditingController _geo3LatController = TextEditingController();
  final TextEditingController _geo3LngController = TextEditingController();
  final TextEditingController _geo4LatController = TextEditingController();
  final TextEditingController _geo4LngController = TextEditingController();

  File? _selectedImage;
  String? _selectedGender;
  String? _selectedSubDivision;
  String? _selectedDepartment;
  String? _selectedDesignation;

  DateTime? _dobDate;
  DateTime? _dojDate;

  final List<String> _genders = ['Male', 'Female'];
  final List<String> _subDivisions = ['Corporate', 'Isuzu'];
  final List<String> _departments = [
    'Accounts',
    'Administration',
    'Finance',
    'HR',
    'Operation'
  ];
  final List<String> _designations = [
    'Assistant Manager',
    'COO',
    'Driver',
    'Executive',
    'General Manager',
    'Manager',
    'Supervisor'
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _idController.dispose();
    _dojController.dispose();
    _emailController.dispose();
    _contactController.dispose();
    _addressController.dispose();

    _geo1LatController.dispose();
    _geo1LngController.dispose();
    _geo2LatController.dispose();
    _geo2LngController.dispose();
    _geo3LatController.dispose();
    _geo3LngController.dispose();
    _geo4LatController.dispose();
    _geo4LngController.dispose();
    super.dispose();
  }

  String _formatContactNumber(String number) {
    String cleaned = number.trim();
    if (cleaned.startsWith("+91")) {
      return cleaned;
    } else if (cleaned.startsWith("0")) {
      return "+91${cleaned.substring(1)}";
    } else {
      return "+91$cleaned";
    }
  }

  Future<String> uploadToFirebaseStorage(String empId) async {
    try {
      var reference = FirebaseStorage.instance
          .ref()
          .child("profile_pic/${_nameController.text}_$empId.png");
      var result = await reference.putFile(_selectedImage!);
      return await result.ref.getDownloadURL();
    } catch (e) {
      debugPrint("Error $e");
      return "e";
    }
  }

  Future<void> _selectDate(
      BuildContext context, TextEditingController controller,
      {required String field}) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      controller.text = DateFormat("dd-MM-yyyy").format(picked);
      if (field == 'dob') {
        _dobDate = picked;
      } else if (field == 'doj') {
        _dojDate = picked;
      }
    }
  }

  String _formatDateForFirestore(DateTime? date) {
    if (date == null) return '';
    return DateFormat("dd/MM/yyyy").format(date);
  }

  void _saveForm() async {
    final empId = _idController.text.trim();

    if (_formKey.currentState!.validate()) {
      var existing =
          await FirebaseFirestore.instance.collection('Users').doc(empId).get();
      if (existing.exists) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Employee ID already exists.')),
        );
        return;
      }

      if (_selectedImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please upload a photo')),
        );
        return;
      }

      try {
        String imageUrl = await uploadToFirebaseStorage(empId);
        if (imageUrl == "e") {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image upload failed')),
          );
          return;
        }

        String formattedContact = _formatContactNumber(_contactController.text);
        if (formattedContact.length != 13) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contact number must have 10 digits')),
          );
          return;
        }

        Map<String, dynamic> userInfo = {
          'name': _nameController.text,
          'dob': _formatDateForFirestore(_dobDate),
          'companyName': widget.companyName,
          'subDivision': _selectedSubDivision,
          'department': _selectedDepartment,
          'id': empId,
          'dateOfJoining': _formatDateForFirestore(_dojDate),
          'email': _emailController.text,
          'designation': _selectedDesignation,
          'contact': formattedContact,
          'address': _addressController.text,
          'gender': _selectedGender,
          'imageUrl': imageUrl,
          'isActive': true,
          'geofencing1': _geo1LatController.text.isNotEmpty &&
                  _geo1LngController.text.isNotEmpty
              ? {
                  'lat': double.tryParse(_geo1LatController.text),
                  'lng': double.tryParse(_geo1LngController.text)
                }
              : null,
          'geofencing2': _geo2LatController.text.isNotEmpty &&
                  _geo2LngController.text.isNotEmpty
              ? {
                  'lat': double.tryParse(_geo2LatController.text),
                  'lng': double.tryParse(_geo2LngController.text)
                }
              : null,
          'geofencing3': _geo3LatController.text.isNotEmpty &&
                  _geo3LngController.text.isNotEmpty
              ? {
                  'lat': double.tryParse(_geo3LatController.text),
                  'lng': double.tryParse(_geo3LngController.text)
                }
              : null,
          'geofencing4': _geo4LatController.text.isNotEmpty &&
                  _geo4LngController.text.isNotEmpty
              ? {
                  'lat': double.tryParse(_geo4LatController.text),
                  'lng': double.tryParse(_geo4LngController.text)
                }
              : null,
        };

        await FirebaseFirestore.instance
            .collection('Users')
            .doc(empId)
            .set(userInfo);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User details saved successfully')),
        );

        // Clear all fields after save
        setState(() {
          _selectedImage = null;

          _nameController.clear();
          _dobController.clear();
          _idController.clear();
          _dojController.clear();
          _emailController.clear();
          _contactController.clear();
          _addressController.clear();

          _geo1LatController.clear();
          _geo1LngController.clear();
          _geo2LatController.clear();
          _geo2LngController.clear();
          _geo3LatController.clear();
          _geo3LngController.clear();
          _geo4LatController.clear();
          _geo4LngController.clear();

          _selectedGender = null;
          _selectedSubDivision = null;
          _selectedDepartment = null;
          _selectedDesignation = null;

          _dobDate = null;
          _dojDate = null;
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      bool isTablet = constraints.maxWidth > 600;
      double padding = isTablet ? 24 : 14;

      return Scaffold(
        appBar: AppBar(
          title: const Text('Create Users'),
          backgroundColor: Colors.pinkAccent,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(padding),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isTablet ? 600 : 400),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildTextField('Employee Name', _nameController),
                      _dateField('Date of Birth', _dobController, 'dob'),
                      _buildDropdown('Sub Division', _selectedSubDivision,
                          _subDivisions, (v) => setState(() => _selectedSubDivision = v)),
                      _buildTextField('Employee ID', _idController),
                      _dateField('Date of Joining', _dojController, 'doj'),
                      _buildDropdown('Department', _selectedDepartment, _departments,
                          (v) => setState(() => _selectedDepartment = v)),
                      _buildDropdown('Designation', _selectedDesignation, _designations,
                          (v) => setState(() => _selectedDesignation = v)),
                      _buildTextField('Email ID', _emailController,
                          inputType: TextInputType.emailAddress),
                      _buildTextField('Contact Number', _contactController,
                          inputType: TextInputType.phone),
                      _buildDropdown('Gender', _selectedGender, _genders,
                          (v) => setState(() => _selectedGender = v)),
                      _buildTextField('Address', _addressController, maxLines: 2),

                      const SizedBox(height: 10),
                      const Divider(thickness: 1, color: Colors.grey),
                      const Text("Geofencing (Manual Latitude & Longitude)",
                          style: TextStyle(fontWeight: FontWeight.bold)),

                      _geoField('Geofencing 1', _geo1LatController, _geo1LngController),
                      _geoField('Geofencing 2', _geo2LatController, _geo2LngController),
                      _geoField('Geofencing 3', _geo3LatController, _geo3LngController),
                      _geoField('Geofencing 4', _geo4LatController, _geo4LngController),

                      const SizedBox(height: 16),
                      _buildImagePicker(),
                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton(
                            onPressed: _saveForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              minimumSize: Size(isTablet ? 160 : 120, 50),
                            ),
                            child: const Text('Save',
                                style: TextStyle(color: Colors.white)),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              minimumSize: Size(isTablet ? 160 : 120, 50),
                            ),
                            child: const Text('Cancel',
                                style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _geoField(String label, TextEditingController latCtrl, TextEditingController lngCtrl) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: latCtrl,
                  decoration: const InputDecoration(labelText: 'Latitude'),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: lngCtrl,
                  decoration: const InputDecoration(labelText: 'Longitude'),
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dateField(String label, TextEditingController controller, String field) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        onTap: () => _selectDate(context, controller, field: field),
        validator: (v) => v == null || v.isEmpty ? 'Select $label' : null,
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {TextInputType inputType = TextInputType.text, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: inputType,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        validator: (v) => v == null || v.isEmpty ? 'Enter $label' : null,
      ),
    );
  }

  Widget _buildDropdown(String label, String? value, List<String> items,
      Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DropdownButtonFormField<String>(
        value: value,
        items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        validator: (v) => v == null ? 'Select $label' : null,
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: () => _showImageSourceActionSheet(context),
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          border: Border.all(color: Colors.grey),
          borderRadius: BorderRadius.circular(16),
        ),
        child: _selectedImage == null
            ? const Icon(Icons.camera_alt, color: Colors.pinkAccent, size: 40)
            : ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(_selectedImage!, fit: BoxFit.cover)),
      ),
    );
  }

  void _showImageSourceActionSheet(BuildContext context) {
    showModalBottomSheet(
        context: context,
        builder: (context) {
          return Wrap(children: [
            ListTile(
                leading: const Icon(Icons.camera_alt, color: Colors.pinkAccent),
                title: const Text('Camera'),
                onTap: () async {
                  Navigator.pop(context);
                  final picked =
                      await ImagePicker().pickImage(source: ImageSource.camera);
                  if (picked != null) {
                    setState(() => _selectedImage = File(picked.path));
                  }
                }),
            ListTile(
                leading: const Icon(Icons.photo, color: Colors.pinkAccent),
                title: const Text('Gallery'),
                onTap: () async {
                  Navigator.pop(context);
                  final picked =
                      await ImagePicker().pickImage(source: ImageSource.gallery);
                  if (picked != null) {
                    setState(() => _selectedImage = File(picked.path));
                  }
                })
          ]);
        });
  }
}
