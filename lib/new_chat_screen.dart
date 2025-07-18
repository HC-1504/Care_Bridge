import 'chat_screen.dart' show ChatScreen;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NewChatScreen extends StatefulWidget {
  @override
  _NewChatScreenState createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Stream<QuerySnapshot>? _usersStream;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    User? user = _auth.currentUser;
    if (user != null) {
      _currentUserId = user.uid;
      print("NewChatScreen initState: Current User ID: $_currentUserId");

      //get user exclude current user
      _usersStream = _firestore
          .collection('users')
          .where(FieldPath.documentId, isNotEqualTo: _currentUserId!)
          .snapshots();

      //manually get users
      _testFetchUsers();
    } else {
      print("NewChatScreen initState: No current user found.");
    }
  }

  // debug function
  Future<void> _testFetchUsers() async {
    if (_currentUserId == null) return;
    print("Firestore Test (_testFetchUsers): Attempting to .get() users excluding $_currentUserId");
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('users')
          .where(FieldPath.documentId, isNotEqualTo: _currentUserId!)
          .get();
      print("Firestore Test (_testFetchUsers): .get() successful. Found ${querySnapshot.docs.length} users.");
      if (querySnapshot.docs.isEmpty) {
        print("Firestore Test (_testFetchUsers): No other users found via .get().");
      }
      for (var doc in querySnapshot.docs) {
        print("Firestore Test (_testFetchUsers): User: ${doc.id}, Data: ${doc.data()}");
      }
    } catch (e, s) {
      print("Firestore Test (_testFetchUsers): ERROR during .get() users: $e");
      print("Firestore Test (_testFetchUsers): STACK TRACE: $s");
    }
  }

  // navigate to selected user chat
  void _startChat(BuildContext context, String userId, String username) async {
    print("_startChat called for userId: $userId, username: $username"); // debug
    String currentAuthUserId = _auth.currentUser!.uid;
    String chatRoomId = getChatRoomId(currentAuthUserId, userId);
    DocumentReference chatRef = _firestore.collection('chats').doc(chatRoomId);

    try {
      //debug firestore rules
      print("Firestore (_startChat): currentAuthUserId for rule check: $currentAuthUserId");
      print("Firestore (_startChat): Target chatId for rule check: $chatRoomId");
      List<String> chatRoomIdParts = chatRoomId.split('_');
      if (chatRoomIdParts.length == 2) {
        print("Firestore (_startChat): chatId part 0: ${chatRoomIdParts[0]}");
        print("Firestore (_startChat): chatId part 1: ${chatRoomIdParts[1]}");
        print("Firestore (_startChat): Rule condition check: (part0 == currentAuthUserId) OR (part1 == currentAuthUserId)");
        print("Firestore (_startChat): Part 0 ('${chatRoomIdParts[0]}') == CurrentUID ('$currentAuthUserId') -> ${chatRoomIdParts[0] == currentAuthUserId}");
        print("Firestore (_startChat): Part 1 ('${chatRoomIdParts[1]}') == CurrentUID ('$currentAuthUserId') -> ${chatRoomIdParts[1] == currentAuthUserId}");
      } else {
        print("Firestore (_startChat): WARNING - chatRoomId did not split into 2 parts: $chatRoomId");
      }
      print("Firestore (_startChat): Attempting to get chat document: ${chatRef.path}");
      DocumentSnapshot chatSnapshot = await chatRef.get();
      print("Firestore (_startChat): Chat document .get() successful. Exists: ${chatSnapshot.exists}");

      // create chat if dont exists
      if (!chatSnapshot.exists) {
        print("Firestore (_startChat): Chat document does not exist. Attempting to create...");
        await chatRef.set({
          'participants': [currentAuthUserId, userId],
          'lastMessage': '',
          'timestamp': FieldValue.serverTimestamp(),
          'admin': currentAuthUserId,
        });
        print("Firestore (_startChat): Chat document created successfully: ${chatRef.path}");
      }

      //navigate to chat screen
      print("Navigation (_startChat): Attempting to navigate to ChatScreen...");
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            senderId: currentAuthUserId,
            receiverId: userId,
            receiverName: username,
          ),
        ),
      );
      print("Navigation (_startChat): Navigation to ChatScreen initiated.");

    } catch (e, s) {
      print("ERROR in _startChat: $e");
      print("STACK TRACE (_startChat): $s");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error starting chat: ${e.toString()}")),
        );
      }
    }
  }

  // get unique chatRoomId
  String getChatRoomId(String user1, String user2) {
    return user1.hashCode <= user2.hashCode ? "$user1\_$user2" : "$user2\_$user1";
  }

  //=========================================================================================
  @override
  Widget build(BuildContext context) {

    if (_currentUserId == null || _usersStream == null) {
      return Scaffold(
        appBar: AppBar(title: Text("Select a user")),
        body: Center(
          child: _auth.currentUser == null
              ? Text("User not logged in. Please restart.") // If user somehow logged out
              : CircularProgressIndicator(), // If currentUser was found but stream isn't ready
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text("Select a user")),
      body: StreamBuilder<QuerySnapshot>(
        stream: _usersStream, // Use the stream initialized in initState
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            print("StreamBuilder: Waiting for user data...");
            return Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print("StreamBuilder error loading users: ${snapshot.error}");
            print("StreamBuilder error STACKTRACE: ${snapshot.stackTrace}");
            return Center(child: Text("Error loading users: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            print("StreamBuilder: No user data found or data is empty.");
            return Center(child: Text("No other users found."));
          }

          print("StreamBuilder: User data received. Number of users: ${snapshot.data!.docs.length}");

          // display user as list
          return ListView(
            children: snapshot.data!.docs.map((doc) {
              var userData = doc.data() as Map<String, dynamic>;
              String userId = doc.id;
              String username = userData['username'] ?? "Unknown User";

              return ListTile(
                title: Text(username),
                onTap: () => _startChat(context, userId, username),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}