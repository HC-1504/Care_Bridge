import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_service.dart';
import 'chat_screen.dart';
import 'home_page.dart';
import 'login_page.dart';
import 'registration_page.dart';
import 'donation_details_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'donation_success_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  final AuthService authService = AuthService();

  @override
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => authService,
      child: FutureBuilder(
        future: authService.loadUser(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const MaterialApp(
              home: Scaffold(body: Center(child: CircularProgressIndicator())),
            );
          }
          return MaterialApp(
            title: 'CareBridge', // Good to have a title
            home: Consumer<AuthService>(
              builder: (context, auth, child) {
                return auth.isLoggedIn ? HomePage() : WelcomeScreen();
              },
            ),
            routes: {
              '/login': (context) => LoginPage(),
              '/home': (context) => HomePage(),
              '/welcome': (context) => WelcomeScreen(),
            },
            onGenerateRoute: (settings) {
              if (settings.name == '/donationDetails') {
                final args = settings.arguments as Map<String, dynamic>?;
                if (args != null) {
                  return MaterialPageRoute(
                    builder: (context) => DonationDetailsScreen(
                      postId: args['postId'] as String? ?? '',
                      campaignCaption: args['campaignCaption'] as String? ?? '',
                    ),
                  );
                }
                return MaterialPageRoute(builder: (_) => Scaffold(body: Center(child: Text('Error: Missing arguments for donationDetails'))));

              } else if (settings.name == '/donationSuccess') {
                final args = settings.arguments as Map<String, dynamic>?;
                return MaterialPageRoute(
                  builder: (context) => const DonationSuccessScreen(),
                  settings: settings,
                );
              }
              else if (settings.name == '/chatScreen') {
                final args = settings.arguments as Map<String, dynamic>?;
                if (args != null &&
                    args.containsKey('chatRoomId') &&
                    args.containsKey('receiverId')) {

                  final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
                  final receiverId = args['receiverId'];
                  final chatRoomId = args['chatRoomId'];

                  final receiverName = args['receiverName'] ?? 'Chat';

                  return MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      senderId: currentUserId,
                      receiverId: receiverId,
                      receiverName: receiverName,
                    ),
                  );
                }

                return MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: Text("Error")),
                    body: Center(child: Text('Missing arguments for ChatScreen')),
                  ),
                );
              }

              // Fallback for any other unhandled routes
              return MaterialPageRoute(
                builder: (_) => Scaffold(
                  appBar: AppBar(title: Text("Page Not Found")),
                  body: Center(child: Text('No route defined for ${settings.name}')),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Spacer(),
            Image.asset(
              'assets/images/CareBridge.png',
              height: 200,
              width: 200,
              fit: BoxFit.contain,
            ),
            Spacer(),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFFBD157),
                minimumSize: Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Login', style: TextStyle(color: Colors.black)),
            ),
            SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => RegistrationPage()),
                );
              },
              style: OutlinedButton.styleFrom(
                minimumSize: Size(double.infinity, 50),
                side: BorderSide(color: Colors.black),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Create account', style: TextStyle(color: Colors.black)),
            ),
            SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
