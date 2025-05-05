import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
          .orderBy('date')
          .get();
      if (mounted) setState(() => _appointments = snapshot.docs);
    } catch (e) {
      _showSnackBar('Error loading appointments: $e');
    }
  }

  Future<void> _deleteAppointment(String appointmentId) async {
    try {
      await _firestore.collection('appointments').doc(appointmentId).delete();
      _showSnackBar('Appointment deleted');
      _loadAppointments(); // Refresh list
    } catch (e) {
      _showSnackBar('Failed to delete appointment: $e');
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _firestore.collection('users').doc(user.uid).update({
        'fullName': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'gender': _genderController.text.trim(),
      });

      _showSnackBar('Profile updated');
    } catch (e) {
      _showSnackBar('Failed to save: $e');
    }

    if (mounted) setState(() => _isSaving = false);
  }

  void _changePassword() async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return;

    try {
      await _auth.sendPasswordResetEmail(email: user.email!);
      _showSnackBar('Password reset email sent to ${user.email}');
    } catch (e) {
      _showSnackBar('Failed to send reset email: $e');
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning ☀️";
    if (hour < 17) return "Good Afternoon 🌤️";
    return "Good Evening 🌙";
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _genderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("My Profile", style: TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Center(
              child: Column(
                children: [
                  const SizedBox(height: 10),
                  Text(_greeting(),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  _buildInput(_nameController, "Full Name", true),
                  _buildInput(_emailController, "Email", false, readOnly: true),
                  _buildInput(_phoneController, "Phone", true),
                  _buildInput(_genderController, "Gender", false),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
                    onPressed: _isSaving ? null : _saveProfile,
                    child: _isSaving
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white))
                        : const Text("Save Changes", style: TextStyle(color: Colors.white)),
                  ),
                  TextButton(
                    onPressed: _changePassword,
                    child: const Text("Change Password", style: TextStyle(color: Colors.blue)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            const Text("Appointments", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const Divider(color: Colors.black),
            ..._appointments.map((doc) {
              final a = doc.data();
              return Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(a['doctorName'] ?? 'Doctor',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 6),
                    Text('📅 ${a['date']} at ${a['time']}'),
                    Text('📍 ${a['location']}'),
                    Text('📩 ${a['doctorEmail']}'),
                    Text('📝 ${a['purpose']}'),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => _deleteAppointment(doc.id),
                        icon: const Icon(Icons.delete, color: Colors.red),
                        label: const Text("Delete", style: TextStyle(color: Colors.red)),
                      ),
                    ),
                  ],
                ),
              );
            }),
            if (_appointments.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: Text("No appointments yet.", style: TextStyle(color: Colors.black54)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController controller, String label, bool required, {bool readOnly = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        readOnly: readOnly,
        validator: required ? (val) => val == null || val.isEmpty ? 'Required' : null : null,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.black),
          filled: true,
          fillColor: Colors.grey[100],
          enabledBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.black),
            borderRadius: BorderRadius.circular(8),
          ),
          focusedBorder: OutlineInputBorder(
            borderSide: const BorderSide(color: Colors.black),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        style: const TextStyle(color: Colors.black),
      ),
    );
  }
}