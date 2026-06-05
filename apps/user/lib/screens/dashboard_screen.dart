import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: Stack(
        children: [
          const SizedBox.expand(
            child: Image(
              image: AssetImage('assets/dashboard_image.png'),
              fit: BoxFit.contain,
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: SafeArea(
              child: FloatingActionButton.extended(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                },
                backgroundColor: const Color(0xFF132238),
                foregroundColor: Colors.redAccent,
                icon: const Icon(Icons.logout),
                label: const Text(
                  'Log Out',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
