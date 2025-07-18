import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'auth_service.dart';
import 'home_page.dart';
import 'user_model.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class SetProfilePage extends StatefulWidget {
  final String email;
  final String password;

  const SetProfilePage({Key? key, required this.email, required this.password}) : super(key: key);

  @override
  _SetProfilePageState createState() => _SetProfilePageState();
}

class _SetProfilePageState extends State<SetProfilePage> {
  final TextEditingController _usernameController = TextEditingController();
  File? _profileImage;
  Uint8List? _defaultImageBytes;
  final ImagePicker _picker = ImagePicker();
  bool _isLoading = false;
  bool _imageSelected = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    _loadDefaultImage();
  }

  Future<File?> _compressImage(File file) async {
    try {

      final originalSize = await file.length();


      int quality = 90;
      if (originalSize > 2 * 1024 * 1024) { // >2MB
        quality = 50;
      } else if (originalSize > 1 * 1024 * 1024) { // >1MB
        quality = 70;
      }


      final tempDir = await getTemporaryDirectory();
      final targetPath = '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';


      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: quality,
        minWidth: 800,
        minHeight: 800,
      );

      return result != null ? File(result.path) : null;
    } catch (e) {
      print('Error compressing image: $e');
      return null;
    }
  }

  Future<void> _loadDefaultImage() async {
    try {

      final byteData = await rootBundle.load('assets/images/default.png');
      setState(() {
        _defaultImageBytes = byteData.buffer.asUint8List();
      });
    } catch (e) {
      print('Error loading default image: $e');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final pickedFile = await _picker.pickImage(source: source);
      if (pickedFile != null) {
        setState(() {
          _profileImage = File(pickedFile.path);
          _imageSelected = true;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: ${e.toString()}')),
      );
    }
  }

  Future<void> _useDefaultImage() async {
    if (_defaultImageBytes != null) {

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/default.png');
      await file.writeAsBytes(_defaultImageBytes!);

      setState(() {
        _profileImage = file;
        _imageSelected = true;
      });
    }
  }

  void _showImagePickerOptions() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_library, color: Colors.blue),
                title: Text("Choose from library"),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: Icon(Icons.camera_alt, color: Colors.green),
                title: Text("Take photo"),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              ListTile(
                leading: Icon(Icons.image, color: Colors.orange),
                title: Text("Use default picture"),
                onTap: () {
                  Navigator.pop(context);
                  _useDefaultImage();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitProfile() async {
    if (!_imageSelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a profile image')),
      );
      return;
    }

    if (_usernameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a username')),
      );
      return;
    }



    setState(() {
      _isLoading = true;
    });

    try {
      final User? user = FirebaseAuth.instance.currentUser;

      if (user == null) throw Exception('User not authenticated');

      await user.updatePassword(widget.password);


      String? base64Image;
      if (_profileImage != null) {

        final compressedImage = await _compressImage(_profileImage!);
        if (compressedImage != null) {
          final imageSize = await compressedImage.length();
          if (imageSize > 1048576) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Image is still too large after compression. Please try another image.')),
            );
            return;
          }
          base64Image = base64Encode(await compressedImage.readAsBytes());
        }
      }

      final userRef = _firestore.collection('users').doc(user.uid);
      await userRef.set({
        'email': widget.email,
        'username': _usernameController.text,
        'profileImage': base64Image,
        'created_date': FieldValue.serverTimestamp(),
        'bio': '',
      });

      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.setUser(UserModel(
        userID: user.uid,
        email: widget.email,
        username: _usernameController.text,
        profileImage: _profileImage != null ? await _profileImage!.readAsBytes() : null,
        bio: '',
      ));

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile saved successfully!')),
      );

      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => HomePage()),(route) => false,);

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving profile: ${e.toString()}')),
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
      appBar: AppBar(
        title: Text('Complete Your Profile'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24),
        child: Column(
          children: [
            SizedBox(height: 20),
            Text(
              'Welcome, ${widget.email}',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            SizedBox(height: 40),


            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundImage: _profileImage != null
                        ? FileImage(_profileImage!)
                        : AssetImage('assets/images/default.png') as ImageProvider,
                    backgroundColor: Colors.grey[200],
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Color(0xFFFBD157),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(Icons.camera_alt, color: Colors.black),
                        onPressed: _showImagePickerOptions,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Add Profile Photo (size<1MB)',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (!_imageSelected)
              Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'Please select a profile image',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),

            SizedBox(height: 40),


            TextFormField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
                hintText: 'Enter your username',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a username';
                }
                return null;
              },
            ),
            SizedBox(height: 20),
            Text(
              'This will be how other users see you',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            SizedBox(height: 40),


            ElevatedButton(
              onPressed: _isLoading ? null : _submitProfile,
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
                'Complete Profile',
                style: TextStyle(color: Colors.black, fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }
}