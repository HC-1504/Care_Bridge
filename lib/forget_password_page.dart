import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';
import 'reset_password_page.dart';

class ForgetPasswordPage extends StatefulWidget {
  @override
  _ForgetPasswordPageState createState() => _ForgetPasswordPageState();
}

class _ForgetPasswordPageState extends State<ForgetPasswordPage> {
  final TextEditingController emailController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  Future<void> sendVerificationForReset() async {
    setState(() => _isLoading = true);

    try {

      await _auth.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: 'temporary_password',
      );


      await _auth.currentUser?.sendEmailVerification();


      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text("Verify Your Email"),
            content: Text(
              "We've sent a verification link to ${emailController.text.trim()}.\n\n"
                  "Please check your email and click the link to verify. Then click the button below.",
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => AlertDialog(
                      title: Text("Waiting for Verification"),
                      content: Text("Click 'I've verified' after verifying your email."),
                      actions: [
                        TextButton(
                          onPressed: () async {
                            await _auth.currentUser?.reload();
                            if (_auth.currentUser?.emailVerified ?? false) {
                              Navigator.pop(context);
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ResetPasswordPage(
                                    email: emailController.text.trim(),
                                  ),
                                ),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Email not verified yet.")),
                              );
                            }
                          },
                          child: Text("I've verified"),
                        ),
                      ],
                    ),
                  );
                },
                child: Text("OK"),
              ),
            ],
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      String message = "Something went wrong";
      if (e.code == 'user-not-found') {
        message = "No account found with that email.";
      } else if (e.code == 'wrong-password') {
        message = "This email is already registered. Please use correct flow.";
      } else if (e.code == 'invalid-email') {
        message = "Invalid email format.";
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: BackButton(onPressed: () {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginPage()));
        }),
        title: Text("Forgot Password"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            SizedBox(height: 40),
            Text(
              'Enter your email address',
              style: TextStyle(fontSize: 20),
            ),
            SizedBox(height: 20),
            TextFormField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: "Email",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: sendVerificationForReset,
              style: ElevatedButton.styleFrom(
                backgroundColor:Color(0xFFFBD157),
                minimumSize: Size(double.infinity, 50),
              ),
              child: _isLoading
                  ? CircularProgressIndicator(color: Colors.black)
                  : Text("Send Reset Link", style: TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }
}
