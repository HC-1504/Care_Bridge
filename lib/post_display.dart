import 'dart:convert';
import 'post_creation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'chat_by_post_screen.dart';
import 'custom_appbar_drawer.dart';
import 'donation_by_post_screen.dart';
import 'view_profile_page.dart';

// =====================================================================================================================
class PostScreen extends StatefulWidget {
  final int initialTabIndex;
  const PostScreen({super.key, this.initialTabIndex = 0});

  @override
  PostScreenState createState() => PostScreenState();
}

// =====================================================================================================================
class PostScreenState extends State<PostScreen> with SingleTickerProviderStateMixin {
  String? _message;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBarDrawer(
        title: 'Post',
        activeScreen: 'post_display',
      ),
      drawer: CustomAppBarDrawer.buildDrawer(context, activeScreen: 'post_display'),
      body: Column(
        children: [
          // Tab Bar
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Volunteer'),
              Tab(text: 'Donation'),
            ],
          ),

          if (_message != null)
            Container(
              width: double.infinity,
              color: kPrimaryColor,
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: Text(
                  _message!,
                  style: const TextStyle(color: Colors.black, fontSize: 16),
                ),
              ),
            ),

          // Wrapping the list view inside a Column
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  StreamBuilder(
                    stream: FirebaseFirestore.instance
                        .collection('posts')
                        .orderBy('timestamp', descending: true)
                        .snapshots(),
                    builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      if (snapshot.hasError) {
                        return const Center(child: Text('Something went wrong'));
                      }

                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return const Center(child: Text('No posts available.'));
                      }

                      var posts = snapshot.data!.docs;

                      final selectedType = _tabController.index == 0 ? 'volunteer' : 'donation';
                      var filteredPosts = posts.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return data['post_type'] == selectedType;
                      }).toList();

                      return Column(
                        children: List.generate(filteredPosts.length, (index) {
                          var post = filteredPosts[index].data() as Map<String, dynamic>;
                          return PostCard(
                            key: ValueKey(filteredPosts[index].id),
                            postId: filteredPosts[index].id,
                            userId: post['userID'],
                            caption: post['caption'],
                            address: post['address'],
                            location: post['location'],
                            postImageUrl: post['post_image_url'],
                            postType: post['post_type'],
                            totalAmount: (post['total_amount'] as num?)?.toDouble(),
                            timestamp: post['timestamp'],
                            isEdited: post['is_edited'],
                          );
                        }),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const PostCreation()),
          );

          if (result != null && result.isNotEmpty) {
            setState(() {
              _message = result['message'];
              _tabController.index = result['postType'] == 'donation' ? 1 : 0;
            });

            // Clear the message after 3 seconds
            Future.delayed(const Duration(seconds: 3), () {
              setState(() {
                _message = null;
              });
            });
          }
        },
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.black87,
        child: const Icon(Icons.add),
      ),
    );
  }
}

// =====================================================================================================================
class PostCard extends StatelessWidget {
  // Var decl
  final String postId;
  final String userId;
  final String? caption;
  final String? address;
  final GeoPoint? location;
  final String? postImageUrl;
  final String postType;
  final double? totalAmount;
  final Timestamp timestamp;
  final bool isEdited;

  // constr
  PostCard({
    super.key,
    required this.postId,
    required this.userId,
    this.caption,
    this.address,
    this.location,
    this.postImageUrl,
    required this.postType,
    this.totalAmount,
    required this.timestamp,
    required this.isEdited,
  });

  // methods
  Future<double> _fetchCollectedAmount() async {
    final query = await FirebaseFirestore.instance
        .collection('donations')
        .where('postID', isEqualTo: postId)
        .get();

    double total = 0.0;
    for (var doc in query.docs) {
      final data = doc.data();
      total += (data['amount_received'] ?? 0).toDouble();
    }

    return total;
  }

