import 'custom_appbar_drawer.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'chat_screen.dart';
import 'new_chat_screen.dart';
import 'custom_appbar_drawer.dart';

class MainChatScreen extends StatefulWidget {
  @override
  _MainChatScreenState createState() => _MainChatScreenState();
}

class _MainChatScreenState extends State<MainChatScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  //=========================================================================================
  @override
  Widget build(BuildContext context) {
    User? currentUser = _auth.currentUser;
    if (currentUser == null) {
      return Scaffold(body: Center(child: Text("Please log in to view chats")));
    }

    return Scaffold(
      appBar: CustomAppBarDrawer(
        title: 'Chat', activeScreen: 'chat',
      ),
      drawer: CustomAppBarDrawer.buildDrawer(context, activeScreen: 'chat'),

      // get chats details
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('chats')
            .where('participants', arrayContains: currentUser.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

          var chats = snapshot.data!.docs;
          Set<String> uniqueChatUsers = {}; // track unique receiverIds
          List<Widget> chatTiles = [];

          for (var chat in chats) {
            var chatData = chat.data() as Map<String, dynamic>;
            List participants = chatData['participants'];

            String receiverId = participants.firstWhere(
                  (id) => id != currentUser.uid,
              orElse: () => "Unknown",
            );

            // skip duplicate receiver
            if (uniqueChatUsers.contains(receiverId)) continue;
            uniqueChatUsers.add(receiverId);

            // get user and last message
            chatTiles.add(
              ListTile(
                title: FutureBuilder<DocumentSnapshot>(
                  future: _firestore.collection('users').doc(receiverId).get(),
                  builder: (context, userSnapshot) {
                    if (userSnapshot.connectionState == ConnectionState.waiting) {
                      return Text("Loading...");
                    }
                    if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                      return Text("Unknown User");
                    }

                    //display participant name
                    String receiverName = userSnapshot.data!['username'] ?? "Unknown";
                    return Text("Chat with $receiverName");
                  },
                ),

                //show last message
                subtitle: Text(chatData['lastMessage'] ?? "No messages yet"),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      senderId: currentUser.uid,
                      receiverId: receiverId,
                      receiverName: "Fetching...",
                    ),
                  ),
                ),
              ),
            );
          }

          return ListView(children: chatTiles);
        },
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => NewChatScreen()),
          );
        },
        child: Icon(Icons.add),
        backgroundColor: kPrimaryColor,
      ),
    );
  }
}
