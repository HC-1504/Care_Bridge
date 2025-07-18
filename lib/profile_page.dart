import 'dart:convert';
import 'post_creation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'auth_service.dart';
import 'custom_appbar_drawer.dart';
import 'edit_profile_page.dart';
import 'post_detail.dart';
import 'settings_page.dart';
import 'user_model.dart';

class ProfilePage extends StatefulWidget {
  @override
  _ProfilePageState createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> with SingleTickerProviderStateMixin {
  UserModel? _user;
  String _bio = '';
  int _postCount = 0;
  List<Map<String, dynamic>> _posts = [];
  bool _isLoading = true;
  late TabController _tabController;
  String? _message;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    final authService = Provider.of<AuthService>(context, listen: false);
    _user = authService.currentUser;
    _bio = _user?.bio ?? '';
    _tabController.addListener(() {
      setState(() {});
    });
    _loadUserPosts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserPosts() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final currentUser = authService.currentUser;

      if (currentUser != null) {
        final userId = currentUser.userID ;

        if (userId == null) {
          print('Error: User ID is null');
          return;
        }

        final postsQuery = await FirebaseFirestore.instance
            .collection('posts')
            .where('userID', isEqualTo: userId)
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
      }
    } catch (e) {
      print('Error loading posts: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _navigateToPostDetail(Map<String, dynamic> post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PostDetailPage(postId: post['id']),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;

    return Scaffold(
      appBar: CustomAppBarDrawer(
        title: _user?.username ?? 'Profile',
        activeScreen: 'profile',
      ),
      drawer: CustomAppBarDrawer.buildDrawer(context, activeScreen: 'profile'),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          children: [
            Container(
              color: Color(0xFFFBD157),
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: _user?.imageProvider,
                    child: _user?.profileImage == null
                        ? Icon(Icons.person, size: 40)
                        : null,
                  ),
                  SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildStatColumn(_postCount.toString(), "Posts"),
                    ],
                  ),
                  SizedBox(height: 10),
                  _buildUserBio(),
                  SizedBox(height: 10),
                  _buildProfileButton("Edit Profile", () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditProfilePage(),
                      ),
                    ).then((result) {
                      if (result == true) {
                        setState(() {
                          _user = authService.currentUser;
                          _bio = _user?.bio ?? '';
                        });
                        _loadUserPosts();
                      }
                    });
                  }),
                  _buildProfileButton("Settings", () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SettingsPage(),
                      ),
                    );
                  }),
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
        final hasImage = post['post_image_url'] != null;
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
            "Share memory",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          SizedBox(height: 10),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => PostCreation()),
              ).then((postCreated) {
                if (postCreated == true) {
                  _loadUserPosts();
                }
              });
            },
            child: Text("Create your first post"),
          )
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

  Widget _buildUserBio() {
    return Column(
      children: [
        Text(
          _bio.isEmpty ? "No bio yet" : _bio,
          style: TextStyle(fontSize: 16),
          textAlign: TextAlign.center,
        ),
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