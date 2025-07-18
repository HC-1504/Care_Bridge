import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'custom_appbar_drawer.dart';

class DonationSuccessScreen extends StatefulWidget {
  const DonationSuccessScreen({super.key});

  @override
  State<DonationSuccessScreen> createState() => _DonationSuccessScreenState();
}

class _DonationSuccessScreenState extends State<DonationSuccessScreen> {
  String? _donatedAmount;
  String? _postId;
  Future<Uint8List?>? _imageFuture;
  String _campaignCaption = 'Loading caption...';

  bool _dataInitialized = false; // prevent multiple initialization

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize data only once
    if (!_dataInitialized) {
      final Map<String, dynamic>? args =
      ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      if (args != null) {
        _donatedAmount = args['amount'] as String? ?? 'your donation';
        _postId = args['postId'] as String?;
        if (_postId != null) {
          _imageFuture = _fetchPostImageBase64(_postId!);
          _fetchPostCaption(_postId!);
        } else {
          _campaignCaption = 'Thank you for your generosity!';
        }
      } else {
        _donatedAmount = 'your donation';
        _campaignCaption = 'Thank you for your generosity!';
      }
      _dataInitialized = true; // Mark as initialized
    }
  }

  Future<Uint8List?> _fetchPostImageBase64(String postId) async {
    try {
      DocumentSnapshot postDoc =
      await FirebaseFirestore.instance.collection('posts').doc(postId).get();
      if (postDoc.exists) {
        final data = postDoc.data() as Map<String, dynamic>?;

        String? base64String = data?['post_image_base64'] as String?;
        if (base64String == null || base64String.isEmpty) {
          base64String = data?['post_image_url'] as String?;

          if (base64String != null && (base64String.startsWith('http://') || base64String.startsWith('https://') || base64String.startsWith('gs://'))) {
            base64String = null;
          }
        }

        if (base64String != null && base64String.isNotEmpty) {
          final String pureBase64 = base64String.startsWith('data:image')
              ? base64String.substring(base64String.indexOf(',') + 1)
              : base64String;
          return base64Decode(pureBase64);
        }
      }
    } catch (e) {
      print("Error fetching or decoding Base64 image for success screen: $e");
    }
    return null;
  }

  Future<void> _fetchPostCaption(String postId) async {
    try {
      DocumentSnapshot postDoc =
      await FirebaseFirestore.instance.collection('posts').doc(postId).get();
      if (mounted) {
        if (postDoc.exists) {
          final data = postDoc.data() as Map<String, dynamic>?;
          setState(() {
            _campaignCaption = data?['caption'] as String? ?? 'Campaign Details';
          });
        } else {
          setState(() {
            _campaignCaption = 'Campaign Details Unavailable';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _campaignCaption = 'Error loading caption';
        });
      }
      print("Error fetching post caption for success screen: $e");
    }
  }

  Widget _buildFundraiserImage() {
    if (_postId == null) {
      return _buildDefaultInfoPlaceholder(message: "Details not available for this donation.");
    }
    if (_imageFuture == null) {
      return _buildDefaultAssetImage();
    }


    return FutureBuilder<Uint8List?>(
      future: _imageFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 250,
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const CircularProgressIndicator(),
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          print("Image snapshot error or no data for post $_postId: ${snapshot.error}");
          return _buildDefaultAssetImage();
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(
              snapshot.data!,
              fit: BoxFit.cover,
              height: 250,
              width: double.infinity,
              errorBuilder: (context, error, stackTrace) {
                print("Error building image from memory for post $_postId: $error");
                return _buildDefaultAssetImage();
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildDefaultAssetImage() {
    return Container(
      height: 250,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
          image: const DecorationImage(
            image: AssetImage('assets/images/null.png'),
            fit: BoxFit.cover,
          )
      ),
      child: Center(       //show icon if asset fails or as overlay
          child: Image.asset(
            'assets/images/null.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.image_not_supported, size: 60, color: Colors.grey);
            },
          )
      ),
    );
  }

  Widget _buildDefaultInfoPlaceholder({String message = "Information not available."}) {
    return Container(
      height: 250,
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ),
      ),
    );
  }

  //=========================================================================================

  @override
  Widget build(BuildContext context) {
    // make sure data loaded before building the main content
    if (!_dataInitialized) {

      return Scaffold(
        backgroundColor: Colors.yellow.shade50,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Donation Successful'),
          centerTitle: true,
          backgroundColor: kPrimaryColor,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.yellow.shade50,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Donation Successful'),
        centerTitle: true,
        backgroundColor: kPrimaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[

            if (_postId != null)
              _buildFundraiserImage()
            else
              _buildDefaultInfoPlaceholder(message: "Thank you for your generous donation!"),

            const SizedBox(height: 8),
            Text(
              _campaignCaption ?? "Campaign",
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87
              ),
            ),
            const SizedBox(height: 40),
            Text(
              'You have successfully donated ${_donatedAmount ?? "your contribution"}!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Thank You for\nyour donation!!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.amber.shade700,
              ),
            ),

            const SizedBox(height: 50),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                ),
                onPressed: () {
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/home',
                        (Route<dynamic> route) => false,
                  );
                },
                child: const Text('Return to Home'),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}