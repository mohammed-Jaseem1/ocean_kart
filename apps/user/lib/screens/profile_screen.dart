import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'edit_profile_screen.dart';
import 'help_support_screen.dart';
import 'terms_policy_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool isTab;
  final VoidCallback? onSwitchToOrders;

  const ProfileScreen({
    super.key,
    this.isTab = false,
    this.onSwitchToOrders,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final Color _textColor = const Color(0xFF0F172A);
  final Color _subtextColor = const Color(0xFF64748B);
  final Color _primaryBlue = const Color(0xFF00B4D8);

  Map<String, dynamic>? userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists && mounted) {
          final data = doc.data();
          setState(() {
            userData = data;
            _isLoading = false;
          });

          // Sync phone number to Firebase Auth if not already attached
          if (user.phoneNumber == null || user.phoneNumber!.isEmpty) {
            final phone = data?['mobileNumber'];
            if (phone != null && phone.toString().trim().isNotEmpty) {
              try {
                final linkFn = FirebaseFunctions.instanceFor(
                        region: 'us-central1')
                    .httpsCallable('linkPhoneNumber');
                await linkFn.call(
                    {'uid': user.uid, 'mobileNumber': phone.toString().trim()});
                await user.reload();
              } catch (linkErr) {
                debugPrint('Profile auto-sync phone warning: $linkErr');
              }
            }
          }
        } else if (mounted) {
          setState(() => _isLoading = false);
        }
      } catch (e) {
        debugPrint("Error fetching user data: $e");
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleLogout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Logout',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        content: const Text(
          'Are you sure you want to logout from OceanKart?',
          style: TextStyle(color: Color(0xFF475569), fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Logout',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }



  @override
  Widget build(BuildContext context) {
    final initial = userData?['name']?.toString().isNotEmpty == true
        ? userData!['name'].toString().substring(0, 1).toUpperCase()
        : 'U';
    final name = userData?['name'] ?? 'User';

    String getPhone() {
      if (userData != null &&
          userData!['mobileNumber'] != null &&
          userData!['mobileNumber'].toString().trim().isNotEmpty) {
        return userData!['mobileNumber'];
      }
      final authPhone = FirebaseAuth.instance.currentUser?.phoneNumber;
      if (authPhone != null && authPhone.trim().isNotEmpty) return authPhone;
      return 'No Phone Number';
    }

    final phone = getPhone();

    String getEmail() {
      if (userData != null &&
          userData!['email'] != null &&
          userData!['email'].toString().trim().isNotEmpty) {
        return userData!['email'].toString().trim();
      }
      final authEmail = FirebaseAuth.instance.currentUser?.email;
      if (authEmail != null && authEmail.trim().isNotEmpty) return authEmail;
      return '';
    }

    final email = getEmail();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        automaticallyImplyLeading: !widget.isTab,
        leading: !widget.isTab
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded,
                    color: Color(0xFF0F172A), size: 20),
                onPressed: () => Navigator.pop(context),
              )
            : null,
        title: const Text(
          'My Profile',
          style: TextStyle(
            color: Color(0xFF0F172A),
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 12),

                  // ── Profile Header on Pure White ───────────────────
                  Center(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _primaryBlue.withValues(alpha: 0.25),
                              width: 2.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _primaryBlue.withValues(alpha: 0.12),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 46,
                            backgroundColor: const Color(0xFFE0F2FE),
                            backgroundImage: userData?['photoUrl'] != null &&
                                    userData!['photoUrl'].toString().isNotEmpty
                                ? NetworkImage(userData!['photoUrl'])
                                : null,
                            child: userData?['photoUrl'] != null &&
                                    userData!['photoUrl'].toString().isNotEmpty
                                ? null
                                : Text(
                                    initial,
                                    style: TextStyle(
                                      fontSize: 38,
                                      fontWeight: FontWeight.w900,
                                      color: _primaryBlue,
                                    ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: _textColor,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.phone_iphone_rounded,
                                  size: 14, color: _subtextColor),
                              const SizedBox(width: 4),
                              Text(
                                phone,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: _subtextColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (email.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.email_outlined,
                                    size: 13, color: _subtextColor),
                                const SizedBox(width: 4),
                                Text(
                                  email,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _subtextColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── Action Tabs / Menu ─────────────────────────────
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Account Settings',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _textColor,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 1. Personal Information Tab
                  _buildProfileTab(
                    icon: Icons.person_rounded,
                    iconBgColor: const Color(0xFF00B4D8).withValues(alpha: 0.12),
                    iconColor: const Color(0xFF00B4D8),
                    title: 'Personal Information',
                    subtitle: 'Name, phone & delivery address',
                    onTap: () async {
                      final updated = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => EditProfileScreen(
                            userData: userData ?? {},
                          ),
                        ),
                      );
                      if (updated == true) {
                        setState(() => _isLoading = true);
                        _fetchUserData();
                      }
                    },
                  ),

                  // 2. Help & Support Tab
                  _buildProfileTab(
                    icon: Icons.headset_mic_rounded,
                    iconBgColor: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                    iconColor: const Color(0xFF8B5CF6),
                    title: 'Help & Support',
                    subtitle: 'FAQs, live chat, support tickets & account deletion',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HelpSupportScreen(),
                        ),
                      );
                    },
                  ),

                  // 3. Terms & Privacy Policy Tab
                  _buildProfileTab(
                    icon: Icons.policy_rounded,
                    iconBgColor: const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                    iconColor: const Color(0xFF0EA5E9),
                    title: 'Terms & Privacy Policy',
                    subtitle: 'Fresh catch standards, COD & privacy policies',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TermsPolicyScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 32),

                  // ── Logout Button ──────────────────────────────────
                  InkWell(
                    onTap: _handleLogout,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFFECACA)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout_rounded,
                              color: Color(0xFFEF4444), size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Logout',
                            style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: widget.isTab ? 95 : 36),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileTab({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: _textColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: _subtextColor,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 15,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
