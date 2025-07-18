import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'user_model.dart';
import 'auth_service.dart';
import 'forget_password_page.dart';
import 'registration_page.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isPasswordVisible = false;
  bool isTermsAccepted = false;
  bool _isLoading = false;
  bool _isLocked = false;
  int _failedAttempts = 0;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;



  Future<void> _loginUser() async {
    if (_isLocked) return;

    if (!isTermsAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please accept the terms and privacy policy')),
      );
      return;
    }

    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {

      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );

      _failedAttempts = 0;

      DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      if (!userDoc.exists) {
        throw Exception('User not found in database');
      }

      var userData = userDoc.data() as Map<String, dynamic>;

      final authService = Provider.of<AuthService>(context, listen: false);
      authService.setUser(
        UserModel(
          userID: userDoc.id,
          email: emailController.text.trim(),
          username: userData['username'] ?? '',
          profileImage: userData['profileImage'] != null
              ? base64Decode(userData['profileImage'])
              : null,
          bio: userData['bio'] ?? '',
        ),
      );

      Navigator.pushNamedAndRemoveUntil(
        context,
        '/home',
            (route) => false,
      );

    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Login failed';

      _failedAttempts++;
      if (_failedAttempts >= 3) {
        setState(() {
          _isLocked = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Too many failed attempts. Try again in 10 seconds.')),
        );
        Future.delayed(Duration(seconds: 10), () {
          if (mounted) {
            setState(() {
              _isLocked = false;
              _failedAttempts = 0;
            });
          }
        });
        return;
      }

      if (e.code == 'user-not-found') {
        errorMessage = 'No user found with this email';
      }  else if (e.code == 'invalid-email') {
        errorMessage = 'Invalid email format';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Login failed: ${e.toString()}')),
      );
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
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 100),
              Text(
                'Login',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              Text('Email', style: TextStyle(fontWeight: FontWeight.bold)),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  hintText: 'Your email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 12),
              Text('Password', style: TextStyle(fontWeight: FontWeight.bold)),
              TextField(
                controller: passwordController,
                obscureText: !isPasswordVisible,
                decoration: InputDecoration(
                  hintText: '●●●●●●●',
                  border: OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () {
                      setState(() {
                        isPasswordVisible = !isPasswordVisible;
                      });
                    },
                  ),
                ),
              ),
              SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ForgetPasswordPage()),
                    );
                  },
                  child: Text('Forgot password?'),
                ),
              ),
              SizedBox(height: 10),
              Row(
                children: [
                  Checkbox(
                    value: isTermsAccepted,
                    onChanged: (value) {
                      setState(() {
                        isTermsAccepted = value!;
                      });
                    },
                  ),
                  Expanded(
                    child: Text('I accept the terms and privacy policy'),
                  ),
                ],
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _loginUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFFFBD157),
                  minimumSize: Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isLoading
                    ? CircularProgressIndicator(color: Colors.white)
                    : Text('Login', style: TextStyle(color: Colors.black)),
              ),
              SizedBox(height: 20),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => RegistrationPage()),
                    );
                  },
                  child: Text('New User? Create account'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}