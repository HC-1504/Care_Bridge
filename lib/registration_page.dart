import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'login_page.dart';
import 'set_password_page.dart';

class RegistrationPage extends StatefulWidget {
  @override
  _RegistrationPageState createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final TextEditingController emailController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  Future<void> submitEmail() async {
    setState(() {
      _isLoading = true;
    });

    try {

      await _auth.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: "temporary_password",
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
                    "Please check your email and click the link to verify your account. "
                    "Once done, click the button below."),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.pop(context);

                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => AlertDialog(
                      title: Text("Waiting for Email Verification"),
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
                                  builder: (context) => SetPasswordPage(
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
      String errorMessage = "An error occurred";
      if (e.code == 'email-already-in-use') {
        errorMessage = "This email is already registered";
      } else if (e.code == 'invalid-email') {
        errorMessage = "Please enter a valid email address";
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 100),
              Text(
                'Create account',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 40),
              Text(
                'What is your email address?',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              Text(
                'Enter the email address at which you can be contacted',
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              SizedBox(height: 40),
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email address',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                      .hasMatch(value)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              SizedBox(height: 40),
              ElevatedButton(
                onPressed: submitEmail,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFBD157),
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  'Continue',
                  style: TextStyle(color: Colors.black, fontSize: 16),
                ),
              ),
              SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => LoginPage()),
                    );
                  },
                  child: Text(
                    'Already have an account? Login',
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

    );
  }
}