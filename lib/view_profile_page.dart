import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'post_detail.dart';
import 'user_model.dart';
import 'chat_by_post_screen.dart';
import 'custom_appbar_drawer.dart';

class ViewProfilePage extends StatefulWidget {
  final String userId;

  const ViewProfilePage({Key? key, required this.userId}) : super(key: key);

  @override
  _ViewProfilePageState createState() => _ViewProfilePageState();
}

class _ViewProfilePageState extends State<ViewProfilePage> with SingleTickerProviderStateMixin {
  late Future<UserModel?> _userFuture;
  int _postCount = 0;
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;
  late TabController _tabController;
  String? _message;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _userFuture = _fetchUserData();
    _loadUserPosts();
    _tabController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _navigateToPostDetail(Map<String, dynamic> post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailPage(postId: post['id']),
      ),
    );
  }

  Future<UserModel?> _fetchUserData() async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data()!;
        return UserModel(
          userID: widget.userId,
          email: data['email'] ?? '',
          username: data['username'] ?? 'Unknown',
          profileImage: data['profileImage'] != null
              ? base64Decode(data['profileImage'])
              : null,
          bio: data['bio'] ?? '',
        );
      }
      return null;
    } catch (e) {
      print('Error fetching user data: $e');
      return null;
    }
  }

  Future<void> _loadUserPosts() async {
    try {
      final postsQuery = await FirebaseFirestore.instance
          .collection('posts')
          .where('userID', isEqualTo: widget.userId)
          .get();

      setState(() {
        _postCount = postsQuery.size;
        _posts = postsQuery.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList();
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading posts: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatByPostPage(receiverId: widget.userId),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final isCurrentUser = currentUserId == widget.userId;

    return Scaffold(
      appBar: AppBar(
        title: Text('User Profile'),
        backgroundColor: kPrimaryColor,
      ),
      body: FutureBuilder<UserModel?>(
        future: _userFuture,
        builder: (context, snapshot) {
          if (_isLoading) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return Center(child: Text('User not found'));
          }

          final user = snapshot.data!;

          return SingleChildScrollView(
            child: Column(
              children: [

                Container(
                  color: Color(0xFFFBD157),
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundImage: user.profileImage != null
                            ? MemoryImage(user.profileImage!)
                            : AssetImage('assets/images/default.png') as ImageProvider,
                        child: user.profileImage == null
                            ? Icon(Icons.person, size: 40)
                            : null,
                      ),
                      SizedBox(height: 10),
                      Text(
                        user.username,
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildStatColumn(_postCount.toString(), "Posts"),
                        ],
                      ),
                      SizedBox(height: 10),
                      if (user.bio.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            user.bio,
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      SizedBox(height: 10),
                      if (!isCurrentUser)
                        _buildProfileButton("Message", _navigateToChat),
                    ],
                  ),
                ),


                Container(
                  color: Colors.white,
                  child: Column(
                    children: [
                      if (_message != null)
                        Container(
                          width: double.infinity,
                          color: Colors.amber,
                          padding: const EdgeInsets.all(8.0),
                          child: Center(
                            child: Text(
                              _message!,
                              style: const TextStyle(color: Colors.black, fontSize: 16),
                            ),
                          ),
                        ),
                      TabBar(
                        controller: _tabController,
                        tabs: const [
                          Tab(text: 'Volunteer'),
                          Tab(text: 'Donation'),
                        ],
                      ),
                      _buildPostsContent(),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildPostsContent() {
    if (_postCount == 0) {
      return _buildEmptyPostView();
    }

    final selectedType = _tabController.index == 0 ? 'volunteer' : 'donation';
    final filteredPosts = _posts.where((post) => post['post_type'] == selectedType).toList();

    if (filteredPosts.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 50),
        child: Center(
          child: Text(
            'No ${selectedType} posts yet',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      itemCount: filteredPosts.length,
      itemBuilder: (context, index) {
        final post = filteredPosts[index];
        final hasImage = post['post_image_url'] != null && post['post_image_url'].isNotEmpty;
        final hasText = post['caption'] != null && post['caption'].isNotEmpty;

        return GestureDetector(
          onTap: () => _navigateToPostDetail(post),
          child: Container(
            margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasText)
                  Padding(
                    padding: EdgeInsets.only(bottom: hasImage ? 8 : 0),
                    child: Text(
                      post['caption'],
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                if (hasImage)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      base64Decode(post['post_image_url']),
                      fit: BoxFit.cover,
                      height: 200,
                      width: double.infinity,
                    ),
                  ),
                SizedBox(height: 8),
                Text(
                  _formatDate(post['timestamp']),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyPostView() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 50),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library, size: 60, color: Colors.grey),
          SizedBox(height: 10),
          Text(
            "No posts yet",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String count, String label) {
    return Column(
      children: [
        Text(count, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        Text(label),
      ],
    );
  }

  Widget _buildProfileButton(String text, VoidCallback onPressed) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 40, vertical: 5),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          minimumSize: Size(double.infinity, 40),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          side: BorderSide(color: Colors.black),
        ),
        child: Text(text),
      ),
    );
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}