import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'screens/auth/login_screen.dart';
import 'screens/dashboard_screen.dart';
import 'services/otp_service.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  await dotenv.load(fileName: ".env");
  OtpService.initialize();

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
    const lightBackground = Color(0xFFF8FAFC);

    return MaterialApp(
      title: 'OceanKart Shop',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: lightBackground,
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
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
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
  bool _retrying = false;

  void _retry() {
    setState(() {
      _retrying = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _retrying = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_retrying) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00B4D8)),
          ),
        ),
      );
    }

    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Only show loading on very first load (no data yet)
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF00B4D8)),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorScreen(
            context,
            'Authentication error. Please check your connection.',
          );
        }

        if (snapshot.hasData) {
          final user = snapshot.data!;

          if (!user.emailVerified) {
            return const LoginScreen();
          }

          return StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .snapshots(),
            builder: (context, docSnapshot) {
              // Only show loading on very first load (no data yet)
              if (docSnapshot.connectionState == ConnectionState.waiting &&
                  !docSnapshot.hasData) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF00B4D8),
                      ),
                    ),
                  ),
                );
              }

              if (docSnapshot.hasError) {
                return _buildErrorScreen(
                  context,
                  'Failed to load your profile. Please try again.',
                );
              }

              if (docSnapshot.hasData && docSnapshot.data!.exists) {
                final data = docSnapshot.data!.data() as Map<String, dynamic>?;
                if (data != null && data['role'] != 'customer') {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    FirebaseAuth.instance.signOut();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Access Denied. Only customers can log into this app.',
                        ),
                        backgroundColor: Colors.red,
                      ),
                    );
                  });
                  return const Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF00B4D8),
                        ),
                      ),
                    ),
                  );
                } else {
                  return const DashboardScreen();
                }
              }

              return const Scaffold(
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

        return const LoginScreen();
      },
    );
  }

  Widget _buildErrorScreen(BuildContext context, String message) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.redAccent,
                size: 56,
              ),
              const SizedBox(height: 20),
              Text(
                'Something went wrong',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _retry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00B4D8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Retry',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                },
                child: const Text(
                  'Sign Out',
                  style: TextStyle(
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
