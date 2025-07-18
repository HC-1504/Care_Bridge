import 'package:flutter/material.dart';
import 'set_profile_page.dart';

class SetPasswordPage extends StatefulWidget {
  final String email;

  const SetPasswordPage({Key? key, required this.email}) : super(key: key);

  @override
  _SetPasswordPageState createState() => _SetPasswordPageState();
}

class _SetPasswordPageState extends State<SetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;
  double _passwordStrength = 0;
  // 0: Weak, 1: Medium, 2: Strong
  int _strengthIndicator = 0;


  bool _hasMinLength = false;
  bool _hasUpperCase = false;
  bool _hasLowerCase = false;
  bool _hasNumber = false;
  bool _hasSpecialChar = false;

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
    if (value.length < 8) errors.add('at least 8 characters');
    if (!_hasUpperCase) errors.add('an uppercase letter');
    if (!_hasLowerCase) errors.add('a lowercase letter');
    if (!_hasNumber) errors.add('a number');
    if (!_hasSpecialChar) errors.add('a special character (!@#\$ etc)');

    if (errors.isNotEmpty) {
      return 'Password must contain ${errors.join(', ')}';
    }

    return null;
  }

  Future<void> _submitPassword() async {
    if (!_formKey.currentState!.validate()) return;


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

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => SetProfilePage(
              email: widget.email,
              password: _passwordController.text.trim(),
            ),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error: ${e.toString()}';
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 20),
                Text(
                  'Set your password',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 20),
                Text(
                  'Create a secure password for your account',
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),

                if (_errorMessage != null) ...[
                  SizedBox(height: 20),
                  Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red, fontSize: 14),
                  ),
                ],

                SizedBox(height: 20),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  onChanged: (value) => _checkPasswordStrength(value),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
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
                    labelText: 'Confirm Password',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                  ),
                  validator: (value) {
                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _isLoading ? null : _submitPassword,
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
                    'Continue',
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
}