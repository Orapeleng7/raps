import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'appointmentformscreen.dart';

class DoctorProfileScreen extends StatefulWidget {
  final Map<String, dynamic> doctor;

  const DoctorProfileScreen({super.key, required this.doctor});

  @override
  State<DoctorProfileScreen> createState() => _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends State<DoctorProfileScreen> {
  double _userRating = 0.0;
  double? _distanceToDoctor;
  bool _isCalculatingDistance = false;
  String _doctorAddress = 'Loading address...';
  bool _isSuspended = false;

  @override
  void initState() {
    super.initState();
    _isSuspended = widget.doctor['status'] == 'suspended';
    _getDoctorAddress();
  }

  Future<void> _getDoctorAddress() async {
    final location = widget.doctor['location'] as Map<String, dynamic>?;
    final docLat = location?['lat']?.toDouble();
    final docLng = location?['lng']?.toDouble();

    if (docLat == null || docLng == null) {
      setState(() {
        _doctorAddress = 'Location not available';
      });
      return;
    }

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(docLat, docLng);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final address = [
          if (place.street != null && place.street!.isNotEmpty) place.street,
          if (place.locality != null && place.locality!.isNotEmpty) place.locality,
          if (place.subAdministrativeArea != null && place.subAdministrativeArea!.isNotEmpty) place.subAdministrativeArea,
          if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) place.administrativeArea,
        ].where((part) => part != null).join(', ');

        setState(() {
          _doctorAddress = address.isNotEmpty ? address : 'Location available (no address)';
        });
      }
    } catch (e) {
      debugPrint("Error getting address: $e");
      setState(() {
        _doctorAddress = 'Location available (address unknown)';
      });
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.blueGrey.shade800,
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white70, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              const SizedBox(height: 4),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }

  void _showRatingDialog() {
    double tempRating = _userRating;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Rate Doctor"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Select your rating:"),
              const SizedBox(height: 10),
              StatefulBuilder(
                builder: (context, setStateDialog) => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    5,
                    (index) => IconButton(
                      icon: Icon(
                        index < tempRating ? Icons.star : Icons.star_border,
                        color: Colors.amber,
                        size: 30,
                      ),
                      onPressed: () {
                        setStateDialog(() {
                          tempRating = index + 1.0;
                        });
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            TextButton(
              onPressed: () async {
                setState(() {
                  _userRating = tempRating;
                });

                final docRef = FirebaseFirestore.instance
                    .collection('doctors')
                    .doc(widget.doctor['id']);

                await FirebaseFirestore.instance.runTransaction((transaction) async {
                  final snapshot = await transaction.get(docRef);
                  if (!snapshot.exists) return;

                  final data = snapshot.data()!;
                  final currentSum = (data['ratingSum'] ?? 0).toDouble();
                  final currentCount = (data['ratingCount'] ?? 0).toInt();

                  transaction.update(docRef, {
                    'ratingSum': currentSum + tempRating,
                    'ratingCount': currentCount + 1,
                  });
                });

                Navigator.pop(context);
                _showMessage("Rating submitted successfully!");
              },
              child: const Text("Submit"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _launchDirections() async {
    final location = widget.doctor['location'] as Map<String, dynamic>?;
    final docLat = location?['lat']?.toDouble();
    final docLng = location?['lng']?.toDouble();

    if (docLat == null || docLng == null) {
      _showMessage("Doctor location not available");
      return;
    }

    setState(() {
      _isCalculatingDistance = true;
    });

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showMessage("Please enable location services");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showMessage("Location permissions are denied");
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showMessage("Location permissions are permanently denied");
        return;
      }

      final userPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);

      final distanceInMeters = Geolocator.distanceBetween(
        userPosition.latitude,
        userPosition.longitude,
        docLat,
        docLng,
      );

      setState(() {
        _distanceToDoctor = distanceInMeters / 1000; // km
      });

      final url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&origin=${userPosition.latitude},${userPosition.longitude}'
        '&destination=$docLat,$docLng'
        '&travelmode=driving',
      );

      if (await canLaunchUrl(url)) {
        await launchUrl(url);
      } else {
        _showMessage("Could not launch maps application");
      }
    } catch (e) {
      debugPrint("Error getting location: $e");
      final fallbackUrl = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$docLat,$docLng',
      );
      if (await canLaunchUrl(fallbackUrl)) {
        await launchUrl(fallbackUrl);
      } else {
        _showMessage("Could not launch maps application");
      }
    } finally {
      setState(() {
        _isCalculatingDistance = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ratingSum = widget.doctor['ratingSum']?.toDouble() ?? 0.0;
    final ratingCount = widget.doctor['ratingCount']?.toInt() ?? 0;
    final initialRating = ratingCount > 0 ? ratingSum / ratingCount : 0.0;
    final displayRating = _userRating > 0 ? _userRating : initialRating;

    final imageBase64 = widget.doctor['image'] as String?;
    String? pureBase64;
    if (imageBase64 != null && imageBase64.contains(',')) {
      pureBase64 = imageBase64.split(',').last;
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.blueGrey.shade900, Colors.black87],
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            if (_isSuspended)
              Container(
                margin: const EdgeInsets.all(10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade800,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text("This doctor is currently suspended", style: TextStyle(color: Colors.white)),
              ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 60,
                      backgroundColor: Colors.grey.shade800,
                      backgroundImage: pureBase64 != null ? MemoryImage(base64Decode(pureBase64)) : null,
                      child: pureBase64 == null ? const Icon(Icons.person, size: 60, color: Colors.white70) : null,
                    ),
                    const SizedBox(height: 20),
                    Text(widget.doctor['name'] ?? 'Dr. Unknown', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(widget.doctor['specialty'] ?? 'Specialist', style: const TextStyle(color: Colors.white70, fontSize: 16)),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star, color: Colors.amber, size: 20),
                        const SizedBox(width: 4),
                        Text(displayRating.toStringAsFixed(1), style: const TextStyle(color: Colors.white)),
                        Text(' ($ratingCount)', style: const TextStyle(color: Colors.white54)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Card(
                      color: Colors.white10,
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _infoTile(Icons.email, "Email", widget.doctor['email'] ?? 'No email provided'),
                            const Divider(color: Colors.white24, height: 20),
                            _infoTile(Icons.phone, "Phone", widget.doctor['phone'] ?? 'No phone provided'),
                            const Divider(color: Colors.white24, height: 20),
                            _infoTile(Icons.location_on, "Location", _doctorAddress),
                            if (_distanceToDoctor != null)
                              Column(
                                children: [
                                  const Divider(color: Colors.white24, height: 20),
                                  _infoTile(Icons.directions, "Distance", "${_distanceToDoctor!.toStringAsFixed(2)} km away"),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSuspended
                          ? null
                          : () {
                              if (FirebaseAuth.instance.currentUser != null &&
                                  !FirebaseAuth.instance.currentUser!.isAnonymous) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => AppointmentFormScreen(
                                      doctorId: widget.doctor['id'],
                                      doctorName: widget.doctor['name'],
                                      doctorEmail: widget.doctor['email'],
                                    ),
                                  ),
                                );
                              } else {
                                _showMessage("Login required to book appointment.");
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isSuspended ? Colors.grey : Colors.tealAccent.shade400,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        _isSuspended ? "APPOINTMENTS SUSPENDED" : "BOOK APPOINTMENT",
                        style: TextStyle(
                          color: _isSuspended ? Colors.white : Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (FirebaseAuth.instance.currentUser != null &&
                                  !FirebaseAuth.instance.currentUser!.isAnonymous) {
                                _showRatingDialog();
                              } else {
                                _showMessage("Login required to rate doctor.");
                              }
                            },
                            icon: const Icon(Icons.star, size: 20),
                            label: const Text("RATE"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _launchDirections,
                            icon: _isCalculatingDistance
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.directions, size: 20),
                            label: const Text("DIRECTIONS"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
