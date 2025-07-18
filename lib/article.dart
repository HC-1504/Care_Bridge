// address
// Jalan Genting Kelang, Setapak, 53300 Kuala Lumpur, Federal Territory of Kuala Lumpur
// Jalan Segamat / Labis 85000 Segamat, Johor, Malaysia

import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:convert';
import 'post_display.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'custom_appbar_drawer.dart';

// =====================================================================================================================
class ArticleScreen extends StatefulWidget {
  final String articleId;

  const ArticleScreen({
    super.key,
    required this.articleId,
  });

  @override
  ArticleScreenState createState() => ArticleScreenState();
}

// =====================================================================================================================
class ArticleScreenState extends State<ArticleScreen> {
  // var decl
  String title = '';
  String content = '';
  String imageUrl = '';
  bool _isLoading = true;
  final ScrollController _scrollController = ScrollController();
  bool _showAppBarTitle = false;
  Uint8List? _imageBytes;
  final GlobalKey _captureKey = GlobalKey();
  final FlutterTts flutterTts = FlutterTts();


  // methods
  @override
  void initState() {
    super.initState();
    _fetchArticleData();
    _initTts();
    _scrollController.addListener(_handleScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    flutterTts.stop();
    super.dispose();
  }

  void _handleScroll() {
    setState(() {
      _showAppBarTitle = _scrollController.offset > 100;
    });
  }

  String _getSubtitle() {
    if (!_scrollController.hasClients || !_scrollController.position.hasContentDimensions) {
      return "0% read"; // Default state
    }

    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) return "0% read"; // Handle zero-division case

    final double percent = (_scrollController.offset / maxScroll).clamp(0, 1);
    return "${(percent * 100).round()}% read";
  }

