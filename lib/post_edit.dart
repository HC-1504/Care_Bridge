import 'dart:io';
import 'dart:convert';
import 'profile_page.dart';
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
class EditPostScreen extends StatefulWidget {
  final String postId;

  const EditPostScreen({super.key, required this.postId});

  @override
  _EditPostScreenState createState() => _EditPostScreenState();
}

// =====================================================================================================================
class _EditPostScreenState extends State<EditPostScreen> {
  // Variables Declaration
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _captionController = TextEditingController();
  File? _selectedImage;
  bool _isLoading = false;
  String? _postType;
  LatLng? _selectedLocation;
  final TextEditingController _addressController = TextEditingController();
  final MapController _mapController = MapController();
  final TextEditingController _totalAmountController = TextEditingController();
  final FocusNode _captionFocusNode = FocusNode();
  final FocusNode _totalAmountFocusNode = FocusNode();
  final FocusNode _addressFocusNode = FocusNode();

  String? _existingImageUrl;
  DocumentReference? _postDocRef;
  bool isVolunteerPost = true;
  double _amountReceived = 0.0;

  // Methods
  @override
  void initState() {
    super.initState();
    _loadUserID();
    _loadPostData();
  }

  Future<void> _loadPostData() async {
    try {
      _postDocRef = FirebaseFirestore.instance.collection('posts').doc(widget.postId);
      final doc = await _postDocRef!.get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;

        _captionController.text = data['caption'] ?? '';
        _postType = data['post_type'];
        isVolunteerPost = _postType == 'volunteer';

        // Check for existing donations if this is a donation post
        if (_postType == 'donation') {
          await _checkExistingDonations();
        }

        if (data['location'] != null) {
          final geo = data['location'] as GeoPoint;
          _selectedLocation = LatLng(geo.latitude, geo.longitude);

          // Move map to the location
          Future.delayed(Duration.zero, () {
            _mapController.move(_selectedLocation!, 15.0);
          });
        }

        if (data['post_image_url'] != null) {
          _existingImageUrl = data['post_image_url'];
        }

        if (data['address'] != null) {
          _addressController.text = data['address'];
        }

        if (data['total_amount'] != null) {
          _totalAmountController.text = data['total_amount'].toString();
        }

        setState(() {});
      }
    } catch (e) {
      _showSnackBar('Failed to load post: $e');
    }
  }

  // Load the saved userID from SharedPreferences
  Future<void> _loadUserID() async {
    final prefs = await SharedPreferences.getInstance();
    final docId = prefs.getString('userID');

    if (docId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No userID found in Shared Pref'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
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

  // check for existing donations
  Future<void> _checkExistingDonations() async {
    try {
      final donations = await FirebaseFirestore.instance
          .collection('donations')
          .where('postID', isEqualTo: widget.postId)
          .get();

      double totalReceived = 0.0;

      for (var doc in donations.docs) {
        totalReceived += (doc['amount_received'] as num).toDouble();
      }

      setState(() {
        _amountReceived = totalReceived;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error checking donations: $e'),
          backgroundColor: Colors.red,
        ),
      );
      _showSnackBar('Failed to check donation status');
    }
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

  Future<void> _editPost() async {
    final isFormValid = _formKey.currentState?.validate() ?? false;

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
        final bytes = await _selectedImage!.readAsBytes();
        if (bytes.lengthInBytes > 1 * 1024 * 1024) {
          throw 'Image size is too large. Please upload an image smaller than 1MB.';
        }
        base64Image = base64Encode(bytes);
      }

      final updatedData = {
        'timestamp': FieldValue.serverTimestamp(),
        'is_edited': true,
      };

      // Prevent updating total_amount if donations exist
      if (_postType == 'donation' && _amountReceived > 0) {
        // Remove total_amount from update data to prevent changes
        if (updatedData.containsKey('total_amount')) {
          updatedData.remove('total_amount');
        }
      }

      // Handle image removal - use FieldValue.delete() to remove the field
      if (_selectedImage == null && _existingImageUrl == null) {
        updatedData['post_image_url'] = FieldValue.delete();
      } else if (base64Image != null) {
        updatedData['post_image_url'] = base64Image;
      }

      // Handle caption
      if (_captionController.text.isNotEmpty) {
        updatedData['caption'] = _captionController.text.trim();
      } else {
        updatedData['caption'] = FieldValue.delete();
      }

      // Handle address and location removal
      if (_addressController.text.trim().isEmpty) {
        updatedData['address'] = FieldValue.delete();
        updatedData['location'] = FieldValue.delete();
      } else {
        updatedData['address'] = _addressController.text.trim();
        if (_selectedLocation != null) {
          updatedData['location'] = GeoPoint(_selectedLocation!.latitude, _selectedLocation!.longitude);
        }
      }

      // Handle donation amount
      if (_postType == 'donation') {
        if (_totalAmountController.text.isNotEmpty) {
          updatedData['total_amount'] = double.tryParse(_totalAmountController.text)!;
        } else {
          updatedData['total_amount'] = FieldValue.delete();
        }
      }

      // Update post data to Firestore
      await _postDocRef!.update(updatedData);

      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => ProfilePage()),
      );
      _showSnackBar('Post updated successfully.');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
            title: 'Edit post',
            actions: ElevatedButton(
              onPressed: _isLoading ? null : _editPost,
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
            activeScreen: 'post_edit'
        ),
        drawer: CustomAppBarDrawer.buildDrawer(context, activeScreen: 'post_edit'),

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

                    (_selectedImage != null)
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
                        :
                    (_existingImageUrl != null)
                        ? Column(
                      children: [
                        Stack(
                          children: [
                            Image.memory(base64Decode(_existingImageUrl!), height: 200),
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
                                      _existingImageUrl = null;
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
                        : const SizedBox(
                      height: 200,
                      child: Center(
                        child: Text('No image selected.'),
                      ),
                    ),

                    const SizedBox(height: 20),

                    ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.image),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor, // Sets the background to yellow
                        foregroundColor: Colors.black,  // Sets the text color to black
                      ),
                      label: const Text('Upload an Image (max 1 MB)'),
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
                      title: Text(
                        'Volunteer Request Post',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isVolunteerPost ? Colors.black : Colors.grey,
                        ),
                      ),
                      subtitle: Text(
                        "Need volunteers for a community event? Create this post to invite people to join and support your initiative. "
                            "A 'Contact Us' button will be available for interested users.",
                        style: TextStyle(
                          color: isVolunteerPost ? Colors.black : Colors.grey,
                        ),
                      ),
                      leading: Radio<String>(
                        value: 'volunteer',
                        groupValue: _postType,
                        onChanged: null,
                      ),
                    ),

                    const SizedBox(height: 10),

                    ListTile(
                      title: Text(
                        'Donation Request Post',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isVolunteerPost ? Colors.grey : Colors.black,
                        ),
                      ),
                      subtitle: Text(
                        "Need help for a fundraiser? Create this post to encourage donations for those in need. "
                            "A 'Donate Now' button will be available for easy contributions.",
                        style: TextStyle(
                          color: isVolunteerPost ? Colors.grey : Colors.black,
                        ),
                      ),
                      leading: Radio<String>(
                        value: 'donation',
                        groupValue: _postType,
                        onChanged: null,
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
                                    if (_addressController.text.isNotEmpty)
                                      IconButton(
                                        icon: Icon(Icons.clear),
                                        onPressed: () {
                                          setState(() {
                                            _addressController.clear();
                                            _selectedLocation = null;
                                          });
                                        },
                                      ),
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

                            if (_amountReceived > 0) ...[
                              TextFormField(
                                controller: _totalAmountController,
                                focusNode: _totalAmountFocusNode,
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  hintText: 'Enter amount (e.g. 500.00)',
                                  border: OutlineInputBorder(),
                                ),
                                enabled: false,
                                validator: (value) {
                                  if (_postType == 'donation') {
                                    if (value == null || value.isEmpty) {
                                      return 'Total Donation can\'t be empty';
                                    }
                                    final parsed = double.tryParse(value);
                                    if (parsed == null || parsed <= 0) {
                                      return 'Enter a valid amount';
                                    }
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Donations have already been received for this post. '
                                    'The total amount cannot be modified.',
                                style: TextStyle(
                                  color: Colors.red[400],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Amount received so far: ${_amountReceived.toStringAsFixed(2)}',
                                style: TextStyle(
                                  color: Colors.green[700],
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ] else ...[
                              TextFormField(
                                controller: _totalAmountController,
                                focusNode: _totalAmountFocusNode,
                                keyboardType: TextInputType.numberWithOptions(decimal: true),
                                decoration: const InputDecoration(
                                  hintText: 'Enter amount (e.g. 500.00)',
                                  border: OutlineInputBorder(),
                                ),
                                validator: (value) {
                                  if (_postType == 'donation') {
                                    if (value == null || value.isEmpty) {
                                      return 'Total Donation can\'t be empty';
                                    }
                                    final parsed = double.tryParse(value);
                                    if (parsed == null || parsed <= 0) {
                                      return 'Enter a valid amount';
                                    }
                                  }
                                  return null;
                                },
                              ),
                            ],
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
