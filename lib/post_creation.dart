import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'custom_appbar_drawer.dart';

// =====================================================================================================================
class PostCreation extends StatefulWidget {
  const PostCreation({super.key});

  @override
  PostCreationState createState() => PostCreationState();
}

// =====================================================================================================================
class PostCreationState extends State<PostCreation> {
  // Variables Declaration
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _totalAmountController = TextEditingController();
  final MapController _mapController = MapController();
  final FocusNode _captionFocusNode = FocusNode();
  final FocusNode _totalAmountFocusNode = FocusNode();
  final FocusNode _addressFocusNode = FocusNode();
  String? _userID;
  File? _selectedImage;
  bool _isLoading = false;
  String? _postType;
  LatLng? _selectedLocation;

  // Methods
  @override
  void initState() {
    super.initState();
    _loadUserID();
  }

  // Load the saved userID from SharedPreferences
  Future<void> _loadUserID() async {
    final prefs = await SharedPreferences.getInstance();
    final docId = prefs.getString('userID');

    if (docId == null) {
      print('No userID found in SharedPreferences.');
      return;
    }

    setState(() {
      _userID = docId;
    });
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _searchAddress() async {
    final query = _addressController.text.trim();
    if (query.isEmpty) return;

    final url = Uri.parse(
      'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&format=json&limit=1',
    );

    try {
      final response = await http.get(url, headers: {
        'User-Agent': 'CareBridge/1.0'
      });

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (data.isNotEmpty) {
          final lat = double.parse(data[0]['lat']);
          final lon = double.parse(data[0]['lon']);
          setState(() {
            _selectedLocation = LatLng(lat, lon);
            _mapController.move(_selectedLocation!, 15.0);  // Zoom to location
          });
        } else {
          _showSnackBar('Address not found');
        }
      } else {
        _showSnackBar('Failed to fetch location');
      }
    } catch (e) {
      _showSnackBar('Error: $e');
    }
  }

  Future<void> _uploadPost() async {
    final isFormValid = _formKey.currentState?.validate() ?? false;  // ?.validate() calls the validate() method if currentState is not null; ?? false means if currentState is null, it safely defaults to false

    if (!isFormValid) {
      // Focus to the first invalid field manually
      if (_captionController.text.length > 1000) {
        FocusScope.of(context).requestFocus(_captionFocusNode);
      } else if (_postType == 'donation') {
        final value = _totalAmountController.text;
        if (value.isEmpty || double.tryParse(value) == null || double.parse(value) <= 0) {
          FocusScope.of(context).requestFocus(_totalAmountFocusNode);
        }
      }

      return;
    }

    if (_selectedImage == null && _captionController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write a Caption / select an Image.')),
      );
      return;
    }

    if (_postType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a Post Type.')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? base64Image;
      if (_selectedImage != null) {
        final bytes = await _selectedImage!.readAsBytes();  // readAsBytes() is an asynchronous operation that converts the image file into a list of bytes
        if (bytes.lengthInBytes > 1 * 1024 * 1024) {  // 1MB
          throw 'Image size is too large. Please upload an image smaller than 1MB.';
        }
        base64Image = base64Encode(bytes);
      }

      final postData = {
        'userID': _userID,
        'post_type': _postType,
        'timestamp': FieldValue.serverTimestamp(),
        'is_edited': false,
      };

      // Conditionally add optional fields
      if (base64Image != null) {
        postData['post_image_url'] = base64Image;
      }

      if (_captionController.text.isNotEmpty) {
        postData['caption'] = _captionController.text.trim();
      }

      if (_addressController.text.trim().isNotEmpty) {
        postData['address'] = _addressController.text.trim(); // Store address as plain text
      }

      if (_selectedLocation != null) {
        postData['location'] = GeoPoint(_selectedLocation!.latitude, _selectedLocation!.longitude);
      }

      if (_totalAmountController.text.isNotEmpty) {
        postData['total_amount'] = double.tryParse(_totalAmountController.text);
      }

      // Save post data to Firestore
      final docRef = FirebaseFirestore.instance.collection('posts').doc();
      await docRef.set(postData);

      Navigator.pop(context, {
        'message': 'Post uploaded successfully!',
        'postType': _postType!,
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }

    _captionController.clear();
    setState(() {
      _selectedImage = null;
      _postType = null;
      _selectedLocation = null;
    });

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _detectCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showSnackBar('Location services are disabled.');
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showSnackBar('Location permissions are denied');
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _showSnackBar('Location permissions are permanently denied.');
      return;
    }

    Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );

    setState(() {
      _selectedLocation = LatLng(position.latitude, position.longitude);
      _mapController.move(_selectedLocation!, 15.0);
    });

    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        final formattedAddress =
            '${place.street}, ${place.locality}, ${place.administrativeArea}, ${place.postalCode}, ${place.country}';