  String _stripHtmlTags(String htmlString) {
    final regex = RegExp(r'<[^>]*>|&[^;]+;');
    final textOnly = htmlString.replaceAll(regex, '');
    return textOnly.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  void _initTts() {
    flutterTts.setLanguage("en-US");
    flutterTts.setSpeechRate(0.5);
    flutterTts.setPitch(1.0);
  }

  Future<void> _speak() async {
    if (title.isNotEmpty || content.isNotEmpty) {
      final cleanTitle = _stripHtmlTags(title);
      final cleanContent = _stripHtmlTags(content);
      await flutterTts.speak('$cleanTitle. $cleanContent');
    }
  }

  Future<void> _stop() async {
    await flutterTts.stop();
  }

  Future<void> _fetchArticleData() async {
    try {
      DocumentSnapshot articleSnapshot = await FirebaseFirestore.instance
          .collection('articles')
          .doc(widget.articleId)
          .get();

      if (articleSnapshot.exists) {
        setState(() {
          title = articleSnapshot['title'];
          content = articleSnapshot['content'];
          imageUrl = articleSnapshot['image_url'];
          _isLoading = false;
        });

        if (imageUrl.isNotEmpty) {
          try {
            _imageBytes = base64Decode(imageUrl);
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to load image.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load image.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load image.'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() => _isLoading = false);
    }
  }

  Future<void> _shareImageDirectly() async {
    try {
      // Ensure rendering is complete
      await Future.delayed(const Duration(milliseconds: 50));

      // Capture the widget
      final boundary = _captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2.5); // Slightly lower resolution for faster processing

      // Save as PNG
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/carebridge_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(byteData!.buffer.asUint8List());

      // Share with default white background
      await Share.shareXFiles(
        [XFile(file.path)],
        text: title, // Just the title as caption
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to share image')),
      );
    }
  }

  Color _getTitleColor() {
    if (!_scrollController.hasClients) return Colors.white;
    final double scrollPercentage = (_scrollController.offset / 100).clamp(0, 1);
    return Color.lerp(kPrimaryColor, Colors.white, scrollPercentage)!;
  }

  Widget _buildHeroImage() {
    if (_imageBytes != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Hero(
            tag: 'article-image-${widget.articleId}',
            child: ClipRRect(
              child: Image.memory(
                _imageBytes!,
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withAlpha(80),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ],
      );
    } else if (imageUrl.isNotEmpty) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Hero(
            tag: 'article-image-${widget.articleId}',
            child: ClipRRect(
              child: CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(color: Colors.grey[300]),
                errorWidget: (context, url, error) => Icon(Icons.error),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withAlpha(80),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ],
      );
    } else {
      return Container(color: Colors.grey[300]);
    }
  }

  // UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            floating: false,
            pinned: true,
            backgroundColor: _showAppBarTitle ? kPrimaryColor : Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.parallax,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  AnimatedOpacity(
                    opacity: _showAppBarTitle ? 1.0 : 0.0,
                    duration: Duration(milliseconds: 500),
                    child: Text(
                      '🧾 Article',
                      style: TextStyle(
                          color: _getTitleColor(),
                          shadows: [
                            Shadow(
                              color: Colors.cyanAccent,
                              blurRadius: 20,
                            ),
                          ],
                          fontWeight: FontWeight.bold
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(right: 20.0),
                    child: AnimatedSwitcher(  // Subtitle that changes on scroll
                      duration: Duration(milliseconds: 300),
                      child: Text(
                        _showAppBarTitle ? _getSubtitle() : '',
                        key: ValueKey(_showAppBarTitle),
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
              background: _buildHeroImage(),
            ),
          ),
          SliverToBoxAdapter(
              child: RepaintBoundary(
                key: _captureKey,
                child: Container(
                  color: Colors.white,
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              height: 1.4,
                              letterSpacing: -0.5,
                            ),
                          ),
                          SizedBox(height: 20),
                          Html(
                            data: content,
                            style: {
                              "body": Style(
                                fontSize: FontSize(18.0),
                                lineHeight: LineHeight(1.8),
                                fontFamily: 'Georgia',
                                color: Colors.grey[800],
                              ),
                              "p": Style(
                                margin: Margins.only(bottom: 24),
                              ),
                              "h2": Style(
                                fontSize: FontSize(22.0),
                                fontWeight: FontWeight.bold,
                                margin: Margins.only(top: 32, bottom: 16),
                                color: Colors.black,
                              ),
                              "blockquote": Style(
                                padding: HtmlPaddings.all(16),
                                backgroundColor: Colors.grey[100],
                                border: Border(
                                  left: BorderSide(
                                    color: Colors.blue,
                                    width: 4,
                                  ),
                                ),
                                fontStyle: FontStyle.italic,
                              ),
                            },
                          ),
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(vertical: 16.0, horizontal: 10.0),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Want to Contribute?',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                                SizedBox(height: 10),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => PostScreen(),
                                      ),
                                    );
                                  },
                                  icon: Icon(Icons.volunteer_activism),
                                  label: Text('Join Volunteer Event!'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.pinkAccent[100],
                                    foregroundColor: Colors.black87,
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            PostScreen(initialTabIndex: 1),
                                      ),
                                    );
                                  },
                                  icon: Icon(Icons.attach_money),
                                  label: Text('Make Donation!'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kPrimaryColor,
                                    foregroundColor: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              )
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _scrollController.animateTo(
            0,
            duration: Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        },
        backgroundColor: kPrimaryColor,
        foregroundColor: Colors.black87,
        child: Icon(Icons.arrow_upward),
      ),
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            IconButton(
              icon: Icon(Icons.volume_up),
              onPressed: _speak,
              tooltip: 'Read Aloud',
            ),
            IconButton(
              icon: Icon(Icons.stop),
              onPressed: _stop,
              tooltip: 'Stop Reading',
            ),
            IconButton(
              icon: Icon(Icons.share),
              onPressed: _shareImageDirectly,
            ),
          ],
        ),
      ),
    );
  }
}