import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _genderController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  String? _profileImageUrl;
  File? _selectedImage;
  bool _isLoading = true;
  bool _isSaving = false;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _appointments = [];

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadAppointments();
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snapshot = await _firestore.collection('users').doc(user.uid).get();
      if (snapshot.exists) {
        final data = snapshot.data()!;
        _nameController.text = data['fullName'] ?? '';
        _emailController.text = data['email'] ?? user.email ?? '';
        _phoneController.text = data['phone'] ?? '';
        _genderController.text = data['gender'] ?? '';
        _profileImageUrl = data['profileImageUrl'];
      }
    } catch (e) {
      _showSnackBar('Error loading profile: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadAppointments() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      final snapshot = await _firestore
          .collection('appointments')
          .where('userId', isEqualTo: user.uid)
          .get();

      setState(() {
        _appointments = snapshot.docs;
      });
    } catch (e) {
      _showSnackBar('Error loading appointments: $e');
    }
  }

  Future<void> _pickImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
      });
      await _uploadProfileImage();
    }
  }

  Future<void> _uploadProfileImage() async {
    final user = _auth.currentUser;
    if (user == null || _selectedImage == null) return;

    try {
      final ref = _storage.ref().child('profile_pics/${user.uid}.jpg');
      await ref.putFile(_selectedImage!);
      final url = await ref.getDownloadURL();

      await _firestore.collection('users').doc(user.uid).update({'profileImageUrl': url});

      setState(() {
        _profileImageUrl = url;
      });

      _showSnackBar('Profile image updated!');
    } catch (e) {
      _showSnackBar('Failed to upload image: $e');
    }
  }

  Future<void> _saveUserProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'fullName': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'gender': _genderController.text.trim(),
      });

      _showSnackBar('Profile updated!');
    } catch (e) {
      _showSnackBar('Error saving profile: $e');
    }

    setState(() => _isSaving = false);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey[300],
                  backgroundImage: _selectedImage != null
                      ? FileImage(_selectedImage!)
                      : (_profileImageUrl != null
                          ? NetworkImage(_profileImageUrl!) as ImageProvider
                          : const AssetImage('assets/default_avatar.png')),
                  child: _profileImageUrl == null && _selectedImage == null
                      ? const Icon(Icons.camera_alt, size: 40, color: Colors.white70)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildTextField(_nameController, 'Full Name'),
                  _buildTextField(_emailController, 'Email', keyboardType: TextInputType.emailAddress),
                  _buildTextField(_phoneController, 'Phone Number', keyboardType: TextInputType.phone),
                  _buildTextField(_genderController, 'Gender'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _saveUserProfile,
                    child: _isSaving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Save Profile'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text('Appointments', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _appointments.isEmpty
                ? const Text('No appointments found.')
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _appointments.length,
                    itemBuilder: (context, index) {
                      final appointment = _appointments[index].data();
                      return ListTile(
                        title: Text(appointment['doctorName'] ?? 'Unknown Doctor'),
                        subtitle: Text(appointment['dateTime'] ?? 'No Date'),
                      );
                    },
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label,
      {TextInputType keyboardType = TextInputType.text}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        validator: (value) => (value == null || value.isEmpty) ? 'Please enter $label' : null,
      ),
    );
  }
}
