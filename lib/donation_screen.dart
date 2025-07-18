import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'custom_appbar_drawer.dart';

class DonationPage extends StatefulWidget {
  @override
  _DonationPageState createState() => _DonationPageState();
}

class _DonationPageState extends State<DonationPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Map<String, bool> _expandedPosts = {};

  // format timestamp
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'No date';
    return DateFormat('yyyy-MM-dd HH:mm').format(timestamp.toDate().toLocal());
  }

  // get post details
  Future<DocumentSnapshot?> _fetchPostById(String postId) async {
    try {
      final postDoc = await _firestore.collection('posts').doc(postId).get();
      if (postDoc.exists) return postDoc;
    } catch (e) {
      debugPrint("Failed to fetch post $postId: $e");
    }
    return null;
  }

  //=========================================================================================
  @override
  Widget build(BuildContext context) {
    final String? currentUserId = _auth.currentUser?.uid;

    // user not logged in
    if (currentUserId == null) {
      return Scaffold(
        appBar: CustomAppBarDrawer(title: 'Donation', activeScreen: 'donation'),
        drawer: CustomAppBarDrawer.buildDrawer(context, activeScreen: 'donation'),
        body: const Center(child: Text("User not logged in. Please log in to see your donations.")),
      );
    }

    return Scaffold(
      appBar: CustomAppBarDrawer(title: 'My Donations', activeScreen: 'donation'),
      drawer: CustomAppBarDrawer.buildDrawer(context, activeScreen: 'donation'),

      //get details from donations subcollections
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collectionGroup('donations')
            .where('userId', isEqualTo: currentUserId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, donationSnapshot) {
          if (donationSnapshot.hasError) {
            return const Center(child: Text("Error loading donations. Please try again later."));
          }
          if (donationSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!donationSnapshot.hasData || donationSnapshot.data!.docs.isEmpty) {
            return const Center(child: Text("You haven't made any donations yet."));
          }

          final donationDocs = donationSnapshot.data!.docs;

          // display donation in list
          return ListView.builder(
            key: const PageStorageKey('donationList'),
            itemCount: donationDocs.length,
            itemBuilder: (context, index) {
              final donationDoc = donationDocs[index];
              final donationData = donationDoc.data() as Map<String, dynamic>;
              final amount = (donationData['amount_received'] is num)
                  ? (donationData['amount_received'] as num).toDouble()
                  : 0.0;
              final donationTimestamp = donationData['timestamp'] as Timestamp?;
              final transactionType = donationData['transaction_type'] as String? ?? 'N/A';
              final postId = donationData['postID'] as String?;

              // check card is expanded or not
              final isExpanded = _expandedPosts[donationDoc.id] ?? false;

              // get post details relate to donation
              return FutureBuilder<DocumentSnapshot?>(
                future: postId != null ? _fetchPostById(postId) : Future.value(null),
                builder: (context, postSnapshot) {
                  final postData = postSnapshot.data?.data() as Map<String, dynamic>?;

                  // display post details
                  Widget postDetails = const SizedBox.shrink();
                  if (isExpanded) {
                    final caption = postData?['caption'] ?? 'Not available';
                    final postType = postData?['post_type'] ?? 'Not available';
                    final totalAmount = postData?['total_amount']?.toString() ?? 'Not available';
                    final postTime = postData?['timestamp'] as Timestamp?;
                    final imageBase64 = postData?['post_image_url'];

                    Widget imageWidget = const SizedBox.shrink();
                    if (imageBase64 != null && imageBase64.toString().isNotEmpty) {
                      try {
                        final bytes = base64Decode(imageBase64.toString().split(',').last);
                        imageWidget = Padding(
                          padding: const EdgeInsets.only(top: 10.0),
                          child: Image.memory(bytes, height: 200, fit: BoxFit.cover),
                        );
                      } catch (e) {
                        debugPrint("Error decoding image: $e");
                      }
                    }

                    postDetails = Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Caption: $caption"),
                          Text("Post Type: $postType"),
                          Text("Total Amount Needed: RM $totalAmount"),
                          Text("Post Time: ${_formatTimestamp(postTime)}"),
                          imageWidget,
                        ],
                      ),
                    );
                  }

                  // display card (donation)
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    elevation: 2,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Donation: RM ${amount.toStringAsFixed(2)}",
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _expandedPosts[donationDoc.id] = !isExpanded;
                                  });
                                },
                                icon: Icon(isExpanded ? Icons.expand_less : Icons.expand_more),
                                label: Text(isExpanded ? "Hide" : "Details"),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text("Donated on: ${_formatTimestamp(donationTimestamp)}"),
                          Text("Transaction Type: $transactionType"),
                          if (postId != null)
                            Text("Post ID: $postId")
                          else
                            const Text("Post ID: N/A", style: TextStyle(color: Colors.orange)),
                          postDetails,
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
