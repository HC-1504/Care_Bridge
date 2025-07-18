import 'package:cloud_firestore/cloud_firestore.dart' show FirebaseFirestore, QuerySnapshot;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'post_display.dart';
import 'profile_page.dart';
import 'home_page.dart';
import 'main_chat_screen.dart';
import 'donation_screen.dart';
import 'notification_screen.dart';


const Color kPrimaryColor = Color(0xFFFBD157);

class CustomAppBarDrawer extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final Widget? actions;
  final Function()? onActionPressed;
  final bool showTabs;
  final TabController? tabController;
  final String activeScreen; // To track which screen is active

  const CustomAppBarDrawer({
    super.key,
    required this.title,
    this.actions,
    this.onActionPressed,
    this.tabController,
    this.showTabs = false,
    required this.activeScreen, // Required parameter for active screen
  });

  @override
  final Size preferredSize = const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Color(0xFFFBD157),
      leading: Builder(
        builder: (BuildContext context) {
          return IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          );
        },
      ),
      title: Text(title),
      centerTitle: true,
      actions: [
        if (actions != null) Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: actions!,
        ),
      ],
      bottom: showTabs
          ? TabBar(
        controller: tabController,
        tabs: const [
          Tab(text: 'Volunteer'),
          Tab(text: 'Donation'),
        ],
      )
          : null,
    );
  }

  // Static method to create the drawer that can be used across pages
  static Widget buildDrawer(BuildContext context, {required String activeScreen}) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = authService.currentUser;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: <Widget>[

          UserAccountsDrawerHeader(

            accountName: Text(user?.username ?? 'User'),
            accountEmail: Text(user?.email ?? ''),
            currentAccountPicture: CircleAvatar(
              backgroundImage: user?.imageProvider,
              child: user?.profileImage == null
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
            ),
            decoration: const BoxDecoration(color: kPrimaryColor),
          ),
          ListTile(
            leading: const Icon(Icons.arrow_back),
            title: const Text('Back'),
            onTap: () {
              Navigator.of(context).pop();
            },
          ),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Home'),
            selected: activeScreen == 'home',
            selectedTileColor: kPrimaryColor.withAlpha(100),
            onTap: () {
              if (activeScreen != 'home') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => HomePage()),
                );
              } else {
                Navigator.pop(context);
              }
            },
          ),

          ListTile(
            leading: const Icon(Icons.search),
            title: const Text('Post'),
            selected: activeScreen == 'post_display',
            selectedTileColor: kPrimaryColor.withAlpha(100),
            onTap: () {
              if (activeScreen != 'post_display') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) =>  PostScreen()),
                );
              } else {
                Navigator.pop(context);
              }
            },
          ),

          ListTile(
            leading: const Icon(Icons.chat_bubble_outline),
            title: const Text('Chat'),
            selected: activeScreen == 'chat', // Pass this from your page
            selectedTileColor: kPrimaryColor.withAlpha(100),
            onTap: () {
              if (activeScreen != 'chat') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => MainChatScreen()), // Replace with your target screen
                );
              } else {
                Navigator.pop(context); // Close drawer if already on this page
              }
            },
          ),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notification')
                .where('toUserId', isEqualTo: user?.userID)
                .where('isRead', isEqualTo: false)
                .snapshots(),
            builder: (context, snapshot) {
              int unreadCount = snapshot.hasData ? snapshot.data!.docs.length : 0;

              return ListTile(
                leading: const Icon(Icons.notifications_none_outlined),
                title: Row(
                  children: [
                    const Text('Notification'),
                    if (unreadCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          unreadCount.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ]
                  ],
                ),
                selected: activeScreen == 'notification',
                selectedTileColor: kPrimaryColor.withAlpha(100),
                onTap: () {
                  if (activeScreen != 'notification') {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => NotificationPage()),
                    );
                  } else {
                    Navigator.pop(context);
                  }
                },
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.volunteer_activism_outlined),
            title: const Text('Donation'),
            selected: activeScreen == 'donation', // Pass this from your page
            selectedTileColor: kPrimaryColor.withAlpha(100),
            onTap: () {
              if (activeScreen != 'donation') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => DonationPage()), // Replace with your target screen
                );
              } else {
                Navigator.pop(context); // Close drawer if already on this page
              }
            },
          ),

          ListTile(
            leading: const Icon(Icons.account_circle),
            title: const Text('Profile'),
            selected: activeScreen == 'profile',
            selectedTileColor: kPrimaryColor.withAlpha(100),
            onTap: () {
              if (activeScreen != 'profile') {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => ProfilePage()),
                );
              } else {
                Navigator.pop(context);
              }
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () async {
              await authService.clearUser();
              Navigator.pushNamedAndRemoveUntil(
                context,
                '/welcome',
                    (route) => false,
              );
            },
          ),
        ],
      ),
    );
  }
}