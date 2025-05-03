import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'registerscreen.dart';
import 'doctorlistscreen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final inputController = TextEditingController(); // Email or phone
  final passwordController = TextEditingController();
  String error = '';
  bool isLoading = false;

  bool isPhoneNumber(String input) {
    final phoneRegex = RegExp(r'^\+?\d{8,15}$');
    return phoneRegex.hasMatch(input);
  }

  Future<void> login() async {
    final input = inputController.text.trim();
    final password = passwordController.text.trim();

    setState(() {
      error = '';
      isLoading = true;
    });

    try {
      if (isPhoneNumber(input)) {
        final fakeEmail = '$input@email.fake';
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: fakeEmail,
          password: password,
        );
      } else {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: input,
          password: password,
        );
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DoctorListScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = 'Login failed. Check credentials or format.';
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<void> continueAsGuest() async {
    setState(() => isLoading = true);

    try {
      await FirebaseAuth.instance.signInAnonymously(); // <-- Anonymous Sign-in
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DoctorListScreen()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = 'Failed to continue as guest.';
      });
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> navigateToRegister() async {
    setState(() => isLoading = true);
    await Future.delayed(const Duration(milliseconds: 500)); // Simulated loading
    if (!mounted) return;
    setState(() => isLoading = false);
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  Future<void> resetPasswordDialog() async {
    final emailController = TextEditingController();

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Reset Password"),
        content: TextField(
          controller: emailController,
          decoration: const InputDecoration(labelText: "Enter your email"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () async {
              final email = emailController.text.trim();
              if (email.isNotEmpty) {
                try {
                  await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                  if (!mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Reset email sent.")),
                  );
                } catch (e) {
                  if (!mounted) return;
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Failed to send reset email.")),
                  );
                }
              }
            },
            child: const Text("Send"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login")),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.person, size: 80),
                const SizedBox(height: 24),
                TextField(
                  controller: inputController,
                  decoration: const InputDecoration(
                    labelText: "Email or Phone (+267...)",
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: "Password"),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: resetPasswordDialog,
                    child: const Text("Forgot Password?"),
                  ),
                ),
                const SizedBox(height: 8),
                if (error.isNotEmpty)
                  Text(error, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: isLoading ? null : login,
                  child: const Text("Login"),
                ),
                TextButton(
                  onPressed: isLoading ? null : navigateToRegister,
                  child: const Text("Create Account"),
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: isLoading ? null : continueAsGuest,
                  child: const Text("Continue as Guest"),
                ),
              ],
            ),
          ),
          if (isLoading)
            Container(
              color: Colors.black.withAlpha(77), // ~30% opacity
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
