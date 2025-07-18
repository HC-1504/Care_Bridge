import 'dart:convert';
import 'custom_appbar_drawer.dart'; // Assuming kPrimaryColor is here or defined globally
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';


class DonationByPost extends StatelessWidget {
  final String postId;

  const DonationByPost({required this.postId, Key? key}) : super(key: key);

  // Get download URL from Firebase Storage if path is valid
  Future<String> _getImageUrl(String storagePath) async {
    if (storagePath.isEmpty) return '';
    try {
      String path = storagePath.startsWith('/') ? storagePath.substring(1) : storagePath;
      return await FirebaseStorage.instance.ref(path).getDownloadURL();
    } catch (e) {
      print("Error getting image URL for '$storagePath': $e");
      return '';
    }
  }

  // show if image null
  Widget _buildPostImage({String? base64, String? url}) {
    Widget fallbackImage = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        'assets/images/null.png',
        fit: BoxFit.cover,
        height: 350,
        width: double.infinity,
        errorBuilder: (context, error, stackTrace) {
          print("Error loading asset 'assets/images/null.png': $error");
          return const Icon(Icons.broken_image, size: 100, color: Colors.grey);
        },
      ),
    );

    if (base64 != null && base64.isNotEmpty) {
      try {
        final bytes = base64Decode(base64);
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            height: 350,
            width: double.infinity,
          ),
        );
      } catch (e) {
        print("Error decoding base64 image in DonationByPost: $e");
        return fallbackImage;
      }
    } else if (url != null && url.isNotEmpty) {  // load url
      return FutureBuilder<String>(
        future: _getImageUrl(url),
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
                errorBuilder: (context, error, stackTrace) {
                  print("Error loading network image from ${snapshot.data!} in DonationByPost: $error");
                  return fallbackImage;
                },
              ),
            );
          } else {
            return fallbackImage;
          }
        },
      );
    } else {
      return fallbackImage;
    }
  }

  //=========================================================================================

  @override
  Widget build(BuildContext context) {
    final postRef = FirebaseFirestore.instance.collection('posts').doc(postId);

    return StreamBuilder<DocumentSnapshot>(
      stream: postRef.snapshots(),
      builder: (context, postSnapshot) {
        if (postSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (postSnapshot.hasError) {
          return Center(child: Text('Error: ${postSnapshot.error}'));
        }
        if (!postSnapshot.hasData || !postSnapshot.data!.exists) {
          return const Center(child: Text('Post not found.'));
        }

        // get data from posts
        final postData = postSnapshot.data!.data() as Map<String, dynamic>;
        final String caption = postData['caption'] as String? ?? 'No Caption';
        final double targetAmount = (postData['total_amount'] ?? 0).toDouble();

        String? base64ForWidget = postData['post_image_base64'] as String?;
        String? urlPathForWidget = postData['post_image_url'] as String?;

        // logic to identifies post_image_url contains base64 data
        if ((base64ForWidget == null || base64ForWidget.isEmpty) &&
            (urlPathForWidget != null && urlPathForWidget.isNotEmpty)) {
          if (!urlPathForWidget.startsWith('http://') &&
              !urlPathForWidget.startsWith('https://') &&
              !urlPathForWidget.startsWith('gs://')) {
            base64ForWidget = urlPathForWidget;
            urlPathForWidget = null;
          }
        }

        //get donations about the post
        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('donations')
              .where('postID', isEqualTo: postId)
              .snapshots(),
          builder: (context, donationSnapshot) {
            if (donationSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            //calculate total received donation
            double totalReceived = 0;
            if (donationSnapshot.hasData && donationSnapshot.data!.docs.isNotEmpty) {
              totalReceived = donationSnapshot.data!.docs.fold(0.0, (sum, doc) {
                final data = doc.data() as Map<String, dynamic>;
                final amount = (data['amount_received'] ?? 0).toDouble();
                return sum + amount;
              });
            }

            final double progress = (targetAmount > 0) ? (totalReceived / targetAmount) : 0;
            final bool goalReached = targetAmount > 0 && totalReceived >= targetAmount;

            return Scaffold(
              backgroundColor: Colors.yellow.shade50,
              appBar: AppBar(
                title: const Text('Donation By Post'),
                centerTitle: true,
                backgroundColor: kPrimaryColor,
              ),
              body: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(10),
                  child: Card(
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildPostImage(base64: base64ForWidget, url: urlPathForWidget),
                          const SizedBox(height: 12),
                          Text(caption, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Text(
                            'RM ${totalReceived.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          Text(
                            'of RM ${targetAmount.toStringAsFixed(2)} raised',
                            style: const TextStyle(fontSize: 20, color: Colors.black87),
                          ),
                          const SizedBox(height: 12),
                          LinearProgressIndicator(   //donation progress bar
                            value: progress.clamp(0.0, 1.0),
                            backgroundColor: Colors.grey[300],
                            color: Colors.amberAccent,
                            minHeight: 15,
                            borderRadius: BorderRadius.circular(5),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(       //donate button
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kPrimaryColor,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: goalReached
                                  ? null
                                  : () {
                                Navigator.pushNamed(
                                  context,
                                  '/donationDetails',
                                  arguments: {
                                    'postId': postId,
                                    'campaignCaption': caption,
                                    'targetAmount': targetAmount,
                                    'currentCollected': totalReceived,
                                  },
                                );
                              },
                              child: Text(
                                goalReached ? 'Goal Reached!' : 'Donate Now',
                                style: const TextStyle(fontSize: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}