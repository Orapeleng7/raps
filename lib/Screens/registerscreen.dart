import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'doctorlistscreen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final emailController = TextEditingController();
  final signUpInputController = TextEditingController();
  final otpController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  String gender = 'Male';
  bool showStepTwo = false;
  bool showOtpField = false;
  bool isSigningUpWithPhone = false;
  bool isLoading = false;
  String verificationId = '';

  bool isPhoneNumber(String input) {
    final phoneRegex = RegExp(r'^\+?\d{8,15}$');
    return phoneRegex.hasMatch(input);
  }

  void showSnack(String message, [Color color = Colors.black]) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  Future<void> saveUserData(String uid) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'fullName': nameController.text.trim(),
      'gender': gender,
      'phone': phoneController.text.trim(),
      'email': emailController.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> verifyPhoneNumber() async {
    final phone = signUpInputController.text.trim();
    setState(() => isLoading = true);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await FirebaseAuth.instance.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          showSnack('Phone verification failed: ${e.message}', Colors.red);
        },
        codeSent: (String verId, int? resendToken) {
          setState(() {
            verificationId = verId;
            showOtpField = true;
          });
          showSnack('OTP code sent to $phone');
        },
        codeAutoRetrievalTimeout: (String verId) {
          verificationId = verId;
        },
      );
    } catch (e) {
      showSnack('Failed to send OTP: $e', Colors.red);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> verifyOtpAndRegister() async {
    final smsCode = otpController.text.trim();
    setState(() => isLoading = true);

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      final userCred = await FirebaseAuth.instance.signInWithCredential(credential);

      if (emailController.text.trim().isNotEmpty) {
        try {
          await userCred.user?.verifyBeforeUpdateEmail(emailController.text.trim());
          showSnack('Verification email sent. Please verify your email.', Colors.blue);
        } catch (e) {
          showSnack('Failed to send verification email: $e', Colors.red);
        }
      }

      try {
        await userCred.user?.updatePassword(passwordController.text.trim());
      } catch (e) {
        showSnack('Failed to set password: $e', Colors.red);
      }

      await saveUserData(userCred.user!.uid);

      showSnack("Registration successful!", Colors.green);

      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DoctorListScreen()));
    } catch (e) {
      showSnack('OTP verification failed: $e', Colors.red);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> registerWithEmail() async {
    setState(() => isLoading = true);

    try {
      final userCred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: signUpInputController.text.trim(),
        password: passwordController.text.trim(),
      );

      await userCred.user?.sendEmailVerification();
      await saveUserData(userCred.user!.uid);

      showSnack("Registration successful! Please verify your email.", Colors.green);

      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DoctorListScreen()));
    } on FirebaseAuthException catch (e) {
      showSnack('Error: ${e.message}', Colors.red);
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    emailController.dispose();
    signUpInputController.dispose();
    otpController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Register"),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const Icon(Icons.person_add_alt, size: 80),
                  const SizedBox(height: 24),

                  if (!showStepTwo) ...[
                    TextField(
                      controller: nameController,
                      decoration: const InputDecoration(labelText: "Full Name"),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: gender,
                      items: ['Male', 'Female', 'Other']
                          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (value) => setState(() => gender = value!),
                      decoration: const InputDecoration(labelText: "Gender"),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(labelText: "Phone Number"),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: emailController,
                      decoration: const InputDecoration(labelText: "Email (optional)"),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        if (nameController.text.trim().isEmpty ||
                            phoneController.text.trim().isEmpty) {
                          showSnack('Please fill all required fields', Colors.red);
                          return;
                        }
                        setState(() {
                          showStepTwo = true;
                          signUpInputController.text = phoneController.text.trim();
                        });
                      },
                      child: const Text("Continue"),
                    ),
                  ] else ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ChoiceChip(
                          label: const Text("Sign up with Phone"),
                          selected: isSigningUpWithPhone,
                          onSelected: (val) {
                            setState(() {
                              isSigningUpWithPhone = true;
                              showOtpField = false;
                              signUpInputController.text = phoneController.text.trim();
                            });
                          },
                        ),
                        const SizedBox(width: 16),
                        ChoiceChip(
                          label: const Text("Sign up with Email"),
                          selected: !isSigningUpWithPhone,
                          onSelected: (val) {
                            setState(() {
                              isSigningUpWithPhone = false;
                              showOtpField = false;
                              signUpInputController.text = emailController.text.trim();
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: signUpInputController,
                      decoration: InputDecoration(
                        labelText: isSigningUpWithPhone
                            ? "Phone Number"
                            : "Email Address",
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: "Password"),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(labelText: "Confirm Password"),
                    ),
                    if (showOtpField) ...[
                      const SizedBox(height: 16),
                      TextField(
                        controller: otpController,
                        decoration: const InputDecoration(labelText: "OTP Code"),
                      ),
                    ],
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              if (passwordController.text != confirmPasswordController.text) {
                                showSnack('Passwords do not match', Colors.red);
                                return;
                              }

                              if (isSigningUpWithPhone) {
                                if (showOtpField) {
                                  await verifyOtpAndRegister();
                                } else {
                                  if (!isPhoneNumber(signUpInputController.text.trim())) {
                                    showSnack('Invalid phone number', Colors.red);
                                    return;
                                  }
                                  await verifyPhoneNumber();
                                }
                              } else {
                                if (!signUpInputController.text.contains('@')) {
                                  showSnack('Invalid email format', Colors.red);
                                  return;
                                }
                                await registerWithEmail();
                              }
                            },
                      child: Text(isSigningUpWithPhone && !showOtpField ? "Send OTP" : "Sign Up"),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isLoading)
            Container(
              color: Colors.black.withAlpha(100),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
