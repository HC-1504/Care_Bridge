import 'post_display.dart';
import 'post_edit.dart';
import 'profile_page.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'custom_appbar_drawer.dart';
import 'package:shared_preferences/shared_preferences.dart';

// =====================================================================================================================
class PostDetailPage extends StatefulWidget {
  final String postId;

  const PostDetailPage({super.key, required this.postId});

  @override
  PostDetailPageState createState() => PostDetailPageState();
}

// =====================================================================================================================
class PostDetailPageState extends State<PostDetailPage> {
  // var decl
  Map<String, dynamic>? postData;
  bool _isLoading = true;
  bool isDonationCompleted = false;
  String? currentUserId;

  // methods
  @override
  void initState() {
    super.initState();
    _loadUserDataAndPost();
  }

  Future<void> _loadUserDataAndPost() async {
    final prefs = await SharedPreferences.getInstance();
    currentUserId = prefs.getString('userID');
    await _loadPostData();
  }

  Future<void> _loadPostData() async {
    try {
      final postDoc = await FirebaseFirestore.instance.collection('posts').doc(widget.postId).get();
      if (postDoc.exists) {
        final post = postDoc.data()!;
        double? totalAmount = (post['total_amount'] as num?)?.toDouble();

        // If it's a donation post, check if the donation is complete
        if (post['post_type'] == 'donation' && totalAmount != null) {
          double collectedAmount = 0.0;

          // Fetch all donations for this post
          final donationSnapshot = await FirebaseFirestore.instance
              .collection('donations')
              .where('postID', isEqualTo: widget.postId)
              .get();

          // Sum the amount_received for all donations
          for (var doc in donationSnapshot.docs) {
            collectedAmount += (doc['amount_received'] as num?)?.toDouble() ?? 0.0;
          }

          // Check if the collected amount is greater than or equal to the total amount
          if (collectedAmount >= totalAmount) {
            setState(() {
              isDonationCompleted = true;
            });
          }
        }

        setState(() {
          postData = post;
          _isLoading = false;
        });
      } else {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post not found')),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading post: $e')),
      );
    }
  }

  void _editPost(BuildContext context) async {
    final updatedData = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditPostScreen(postId: widget.postId),
      ),
    );

    if (updatedData != null) {
      setState(() {
        postData = updatedData;
      });
    }
  }

  Future<void> _deletePost() async {
    await FirebaseFirestore.instance.collection('posts').doc(widget.postId).delete();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => ProfilePage()),
    );
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Post deleted')));
  }

  Future<bool> _showDeleteDialog(BuildContext context) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete Post'),
          content: const Text('Are you sure you want to delete this post?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Yes'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  // UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBarDrawer(
          title: 'Post',
          activeScreen: 'post_detail'
      ),
      drawer: CustomAppBarDrawer.buildDrawer(context, activeScreen: 'post_detail'),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : postData == null
          ? const Center(child: Text('Failed to load post data.'))
          : SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 20.0),
        child: Column(
          children: [
            // Pass the postId from widget to PostCard widget
            PostCard(
              postId: widget.postId, // Use widget.postId here for the postId
              userId: postData!['userID'],
              caption: postData!['caption'],
              location: postData!['location'],
              postImageUrl: postData!['post_image_url'],
              postType: postData!['post_type'],
              timestamp: postData!['timestamp'],
              isEdited: postData!['is_edited'],
              address: postData!['address'],
              totalAmount: (postData!['total_amount'] as num?)?.toDouble(),
            ),
            const SizedBox(height: 10),

            if (postData!['userID'] == currentUserId) ...[
              if (isDonationCompleted) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    "This donation post is marked as completed and can no longer be edited.",
                    style: TextStyle(color: Colors.grey[700], fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 10),
              ],
              ElevatedButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('Edit Post'),
                onPressed: isDonationCompleted ? null : () => _editPost(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),

              const SizedBox(height: 10),
              if (postData!['post_type'] != 'donation')
                ElevatedButton.icon(
                  icon: const Icon(Icons.delete),
                  label: const Text('Delete Post'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onPressed: () async {
                    bool confirmDelete = await _showDeleteDialog(context);
                    if (confirmDelete) {
                      await _deletePost();
                    }
                  },
                ),
            ],
          ]
        ),
      ),
    );
  }
}
