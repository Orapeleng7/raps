import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'loginscreen.dart';
import 'doctorlistscreen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final String name = 'Orapeleng Kudzani';
  final String studentId = '22000200';
  final String phone = '+267 76201530';
  final String gender = 'Male';

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {});
      }
    });
  }

  Future<void> signInAsGuest() async {
    try {
      await FirebaseAuth.instance.signInAnonymously();
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DoctorListScreen()),
      );
    } catch (e) {
      debugPrint("Guest sign-in failed: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color backgroundColor = Colors.white;
    const Color textColor = Colors.black;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: PopupMenuButton<String>(
              tooltip: 'Profile Info',
              offset: const Offset(0, 50),
              color: Colors.white,
              icon: Row(
                children: [
                  Text(
                    "$name | $studentId",
                    style: const TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_drop_down, color: textColor),
                ],
              ),
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'phone',
                  child: Text('Phone: $phone'),
                ),
                PopupMenuItem<String>(
                  value: 'gender',
                  child: Text('Gender: $gender'),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "HealthMate",
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              const Icon(
                Icons.health_and_safety,
                size: 80,
                color: textColor,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: textColor,
                  foregroundColor: backgroundColor,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: signInAsGuest,
                child: const Text("Continue as Guest"),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: backgroundColor,
                  foregroundColor: textColor,
                  side: const BorderSide(color: textColor),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: const Text("Login"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
