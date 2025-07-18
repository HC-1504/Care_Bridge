import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'auth_service.dart';
import 'user_model.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class EditProfilePage extends StatefulWidget {
  @override
  _EditProfilePageState createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  File? _imageFile;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  Uint8List? _currentProfileImage;
  Uint8List? _defaultImageBytes;

  final ImagePicker _picker = ImagePicker();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;


  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);
    final currentUser = authService.currentUser;

    if (currentUser != null) {
      setState(() {
        _usernameController.text = currentUser.username;
        _bioController.text = currentUser.bio;
        _currentProfileImage = currentUser.profileImage;
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
    _loadDefaultImage();
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
          _imageFile = File(pickedFile.path);
          _currentProfileImage = null;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to pick image: ${e.toString()}';
      });
    }
  }

  Future<void> _useDefaultImage() async {
    if (_defaultImageBytes != null) {

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/default.png');
      await file.writeAsBytes(_defaultImageBytes!);

      setState(() {
        _imageFile = file;
        _currentProfileImage = null;
      });
    }
  }

  Future<Uint8List?> _compressImage(File file) async {
    try {

      final originalSize = await file.length();
      print('Original image size: ${originalSize / 1024} KB');

      int quality = 90;
      if (originalSize > 2 * 1024 * 1024) {
        quality = 50;
      } else if (originalSize > 1 * 1024 * 1024) {
        quality = 70;
      }

      final result = await FlutterImageCompress.compressWithFile(
        file.absolute.path,
        quality: quality,
        minWidth: 800,
        minHeight: 800,
      );

      if (result != null) {
        print('Compressed image size: ${result.length / 1024} KB');
      }

      return result;
    } catch (e) {
      print('Error compressing image: $e');
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (_usernameController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Username cannot be empty';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;

      if (currentUser == null) {
        throw Exception('User not logged in');
      }


      String? base64Image;
      if (_imageFile != null) {
        final compressedBytes = await _compressImage(_imageFile!);

        if (compressedBytes == null) {
          throw Exception('Failed to compress image');
        }

        if (compressedBytes.length > 1024 * 1024) {
          setState(() {
            _errorMessage = 'Image is still too large after compression. Please try another image.';
          });
          return;
        }

        base64Image = base64Encode(compressedBytes);
      } else if (_currentProfileImage != null) {
        base64Image = base64Encode(_currentProfileImage!);
      }



      await _firestore.collection('users').doc(currentUser.userID).update({
        'username': _usernameController.text.trim(),
        'bio': _bioController.text.trim(),
        if (base64Image != null) 'profileImage': base64Image,
      });


      authService.setUser(
        UserModel(
          userID: currentUser.userID,
          email: currentUser.email ?? '',
          username: _usernameController.text.trim(),
          bio: _bioController.text.trim(),
          profileImage: base64Image != null ? base64Decode(base64Image) : null,
        ),
      );


      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile updated successfully!')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to update profile: ${e.toString()}';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }


  ImageProvider? _getProfileImage() {
    if (_imageFile != null) {
      return FileImage(_imageFile!);
    } else if (_currentProfileImage != null) {
      return MemoryImage(_currentProfileImage!);
    } else if (_defaultImageBytes != null) {
      return MemoryImage(_defaultImageBytes!);
    }
    return null;
  }

  bool _shouldShowPlaceholder() {
    return _imageFile == null && _currentProfileImage == null && _defaultImageBytes == null;
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

  @override
  Widget build(BuildContext context) {


    if(_isLoading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Color(0xFFFBD157),
        title: Text("Edit Profile",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),

      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              color: Color(0xFFFBD157),
              padding: EdgeInsets.only(top: 20, bottom: 50),
              child: Column(
                children: [


                  GestureDetector(
                    onTap: _showImagePickerOptions,
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: _getProfileImage(),
                      child: _shouldShowPlaceholder()
                          ? Icon(Icons.person, size: 40, color: Colors.white)
                          : null,
                    ),
                  ),
                  SizedBox(height: 8),
                  TextButton(
                    onPressed: _showImagePickerOptions,
                    child: Text("Change Picture",
                        style: TextStyle(color: Colors.black)),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  TextField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 16),
                  TextField(
                    controller: _bioController,
                    decoration: InputDecoration(
                      labelText: 'Bio',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                  ),
                  SizedBox(height: 16),
                  if (_errorMessage != null)
                    Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        _errorMessage!,
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFFBD157),
                        minimumSize: Size(double.infinity, 50),
                      ),
                      child: _isSaving
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text("Save Changes",
                          style: TextStyle(color: Colors.black)),
                    ),
                  ),
                ],
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
    _bioController.dispose();
    super.dispose();
  }
}