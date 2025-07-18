import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'article.dart';
import 'auth_service.dart';
import 'custom_appbar_drawer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';

// =====================================================================================================================
class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

// =====================================================================================================================
class _HomePageState extends State<HomePage> {
  UserModel? _currentUser;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final authService = Provider.of<AuthService>(context, listen: false);
    _currentUser = authService.currentUser;
    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBarDrawer(
          title: 'Home',
          activeScreen: 'home'
      ),
      drawer: CustomAppBarDrawer.buildDrawer(context, activeScreen: 'home'),

      body: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: StreamBuilder(
          stream: FirebaseFirestore.instance.collection('articles').snapshots(),
          builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return const Center(child: Text('Something went wrong'));
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('No articles available.'));
            }

            // else, Get the list of documents as articles
            var articles = snapshot.data!.docs;

            return ListView.builder(
              itemCount: articles.length + 1,  // total items = 1 header + articles.length articles
              itemBuilder: (context, index) {
                // display header as 1st item
                if (index == 0) {
                  return const Padding(
                    padding: EdgeInsets.all(10.0),
                    child: Text(
                      'Articles & Awareness',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  );
                }

                // Looping through articles starting from index 1
                // index 1 = article[0]; Casts it to a Map<String, dynamic> to access fields like article['title']
                var article = articles[index - 1].data() as Map<String, dynamic>;

                // display each article as card
                return ArticleCard(
                  title: article['title'],
                  description: article['description'],
                  imageUrl: article['image_url'],
                  articleId: articles[index - 1].id,  // .id = document ID
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// =====================================================================================================================
class ArticleCard extends StatelessWidget {
  final String title;
  final String description;
  final String imageUrl;
  final String articleId;

  const ArticleCard({
    super.key,
    required this.title,
    required this.description,
    required this.imageUrl,
    required this.articleId,
  });

  @override
  Widget build(BuildContext context) {

    // if the imageUrl field is not empty, decode it; if imageUrl is empty, imageBytes will just be null
    var imageBytes = imageUrl.isNotEmpty ? base64Decode(imageUrl) : null;

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // if there is image, display image
            if (imageBytes != null && imageBytes.isNotEmpty)
              Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Hero(
                    tag: 'article-image-$articleId',
                    child: ClipRRect(
                      child: Image.memory(
                        imageBytes,
                        fit: BoxFit.cover,
                        width: double.infinity,
                      ),
                    ),
                  )
              ),
            SizedBox(height: 10.0),

            // display title
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),

            // display description
            Text(
              description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),

            // display Read More button
            Align(
              alignment: Alignment.center,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ArticleScreen(
                          articleId: articleId,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimaryColor,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text("Read More"),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}