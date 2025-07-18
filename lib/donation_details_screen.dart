import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'custom_appbar_drawer.dart';

class DonationDetailsScreen extends StatefulWidget {
  final String postId;
  final String? campaignCaption;

  const DonationDetailsScreen({super.key, required this.postId, this.campaignCaption});

  @override
  State<DonationDetailsScreen> createState() => _DonationDetailsScreenState();
}

class _DonationDetailsScreenState extends State<DonationDetailsScreen> {
  final _amountController = TextEditingController(text: 'RM0.00');
  String? _selectedTransactionType;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _amountController.addListener(_formatAmount);
  }

  //format user input start with RM
  void _formatAmount() {
    String text = _amountController.text;
    if (!text.startsWith('RM') && text.isNotEmpty) {
      _amountController.value = TextEditingValue(
        text: 'RM$text',
        selection: TextSelection.collapsed(offset: 'RM$text'.length),
      );
    } else if (text == 'RM') {
      // Allow user to delete back to 'RM'
    } else if (text.isEmpty) {
      _amountController.value = const TextEditingValue(
        text: 'RM',
        selection: TextSelection.collapsed(offset: 'RM'.length),
      );
    }
  }

  // get image
  Future<String> _getImageStorageUrl(String storagePath) async {
    if (storagePath.isEmpty) return '';
    try {
      String path = storagePath.startsWith('/') ? storagePath.substring(1) : storagePath;
      return await FirebaseStorage.instance.ref(path).getDownloadURL();
    } catch (e) {
      print("Error getting image storage URL for '$storagePath': $e");
      return '';
    }
  }

  // show null image
  Widget _buildNullAssetImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        'assets/images/null.png',
        fit: BoxFit.cover,
        height: 350,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          print("Error loading asset image 'assets/images/null.png': $error");
          return Container(
            height: 350,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.broken_image, size: 60, color: Colors.grey),
          );
        },
      ),
    );
  }

  Widget _buildPostDisplayImage({String? base64, String? urlFromStorage}) {
    if (base64 != null && base64.isNotEmpty) {
      try {
        String b64String = base64;

        final commaIndex = b64String.indexOf(',');
        if (commaIndex != -1 && b64String.substring(0, commaIndex).contains(';base64')) {
          b64String = b64String.substring(commaIndex + 1);
        }

        final bytes = base64Decode(b64String);
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            height: 380,
            width: double.infinity,
            errorBuilder: (context, error, stackTrace) {
              print("Error rendering base64 image in DonationDetails: $error");
              print("Original base64 that caused error: $base64");
              return _buildNullAssetImage();
            },
          ),
        );
      } catch (e) {
        print("Error decoding base64 in DonationDetails: $e");
        print("Base64 string that failed decoding: $base64");
        return _buildNullAssetImage();
      }
    } else if (urlFromStorage != null && urlFromStorage.isNotEmpty) {
      return FutureBuilder<String>(
        future: _getImageStorageUrl(urlFromStorage),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 200,
              child: Center(child: CircularProgressIndicator()),
            );
          } else if (snapshot.hasData && snapshot.data!.isNotEmpty) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                snapshot.data!,
                fit: BoxFit.cover,
                height: 350,
                width: double.infinity,
                loadingBuilder:(BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                  if (loadingProgress == null) return child;
                  return SizedBox(
                    height: 200,
                    child: Center(
                      child: CircularProgressIndicator(
                        value: loadingProgress.expectedTotalBytes != null ?
                        loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  print("Error loading network image in DonationDetails from ${snapshot.data!}: $error");
                  return _buildNullAssetImage();
                },
              ),
            );
          } else {
            return _buildNullAssetImage();
          }
        },
      );
    } else {
      return _buildNullAssetImage();
    }
  }

  // image error
  Widget _buildImageErrorPlaceholder({String? message}) {
    if (message != null) {
      print("Image Error (placeholder invoked): $message");
    }
    return _buildNullAssetImage();
  }

  Widget _buildImageNotSupportedPlaceholder() {
    print("Image Not Supported (placeholder invoked)");
    return _buildNullAssetImage();
  }


  // get post data and show image
  Widget _buildFundraiserImageWrapper(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('posts').doc(widget.postId).get(),
      builder: (context, postSnapshot) {
        if (postSnapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 350,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (postSnapshot.hasError || !postSnapshot.hasData || !postSnapshot.data!.exists) {
          print('Error fetching post for image in DonationDetails: ${postSnapshot.error}');
          return _buildImageErrorPlaceholder(message: "Post data not found.");
        }

        final postData = postSnapshot.data!.data() as Map<String, dynamic>;

        String? base64ForWidget = postData['post_image_base64'] as String?;
        String? urlPathForWidget = postData['post_image_url'] as String?;

        if ((base64ForWidget == null || base64ForWidget.isEmpty) &&
            (urlPathForWidget != null && urlPathForWidget.isNotEmpty)) {
          if (!urlPathForWidget.startsWith('http://') &&
              !urlPathForWidget.startsWith('https://') &&
              !urlPathForWidget.startsWith('gs://')) {
            base64ForWidget = urlPathForWidget;
            urlPathForWidget = null;
          }
        }
        return _buildPostDisplayImage(base64: base64ForWidget, urlFromStorage: urlPathForWidget);
      },
    );
  }


  // transaction type
  Widget _buildTransactionTypeButton(String type) {
    bool isSelected = _selectedTransactionType == type;
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 15),
          backgroundColor: isSelected ? kPrimaryColor : Colors.grey.shade100,
          side: BorderSide(
            color: isSelected ? Colors.grey.shade300 : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1.0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
        ),
        onPressed: () {
          setState(() {
            _selectedTransactionType = type;
          });
        },
        child: Text(
          type,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.black87,
          ),
        ),
      ),
    );
  }

  //store to firebase
  Future<void> _processDonation() async {
    if (_isLoading) return;

    String rawAmount = _amountController.text.replaceFirst('RM', '');
    double? amountToDonateNum = double.tryParse(rawAmount);

    if (amountToDonateNum == null || amountToDonateNum <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid donation amount.')),
      );
      return;
    }
    if (_selectedTransactionType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a transaction type.')),
      );
      return;
    }

    final User? currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: You must be logged in to donate.')),
      );
      return;
    }

    setState(() { _isLoading = true; });

    try {
      await FirebaseFirestore.instance.collection('donations').add({
        'postID': widget.postId,
        'amount_received': amountToDonateNum,
        'userId': currentUser.uid,
        'transaction_type': _selectedTransactionType!,
        'timestamp': FieldValue.serverTimestamp(),
      });

      String formattedDonatedAmount = 'RM${amountToDonateNum.toStringAsFixed(2)}';
      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          '/donationSuccess',
          ModalRoute.withName('/home'),
          arguments: {
            'amount': formattedDonatedAmount,
            'postId': widget.postId,},
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Donation failed: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  @override
  void dispose() {
    _amountController.removeListener(_formatAmount);
    _amountController.dispose();
    super.dispose();
  }

  //=========================================================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.yellow.shade50,
      appBar: AppBar(
        title: const Text('Make Donation'),
        centerTitle: true,
        backgroundColor: kPrimaryColor,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            _buildFundraiserImageWrapper(context),
            const SizedBox(height: 20),
            if (widget.campaignCaption != null && widget.campaignCaption!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  widget.campaignCaption!,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
              ),
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Amount to be donated:',
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: 'RM0.00',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: kPrimaryColor, width: 2.0),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
              ),
              onTap: () {
                if (_amountController.text == 'RM0.00') {
                  _amountController.text = 'RM';
                  _amountController.selection = TextSelection.fromPosition(
                    TextPosition(offset: _amountController.text.length),
                  );
                }
              },
            ),
            const SizedBox(height: 20),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Type of Transaction',
                style: TextStyle(fontSize: 14, color: Colors.black87),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildTransactionTypeButton('E-Wallet'),
                const SizedBox(width: 10),
                _buildTransactionTypeButton('Online Transaction'),
              ],
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: kPrimaryColor,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                onPressed: _isLoading ? null : _processDonation,
                child: _isLoading
                    ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 3, color: Colors.black54),
                )
                    : const Text('Donate Now', style: TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}