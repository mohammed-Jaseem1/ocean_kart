import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens/auth/login_screen.dart';
import 'screens/shop_keeper/dashboard_screen.dart';
import 'screens/delevery_partner/delivery_partner_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase using the provided web configuration
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: "AIzaSyAXQCoKtyg22kE-00mzzaf8znQ8SrIYtJ0",
      authDomain: "oceankart-83bbd.firebaseapp.com",
      projectId: "oceankart-83bbd",
      storageBucket: "oceankart-83bbd.firebasestorage.app",
      messagingSenderId: "234759726531",
      appId: "1:234759726531:web:9e94c9af87234da3a48976",
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF00B4D8);
    const darkBackground = Color(0xFF0A1628);

    return MaterialApp(
      title: 'OceanKart Delivery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: darkBackground,
        primaryColor: primaryBlue,
        colorScheme: const ColorScheme.dark(
          primary: primaryBlue,
          surface: darkBackground,
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // If the connection is waiting, show loading spinner
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00B4D8)),
              ),
            ),
          );
        }

        // If the user has active session, show the correct Dashboard based on role
        if (snapshot.hasData) {
          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(snapshot.data!.uid)
                .get(const GetOptions(source: Source.server)),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  backgroundColor: Color(0xFF0A1628),
                  body: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF00B4D8),
                      ),
                    ),
                  ),
                );
              }

              if (userSnapshot.hasError) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  FirebaseAuth.instance.signOut();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Your request was rejected.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                });
                return const Scaffold(
                  backgroundColor: Color(0xFF0A1628),
                  body: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00B4D8)))),
                );
              }

              if (userSnapshot.hasData) {
                if (!userSnapshot.data!.exists) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    FirebaseAuth.instance.signOut();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Your request was rejected.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  });
                  return const Scaffold(
                    backgroundColor: Color(0xFF0A1628),
                    body: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00B4D8)))),
                  );
                }

                final userData = userSnapshot.data!.data() as Map<String, dynamic>?;

                if (userData?['status'] == 'pending') {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    FirebaseAuth.instance.signOut();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Your account is pending admin approval.'),
                        backgroundColor: Colors.orange,
                      ),
                    );
                  });
                  return const Scaffold(
                    backgroundColor: Color(0xFF0A1628),
                    body: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00B4D8)))),
                  );
                }

                final role = userData?['role'];

                if (role == 'Delivery Boy') {
                  return const DeliveryPartnerDashboard();
                } else if (role == 'Shopkeeper') {
                  return const DashboardScreen();
                } else {
                  // If it's a 'customer' or unknown role, deny access
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    FirebaseAuth.instance.signOut();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Access Denied. Only Shopkeepers and Delivery Boys can log into this app.',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  });
                  return const Scaffold(
                    backgroundColor: Color(0xFF0A1628),
                    body: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF00B4D8),
                        ),
                      ),
                    ),
                  );
                }
              }

              // Fallback to loading while document doesn't exist
              return const Scaffold(
                backgroundColor: Color(0xFF0A1628),
                body: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF00B4D8),
                    ),
                  ),
                ),
              );
            },
          );
        }

        // Otherwise, show LoginScreen
        return const LoginScreen();
      },
    );
  }
}
