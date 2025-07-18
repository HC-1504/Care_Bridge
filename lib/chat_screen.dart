import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'custom_appbar_drawer.dart';

class ChatScreen extends StatefulWidget {
  final String senderId;
  final String receiverId;
  final String receiverName;

  ChatScreen({
    required this.senderId,
    required this.receiverId,
    required this.receiverName,
  });

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TextEditingController _messageController = TextEditingController();
  String? receiverName;

  @override
  void initState() {
    super.initState();
    receiverName = widget.receiverName;
    _fetchReceiverName();
  }

  void _fetchReceiverName() async {
    try {
      DocumentSnapshot userDoc =
      await _firestore.collection('users').doc(widget.receiverId).get();
      if (userDoc.exists) {
        setState(() {
          receiverName = userDoc.get('username') ?? "Unknown User";
        });
      }
    } catch (e) {
      debugPrint("Error fetching username: $e");
    }
  }

  void sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    String chatRoomId = getChatRoomId(widget.senderId, widget.receiverId);
    String messageText = _messageController.text.trim();

    await _firestore.collection('chats').doc(chatRoomId).collection('messages').add({
      'senderId': widget.senderId,
      'receiverId': widget.receiverId,
      'text': messageText,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await _firestore.collection('chats').doc(chatRoomId).set({
      'lastMessage': messageText,
      'timestamp': FieldValue.serverTimestamp(),
      'participants': [widget.senderId, widget.receiverId],
    }, SetOptions(merge: true));

    await _firestore.collection('notification').add({
      'type': 'chat_message',
      'fromUserId': widget.senderId,
      'toUserId': widget.receiverId,
      'message': messageText,
      'timestamp': FieldValue.serverTimestamp(),
      'chatRoomId': chatRoomId,
      'isRead': false,
    });

    _messageController.clear();
  }

  String getChatRoomId(String user1, String user2) {
    return user1.hashCode <= user2.hashCode ? "$user1\_$user2" : "$user2\_$user1";
  }

  //=========================================================================================

  @override
  Widget build(BuildContext context) {
    final String chatRoomId = getChatRoomId(widget.senderId, widget.receiverId);
    final yellow = kPrimaryColor;

    return Scaffold(
      appBar: AppBar(
        title: Text(receiverName ?? "Loading..."),
        backgroundColor: kPrimaryColor,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('chats')
                  .doc(chatRoomId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

                var messages = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    var message = messages[index].data() as Map<String, dynamic>;
                    bool isMe = message['senderId'] == widget.senderId;

                    return Align(
                      alignment:
                      isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isMe ? kPrimaryColor : Colors.yellow.shade600,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(12),
                            topRight: Radius.circular(12),
                            bottomLeft:
                            isMe ? Radius.circular(12) : Radius.circular(0),
                            bottomRight:
                            isMe ? Radius.circular(0) : Radius.circular(12),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            )
                          ],
                        ),
                        child: Text(
                          message['text'],
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 2,
                )
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: "Type a message...",
                      fillColor: Colors.white,
                      filled: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: kPrimaryColor,
                  child: IconButton(
                    icon: Icon(Icons.send, color: Colors.black),
                    onPressed: sendMessage,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
