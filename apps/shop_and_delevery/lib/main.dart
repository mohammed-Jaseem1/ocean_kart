import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/auth/login_screen.dart';
import 'screens/shop_keeper/dashboard_screen.dart';
import 'screens/delevery_partner/delivery_partner_dashboard.dart';
import 'screens/common/location_setup_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await dotenv.load(fileName: ".env");
  } catch (e) {
    debugPrint("DotEnv load notice: $e");
  }

  if (kIsWeb) {
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
  } else {
    await Firebase.initializeApp();
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF00B4D8);

    return MaterialApp(
      title: 'OceanKart Delivery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        primaryColor: primaryBlue,
        colorScheme: const ColorScheme.light(
          primary: primaryBlue,
          surface: Colors.white,
          onPrimary: Colors.white,
          onSurface: Color(0xFF0F172A),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xFF0F172A)),
          titleTextStyle: TextStyle(
            color: Color(0xFF0F172A),
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Only show loading on initial cold launch if waiting and no cached data
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00B4D8)),
              ),
            ),
          );
        }

        // If the user has active session, listen to user document in Firestore
        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .snapshots(),
            builder: (context, userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting && !userSnapshot.hasData) {
                return const Scaffold(
                  backgroundColor: Colors.white,
                  body: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00B4D8)),
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
                  backgroundColor: Colors.white,
                  body: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00B4D8)),
                    ),
                  ),
                );
              }

              if (userSnapshot.hasData && userSnapshot.data != null && userSnapshot.data!.exists) {
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
                    backgroundColor: Colors.white,
                    body: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00B4D8)),
                      ),
                    ),
                  );
                }

                if (userData?['status'] == 'suspended') {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    FirebaseAuth.instance.signOut();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Your account has been suspended. Please contact admin.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  });
                  return const Scaffold(
                    backgroundColor: Colors.white,
                    body: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00B4D8)),
                      ),
                    ),
                  );
                }

                final role = userData?['role'];

                // Route directly to role-specific dashboard
                if (role == 'Delivery Boy' || role == 'delivery_partner') {
                  return const DeliveryPartnerDashboard();
                } else if (role == 'Shopkeeper') {
                  final isPinned = (userData?['locationPinned'] == true || userData?['isLocationPinned'] == true) &&
                      userData?['latitude'] != null &&
                      userData?['longitude'] != null;

                  if (!isPinned) {
                    return const LocationSetupScreen(role: 'Shopkeeper', isInitialSetup: true);
                  }
                  return const DashboardScreen();
                } else {
                  // If it's a customer or unknown role, deny access
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
                    backgroundColor: Colors.white,
                    body: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00B4D8)),
                      ),
                    ),
                  );
                }
              }

              // Fallback to loading while document is syncing or being read
              return const Scaffold(
                backgroundColor: Colors.white,
                body: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00B4D8)),
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