        setState(() {
          _addressController.text = formattedAddress;
        });
      }
    } catch (e) {
      _showSnackBar('Failed to reverse geocode location.');
    }
  }

  // UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: CustomAppBarDrawer(
          title: 'Create post',
          actions: ElevatedButton(
            onPressed: _isLoading ? null : _uploadPost,
            child: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Post'),
          ),
          activeScreen: 'post_creation',
        ),
        drawer: CustomAppBarDrawer.buildDrawer(context, activeScreen: 'post_creation'),

        body: GestureDetector(
          onTap: () {
            FocusScope.of(context).unfocus(); // Dismiss the keyboard when tapping anywhere outside the TextField
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      child: Row(
                        children: const [
                          Icon(Icons.camera_alt_outlined, color: kPrimaryColor),  // Add an icon
                          SizedBox(width: 8),  // Space between icon and text
                          Text(
                            'Image',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: kPrimaryColor,  // Color for text
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    _selectedImage != null
                        ? Column(
                      children: [
                        Stack(
                          children: [
                            Image.file(_selectedImage!, height: 200),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: CircleAvatar(
                                backgroundColor: Colors.black54,
                                child: IconButton(
                                  icon: const Icon(Icons.close, color: Colors.white),
                                  tooltip: 'Remove Image',
                                  onPressed: () {
                                    setState(() {
                                      _selectedImage = null;
                                    });
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                        : SizedBox(
                      height: 200,
                      child: Center(
                        child: const Text('No image selected.'),
                      ),
                    ),


                    const SizedBox(height: 20),

                    ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.image),
                      label: const Text('Upload an Image (max 1 MB)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor, // Sets the background to yellow
                        foregroundColor: Colors.black,  // Sets the text color to black
                      ),
                    ),

                    const SizedBox(height: 20),

                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      child: Row(
                        children: const [
                          Icon(Icons.edit_note_sharp, color: kPrimaryColor),  // Add an icon
                          SizedBox(width: 8),  // Space between icon and text
                          Text(
                            'Caption',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: kPrimaryColor,  // Color for text
                            ),
                          ),
                        ],
                      ),
                    ),

                    TextFormField(
                      controller: _captionController,
                      focusNode: _captionFocusNode,
                      maxLines: 5,
                      decoration: const InputDecoration(
                        hintText: 'Write Post Caption here...',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value != null && value.length > 1000) {
                          return 'Caption must be under 1000 characters.';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      child: Row(
                        children: const [
                          Icon(Icons.label_important_sharp, color: kPrimaryColor),  // Add an icon
                          SizedBox(width: 8),  // Space between icon and text
                          Text(
                            'Post Type',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: kPrimaryColor,  // Color for text
                            ),
                          ),
                        ],
                      ),
                    ),

                    ListTile(
                      title: const Text(
                        'Volunteer Request Post',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        "Need volunteers for a community event? Create this post to invite people to join and support your initiative. "
                            "A 'Contact Us' button will be available for interested users.",
                      ),
                      leading: Radio<String>(
                        value: 'volunteer',
                        groupValue: _postType,
                        onChanged: (value) {
                          setState(() {
                            _totalAmountController.clear();
                            _postType = value!;

                            // Focus on the corresponding field
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              FocusScope.of(context).requestFocus(_addressFocusNode);
                            });

                            _formKey.currentState?.validate(); // Trigger validation update
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 10),

                    ListTile(
                      title: const Text(
                        'Donation Request Post',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: const Text(
                        "Need help for a fundraiser? Create this post to encourage donations for those in need. "
                            "A 'Donate Now' button will be available for easy contributions.",
                      ),
                      leading: Radio<String>(
                        value: 'donation',
                        groupValue: _postType,
                        onChanged: (value) {
                          setState(() {
                            _totalAmountController.clear();
                            _postType = value!;

                            // Focus on the corresponding field
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              FocusScope.of(context).requestFocus(_totalAmountFocusNode);
                            });

                            _formKey.currentState?.validate(); // Trigger validation update
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 10),

                    // Conditional display of the location picker for 'volunteer' post type
                    if (_postType == 'volunteer') ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.location_on, color: kPrimaryColor),
                                SizedBox(width: 8),
                                Text(
                                  'Event Location',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: kPrimaryColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _addressController,
                              focusNode: _addressFocusNode,
                              decoration: InputDecoration(
                                hintText: 'Enter event address...',
                                border: OutlineInputBorder(),
                                suffixIcon: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.my_location),
                                      tooltip: 'Use Current Location',
                                      onPressed: _detectCurrentLocation,
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.search),
                                      onPressed: _searchAddress,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        height: 300,
                        child: FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: _selectedLocation ?? LatLng(3.140853, 101.693207), // default to KL
                            initialZoom: 13.0,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                              subdomains: ['a', 'b', 'c'],
                            ),
                            if (_selectedLocation != null)
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: _selectedLocation!,
                                    width: 50,
                                    height: 50,
                                    child: const Icon(
                                      Icons.location_on,
                                      color: Colors.red,
                                      size: 30,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                    if (_postType == 'donation') ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: const [
                                Icon(Icons.attach_money, color: kPrimaryColor),
                                SizedBox(width: 8),
                                Text(
                                  'Total Amount Required (RM)',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: kPrimaryColor,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 8),

                            TextFormField(
                              controller: _totalAmountController,
                              focusNode: _totalAmountFocusNode,
                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(
                                hintText: 'Enter amount (e.g. 500.00)',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (_postType == 'donation') {  // Only validate if post type is donation
                                  if (value == null || value.isEmpty) {
                                    return 'Total Donation can\'t be empty';
                                  }
                                  final parsed = double.tryParse(value);
                                  if (parsed == null || parsed <= 0) {
                                    return 'Enter a valid amount';
                                  }
                                }
                                return null; // No error for other post types
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        )
    );
  }
}
