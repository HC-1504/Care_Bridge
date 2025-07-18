import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'chat_screen.dart';

class ChatByPostPage extends StatelessWidget {
  final String receiverId;

  ChatByPostPage({required this.receiverId});

  //=========================================================================================

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Chat")),
        body: const Center(child: Text("You must be logged in to chat.")),
      );
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(receiverId).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(
            body: Center(child: Text("User not found.")),
          );
        }

        final receiverData = snapshot.data!.data() as Map<String, dynamic>;
        final receiverName = receiverData['username'] ?? 'Unknown';

        // Push to ChatScreen with sender and receiver info
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => ChatScreen(
                senderId: currentUser.uid,
                receiverId: receiverId,
                receiverName: receiverName,
              ),
            ),
          );
        });

        return const Scaffold(
          body: Center(child: CircularProgressIndicator()), // Just a short placeholder while navigating
        );
      },
    );
  }
}
