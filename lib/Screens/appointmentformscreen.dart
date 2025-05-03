import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AppointmentFormScreen extends StatefulWidget {
  final String doctorId;
  final String doctorName;
  final String doctorEmail;

  const AppointmentFormScreen({
    super.key,
    required this.doctorId,
    required this.doctorName,
    required this.doctorEmail,
  });

  @override
  State<AppointmentFormScreen> createState() => _AppointmentFormScreenState();
}

class _AppointmentFormScreenState extends State<AppointmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _purposeController = TextEditingController();
  final _dateController = TextEditingController();
  final _timeController = TextEditingController();
  bool isLoading = false;

  // EmailJS setup
  static const String _emailJSServiceId = 'service_dhwmwdl';
  static const String _emailJSTemplateIdUser = 'template_f03vjjn'; // User confirmation template
  static const String _emailJSTemplateIdDoctor = 'template_eh3zddf'; // Doctor notification template
  static const String _emailJSUserId = 'ZfKV3oiAuyxuyPLH8';
  static const String _emailJSAPIUrl = 'https://api.emailjs.com/api/v1.0/email/send';

  Future<void> _sendEmail({
    required String recipientEmail,
    required String fromEmail,
    required String doctorName,
    required String date,
    required String time,
    required String purpose,
    required String templateId,
    String? patientName,
    String? patientEmail,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_emailJSAPIUrl),
        headers: {
          'Content-Type': 'application/json',
          'origin': 'http://localhost',
          'User-Agent': 'flutter',
        },
        body: jsonEncode({
          'service_id': _emailJSServiceId,
          'template_id': templateId,
          'user_id': _emailJSUserId,
          'template_params': {
            'to_email': recipientEmail,
            'from_email': fromEmail,
            'doctor_name': doctorName,
            'appointment_date': date,
            'appointment_time': time,
            'purpose': purpose,
            if (patientName != null) 'patient_name': patientName,
            if (patientEmail != null) 'patient_email': patientEmail,
          },
        }),
      );

      if (response.statusCode != 200) {
        debugPrint('EmailJS error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to send email: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Failed to send email: $e');
      rethrow;
    }
  }

  Future<void> bookAppointment() async {
    if (!_formKey.currentState!.validate()) return;

    final purpose = _purposeController.text.trim();
    final date = _dateController.text.trim();
    final time = _timeController.text.trim();
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User not logged in')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final appointmentRef = FirebaseFirestore.instance.collection('appointments');

      // Check if doctor is already booked at the same time
      final existing = await appointmentRef
          .where('doctorId', isEqualTo: widget.doctorId)
          .where('date', isEqualTo: date)
          .where('time', isEqualTo: time)
          .get();

      if (existing.docs.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Doctor already has an appointment at this time.')),
        );
        setState(() => isLoading = false);
        return;
      }

      // Fetch user data
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final userData = userDoc.data() ?? {};
      final userEmail = userData['email'] ?? user.email ?? 'no-email@example.com';
      final userPhone = userData['phone'] ?? 'Not provided';
      final userName = userData['fullName'] ?? 'Patient';

      // Save appointment in Firestore
      await appointmentRef.add({
        'userId': user.uid,
        'doctorId': widget.doctorId,
        'doctorName': widget.doctorName,
        'doctorEmail': widget.doctorEmail,
        'purpose': purpose,
        'date': date,
        'time': time,
        'location': 'Clinic/Office',
        'userPhone': userPhone,
        'userEmail': userEmail,
        'userName': userName,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'scheduled',
      });

      // Send confirmation to user (from doctor's email)
      await _sendEmail(
        recipientEmail: userEmail,
        fromEmail: widget.doctorEmail,
        doctorName: widget.doctorName,
        date: date,
        time: time,
        purpose: purpose,
        templateId: _emailJSTemplateIdUser,
      );

      // Send notification to doctor (from user's email)
      await _sendEmail(
        recipientEmail: widget.doctorEmail,
        fromEmail: userEmail,
        doctorName: widget.doctorName,
        date: date,
        time: time,
        purpose: purpose,
        templateId: _emailJSTemplateIdDoctor,
        patientName: userName,
        patientEmail: userEmail,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Appointment booked! Check your email for confirmation.')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    _purposeController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Book Appointment", style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _purposeController,
                decoration: const InputDecoration(labelText: "Purpose", border: OutlineInputBorder()),
                validator: (value) => value == null || value.isEmpty ? 'Enter purpose' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dateController,
                decoration: const InputDecoration(labelText: "Date (YYYY-MM-DD)", border: OutlineInputBorder()),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d-]'))],
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Enter date';
                  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
                    return 'Format must be YYYY-MM-DD';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _timeController,
                decoration: const InputDecoration(labelText: "Time (e.g. 10:00 AM)", border: OutlineInputBorder()),
                validator: (value) => value == null || value.isEmpty ? 'Enter time' : null,
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  onPressed: isLoading ? null : bookAppointment,
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      : const Text("Confirm Appointment", style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
}
}