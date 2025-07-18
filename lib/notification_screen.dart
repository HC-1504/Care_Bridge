import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'custom_appbar_drawer.dart';

class NotificationPage extends StatefulWidget {
  @override
  _NotificationPageState createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // navigate to chat screen
  void handleNotificationTap(BuildContext context, Map<String, dynamic> notification) {
    if (notification['type'] == 'chat_message' &&
        notification['chatRoomId'] != null &&
        notification['fromUserId'] != null) {
      Navigator.pushNamed(
        context,
        '/chatScreen',
        arguments: {
          'chatRoomId': notification['chatRoomId'],
          'receiverId': notification['fromUserId'],
        },
      );
    } else {
      print("Invalid or missing data in notification.");
    }
  }

  String formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return "Unknown time";
    DateTime dateTime = timestamp.toDate();
    return DateFormat('MMM d, h:mm a').format(dateTime);
  }


  // get sender username
  Future<String> fetchUsername(String userId) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return userDoc['username'] ?? "Unknown User";
      }
    } catch (e) {
      print("Error fetching username: $e");
    }
    return "Unknown User";
  }

  //=========================================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBarDrawer(title: 'Notification', activeScreen: 'notification'),
      drawer: CustomAppBarDrawer.buildDrawer(context, activeScreen: 'notification'),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('notification')
            .where('toUserId', isEqualTo: _auth.currentUser!.uid)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var notifications = snapshot.data!.docs;
          if (notifications.isEmpty) {
            return const Center(child: Text("No notifications yet"));
          }

          // display list of notification
          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              //convert each notification document to map
              var notification = notifications[index].data() as Map<String, dynamic>;
              bool isRead = notification['isRead'] ?? false;
              Timestamp? timestamp = notification['timestamp'];
              String formattedTime = formatTimestamp(timestamp);

              // get sender username for each notification
              return FutureBuilder<String>(
                future: fetchUsername(notification['fromUserId']),
                builder: (context, snapshot) {
                  String senderName = snapshot.data ?? "Unknown User";

                  return GestureDetector(
                    onTap: () async {
                      try {
                        handleNotificationTap(context, notification);
                        await _firestore
                            .collection('notification')
                            .doc(notifications[index].id)
                            .update({'isRead': true});
                        print("Notification marked as read.");
                      } catch (e) {
                        print("Failed to update notification: $e");
                      }
                    },
                    child: Container(
                      color: isRead ? Colors.white : Colors.grey.shade300,
                      child: ListTile(
                        title: Text(
                          "$senderName sent a message",
                          style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(notification['message'] ?? ''),
                            Text(
                              formattedTime,
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