  // UI
  @override
  Widget build(BuildContext context) {
    // Extract latitude and longitude from Firebase GeoPoint
    final LatLng latLng = location != null
        ? LatLng(location!.latitude, location!.longitude)
        : LatLng(0, 0);  // Default to (0, 0) if location is null

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)  // Use the document ID to fetch the document
          .get(),  // Fetch the document
      builder: (context, userSnapshot) {
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (userSnapshot.hasError || !userSnapshot.hasData || !userSnapshot.data!.exists) {
          return const Center(child: Text('User not found'));
        }

        var userData = userSnapshot.data!.data() as Map<String, dynamic>;
        String username = userData['username'];
        String profileImage = userData['profileImage'] ?? '';
        final postImageBytes = postImageUrl != null && postImageUrl!.isNotEmpty
            ? base64Decode(postImageUrl!)
            : null;

        return FutureBuilder<double>( // build UI based on the result of a Future
          future: postType == 'donation' ? _fetchCollectedAmount() : Future.value(0.0), // Future.value(0.0) = creates a Future that immediately resolves with the value 0.0, meaning no donations are collected (since it's not a donation post)
          builder: (context, amountSnapshot) {
            final collectedAmount = amountSnapshot.data ?? 0.0;

            return Card(
              margin: const EdgeInsets.all(8.0),
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User header
                    Row(
                      children: [
                        // profile image
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ViewProfilePage(userId: userId),
                              ),
                            );
                          },
                          child: profileImage.isNotEmpty
                              ? CircleAvatar(
                            backgroundImage: MemoryImage(base64Decode(profileImage)),
                            radius: 24,
                          )
                              : CircleAvatar(
                            radius: 24,
                            child: Icon(Icons.person),
                          ),
                        ),

                        const SizedBox(width: 8.0),

                        // username and post timestamp
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ViewProfilePage(userId: userId),
                                  ),
                                );
                              },
                              // username
                              child: Text(
                                username,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16.0,
                                ),
                              ),
                            ),
                            // post timestamp
                            Text(
                              '${isEdited ? 'Edited' : 'Posted'} on: ${DateTime.fromMillisecondsSinceEpoch(timestamp.millisecondsSinceEpoch).toLocal().toString().substring(0, 16)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 10.0),

                    // Caption
                    if (caption != null && caption!.isNotEmpty)
                      Text(caption!, style: const TextStyle(fontSize: 14.0)),

                    // Address
                    if (address != null && address!.isNotEmpty)  // Check if address is not null and not empty
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: GestureDetector(
                          onTap: () {
                            if (location != null) {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text('Event Location', style: TextStyle(color: kPrimaryColor, fontWeight: FontWeight.bold)),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,  // Use min to fit content
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(address!, style: TextStyle(fontSize: 14)),  // Display the address
                                      SizedBox(height: 16),  // Add some spacing
                                      SizedBox(
                                        height: 300,
                                        width: double.maxFinite,
                                        child: FlutterMap(
                                          options: MapOptions(
                                            initialCenter: latLng,
                                            initialZoom: 13.0,
                                          ),
                                          children: [
                                            TileLayer(
                                              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                                              subdomains: ['a', 'b', 'c'],
                                            ),
                                            MarkerLayer(
                                              markers: [
                                                Marker(
                                                  point: latLng,
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
                                  ),
                                  actions: [
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Close'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: kPrimaryColor, // Sets the background to yellow
                                        foregroundColor: Colors.black,  // Sets the text color to black
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                          },
                          child: Card(
                            elevation: 2,
                            color: Colors.grey[50],
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                children: [
                                  const Icon(Icons.location_on, color: kPrimaryColor),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Event Location: $address',
                                      style: const TextStyle(
                                        fontSize: 13.0,
                                        fontWeight: FontWeight.bold,
                                        color: kPrimaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Post Image
                    if (postImageBytes != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Image.memory(postImageBytes),
                      ),

                    const SizedBox(height: 10),

                    // Donation progress
                    if (postType == 'donation' && totalAmount != null)
                      Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: LinearProgressIndicator(
                              value: (collectedAmount / totalAmount!).clamp(0, 1),
                              backgroundColor: Colors.grey.shade300,
                              valueColor: AlwaysStoppedAnimation<Color>(kPrimaryColor),
                            ),
                          ),

                          const SizedBox(height: 10),

                          RichText(
                            text: TextSpan(
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.black87),
                              children: [
                                const TextSpan(text: 'Raised   '),
                                TextSpan(
                                  text: '\$${collectedAmount.toStringAsFixed(2)}',
                                  style: const TextStyle(color: Colors.green),
                                ),
                                const TextSpan(text: '   of   '),
                                TextSpan(
                                  text: '\$${totalAmount!.toStringAsFixed(2)}',
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                      ),

                    // Button
                    Align(
                      alignment: Alignment.center,
                      child: ElevatedButton(
                        onPressed: (postType == 'donation' &&
                            totalAmount != null &&
                            collectedAmount >= totalAmount!)
                            ? null
                            : () {
                          if (postType == 'volunteer') {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => ChatByPostPage(receiverId: userId,)));
                          } else if (postType == 'donation') {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => DonationByPost(postId: postId)));
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimaryColor, // Sets the background to yellow
                          foregroundColor: Colors.black,  // Sets the text color to black
                        ),
                        child: Text(
                          (postType == 'donation' &&
                              totalAmount != null &&
                              collectedAmount >= totalAmount!)
                              ? 'Donation Complete'
                              : (postType == 'volunteer' ? 'Contact Us!' : 'Donate Now!'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}