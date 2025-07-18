import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';

class ChangePasswordPage extends StatefulWidget {
  @override
  _ChangePasswordPageState createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _currentPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  double _passwordStrength = 0;
  int _strengthIndicator = 0; // 0: Weak, 1: Medium, 2: Strong


  bool _hasMinLength = false;
  bool _hasUpperCase = false;
  bool _hasLowerCase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _checkPasswordStrength(String password) {

    _hasMinLength = password.length >= 8;
    _hasUpperCase = password.contains(RegExp(r'[A-Z]'));
    _hasLowerCase = password.contains(RegExp(r'[a-z]'));
    _hasNumber = password.contains(RegExp(r'[0-9]'));
    _hasSpecialChar = password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'));


    double strength = 0;
    if (_hasMinLength) strength += 0.3;
    if (_hasUpperCase) strength += 0.2;
    if (_hasLowerCase) strength += 0.2;
    if (_hasNumber) strength += 0.2;
    if (_hasSpecialChar) strength += 0.3;

    strength = strength > 1.0 ? 1.0 : strength;

    setState(() {
      _passwordStrength = strength;
      if (strength < 0.4) {
        _strengthIndicator = 0; // Weak
      } else if (strength < 0.7) {
        _strengthIndicator = 1; // Medium
      } else {
        _strengthIndicator = 2; // Strong
      }
    });
  }


  Widget _buildPasswordRequirements() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Password must contain:',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        SizedBox(height: 4),
        Row(
          children: [
            Icon(
              _hasMinLength ? Icons.check_circle : Icons.error,
              color: _hasMinLength ? Colors.green : Colors.red,
              size: 16,
            ),
            SizedBox(width: 4),
            Text(
              '8+ characters',
              style: TextStyle(
                fontSize: 12,
                color: _hasMinLength ? Colors.green : Colors.grey,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Icon(
              _hasUpperCase ? Icons.check_circle : Icons.error,
              color: _hasUpperCase ? Colors.green : Colors.red,
              size: 16,
            ),
            SizedBox(width: 4),
            Text(
              'Uppercase letter',
              style: TextStyle(
                fontSize: 12,
                color: _hasUpperCase ? Colors.green : Colors.grey,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Icon(
              _hasLowerCase ? Icons.check_circle : Icons.error,
              color: _hasLowerCase ? Colors.green : Colors.red,
              size: 16,
            ),
            SizedBox(width: 4),
            Text(
              'Lowercase letter',
              style: TextStyle(
                fontSize: 12,
                color: _hasLowerCase ? Colors.green : Colors.grey,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Icon(
              _hasNumber ? Icons.check_circle : Icons.error,
              color: _hasNumber ? Colors.green : Colors.red,
              size: 16,
            ),
            SizedBox(width: 4),
            Text(
              'Number',
              style: TextStyle(
                fontSize: 12,
                color: _hasNumber ? Colors.green : Colors.grey,
              ),
            ),
          ],
        ),
        Row(
          children: [
            Icon(
              _hasSpecialChar ? Icons.check_circle : Icons.error,
              color: _hasSpecialChar ? Colors.green : Colors.red,
              size: 16,
            ),
            SizedBox(width: 4),
            Text(
              'Special character (!@#\$ etc)',
              style: TextStyle(
                fontSize: 12,
                color: _hasSpecialChar ? Colors.green : Colors.grey,
              ),
            ),
          ],
        ),
      ],
    );
  }


  String? _getPasswordError(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter a password';
    }

    final errors = <String>[];
    if (!_hasMinLength) errors.add('at least 8 characters');
    if (!_hasUpperCase) errors.add('an uppercase letter');
    if (!_hasLowerCase) errors.add('a lowercase letter');
    if (!_hasNumber) errors.add('a number');
    if (!_hasSpecialChar) errors.add('a special character (!@#\$ etc)');

    if (errors.isNotEmpty) {
      return 'Password must contain ${errors.join(', ')}';
    }

    return null;
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    final currentPassword = _currentPasswordController.text.trim();
    final newPassword = _newPasswordController.text.trim();


    if (_passwordStrength < 0.7) {
      setState(() {
        _errorMessage = 'Please choose a stronger password';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');


      final cred = EmailAuthProvider.credential(
        email: user.email!,
        password: currentPassword,
      );
      await user.reauthenticateWithCredential(cred);


      await user.updatePassword(newPassword);


      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Password changed successfully!')),
      );
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'wrong-password':
          errorMessage = 'Wrong password. Please enter your current password correctly.';
          break;
        case 'invalid-credential':
        case 'invalid-email':
        case 'invalid-verification-code':
        case 'invalid-verification-id':
          errorMessage = 'Invalid credentials. Please check and try again.';
          break;
        case 'user-mismatch':
          errorMessage = 'The credential does not match the current user.';
          break;
        case 'user-not-found':
          errorMessage = 'User account not found.';
          break;
        case 'requires-recent-login':
          errorMessage = 'This operation is sensitive and requires recent authentication. Please log in again.';
          break;
        default:
          errorMessage = 'Password change failed: ${e.message ?? 'Unknown error'}';
      }
      setState(() {
        _errorMessage = errorMessage;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: ${e.toString()}';
      });
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
      appBar: AppBar(
        backgroundColor: Color(0xFFFBD157),
        title: Text(
          'Change Password',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Change your password',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),


                TextFormField(
                  controller: _currentPasswordController,
                  obscureText: _obscureCurrentPassword,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureCurrentPassword
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () {
                        setState(() {
                          _obscureCurrentPassword = !_obscureCurrentPassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your current password';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 20),


                TextFormField(
                  controller: _newPasswordController,
                  obscureText: _obscureNewPassword,
                  onChanged: _checkPasswordStrength,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureNewPassword
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () {
                        setState(() {
                          _obscureNewPassword = !_obscureNewPassword;
                        });
                      },
                    ),
                  ),
                  validator: _getPasswordError,
                ),


                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: LinearProgressIndicator(
                        value: _passwordStrength,
                        backgroundColor: Colors.grey[200],
                        color: _strengthIndicator == 0
                            ? Colors.red
                            : _strengthIndicator == 1
                            ? Colors.orange
                            : Colors.green,
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      _strengthIndicator == 0
                          ? 'Weak'
                          : _strengthIndicator == 1
                          ? 'Medium'
                          : 'Strong',
                      style: TextStyle(
                        color: _strengthIndicator == 0
                            ? Colors.red
                            : _strengthIndicator == 1
                            ? Colors.orange
                            : Colors.green,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                _buildPasswordRequirements(),
                SizedBox(height: 20),


                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscureConfirmPassword
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value != _newPasswordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),


                if (_errorMessage != null) ...[
                  SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red),
                  ),
                ],


                SizedBox(height: 30),
                ElevatedButton(
                  onPressed: _isLoading ? null : _changePassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFFFBD157),
                    minimumSize: Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text(
                    'Change Password',
                    style: TextStyle(color: Colors.black, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}