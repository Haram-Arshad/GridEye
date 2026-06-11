import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileScreen extends StatelessWidget {
  final String? meterID;
  const ProfileScreen({super.key, this.meterID});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacementNamed(context, '/login');
      });
      return const Scaffold(
        backgroundColor: Color(0xFF0D1B2A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
        ),
      );
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get(),
      builder: (context, snapshot) {

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF0D1B2A),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF00E5FF)),
            ),
          );
        }

        
        final email = FirebaseAuth.instance.currentUser?.email ?? '—';
        String role = 'consumer';
        String adminId = 'ADMIN-001'; // fallback

        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          role    = data['role']    ?? 'consumer';
          adminId = data['adminId'] ?? 'ADMIN-001';
        }

        if (role == 'admin') {
          return _AdminProfileScreen(
            email:   email,
            adminId: adminId,
          );
        } else {
          // consumer ya multi
          return _ConsumerProfileScreen(
            email:    email,
            meterID:  meterID ?? '—',
          );
        }
      },
    );
  }
}

//------------------------------------------------------
// ADMIN PROFILE
// -----------------------------------------------------
class _AdminProfileScreen extends StatelessWidget {
  final String email;
  final String adminId;
  const _AdminProfileScreen({
    required this.email,
    required this.adminId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: _buildAppBar(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 30),

          // Header 
          Center(
            child: Column(
              children: [
                // Avatar
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF00E5FF).withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: const CircleAvatar(
                    radius: 45,
                    backgroundColor: Color(0xFF1B263B),
                    child: Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 45,
                      color: Color(0xFF00E5FF),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Admin ID
                Text(
                  adminId,
                  style: GoogleFonts.orbitron(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),

                // Email
                Text(
                  email,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 10),

                // Role Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E5FF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF00E5FF).withOpacity(0.4),
                    ),
                  ),
                  child: const Text(
                    'UTILITY ADMIN',
                    style: TextStyle(
                      color: Color(0xFF00E5FF),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 35),
          //-----------------
          // Section Label 
          //-----------------
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              "ACCOUNT SETTINGS",
              style: GoogleFonts.orbitron(
                color: Colors.white54,
                fontSize: 12,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Tiles
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                _buildTapTile(
                  context,
                  Icons.notifications_active_outlined,
                  "Notifications",
                  "Alert preferences",
                  onTap: () => _showComingSoon(context, "Notifications"),
                ),
                _buildTapTile(
                  context,
                  Icons.language_rounded,
                  "App Language",
                  "English (Default)",
                  onTap: () => _showLanguageDialog(context),
                ),
                _buildTapTile(
                  context,
                  Icons.info_outline_rounded,
                  "About GridEye",
                  "Version 1.0.0",
                  onTap: () => _showAboutDialog(context),
                ),
              ],
            ),
          ),

          // Logout 
          _buildLogoutButton(context),
        ],
      ),
    );
  }
}

// -------------------------------------------------------
// CONSUMER PROFILE
// -------------------------------------------------------
class _ConsumerProfileScreen extends StatelessWidget {
  final String email;
  final String meterID;
  const _ConsumerProfileScreen({
    required this.email,
    required this.meterID,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: _buildAppBar(context),
      body: FutureBuilder<DocumentSnapshot>(
        // meters collection se area + city fetch karo
        future: meterID == '—'
            ? null
            : FirebaseFirestore.instance
                .collection('meters')
                .doc(meterID)
                .get(),
        builder: (context, meterSnap) {
          String area = '—';
          String city = '—';

          if (meterSnap.hasData && meterSnap.data!.exists) {
            final m = meterSnap.data!.data() as Map<String, dynamic>;
            area = m['area'] ?? '—';
            city = m['city'] ?? '—';
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 30),
              //--------------
              //  Header 
              //--------------
              Center(
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF00E5FF).withOpacity(0.5),
                          width: 2,
                        ),
                      ),
                      child: const CircleAvatar(
                        radius: 45,
                        backgroundColor: Color(0xFF1B263B),
                        child: Icon(
                          Icons.person_outline,
                          size: 45,
                          color: Color(0xFF00E5FF),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Meter ID as Consumer ID
                    Text(
                      'Consumer #$meterID',
                      style: GoogleFonts.orbitron(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),

                    // Location
                    if (area != '—')
                      Text(
                        '$area, $city',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    const SizedBox(height: 10),

                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.greenAccent.withOpacity(0.4),
                        ),
                      ),
                      child: const Text(
                        'GRID MONITORING ACTIVE',
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 35),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  "ACCOUNT SETTINGS",
                  style: GoogleFonts.orbitron(
                    color: Colors.white54,
                    fontSize: 12,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  children: [
                    // Email — static info
                    _buildStaticTile(
                      Icons.email_outlined,
                      "Registered Email",
                      email,
                    ),
                    _buildTapTile(
                      context,
                      Icons.notifications_active_outlined,
                      "Notifications",
                      "Alert preferences",
                      onTap: () => _showComingSoon(context, "Notifications"),
                    ),
                    _buildTapTile(
                      context,
                      Icons.language_rounded,
                      "App Language",
                      "English (Default)",
                      onTap: () => _showLanguageDialog(context),
                    ),
                    _buildTapTile(
                      context,
                      Icons.info_outline_rounded,
                      "About GridEye",
                      "Version 1.0.0",
                      onTap: () => _showAboutDialog(context),
                    ),
                  ],
                ),
              ),

              _buildLogoutButton(context),
            ],
          );
        },
      ),
    );
  }

  // Static tile — no arrow, no tap
  Widget _buildStaticTile(IconData icon, String title, String sub) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF00E5FF), size: 22),
        title: Text(title,
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w500)),
        subtitle: Text(sub,
            style: const TextStyle(color: Colors.white38, fontSize: 11)),
      ),
    );
  }
}

// --------------------------
// SHARED WIDGETS & HELPERS
// --------------------------

AppBar _buildAppBar(BuildContext context) {
  return AppBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
    centerTitle: false,
    title: Text(
      "USER PROFILE",
      style: GoogleFonts.orbitron(
        color: const Color(0xFF00E5FF),
        fontSize: 16,
      ),
    ),
    leading: IconButton(
      icon: const Icon(
        Icons.arrow_back_ios_new,
        color: Colors.white70,
        size: 20,
      ),
      onPressed: () => Navigator.pop(context),
    ),
  );
}

Widget _buildTapTile(
  BuildContext context,
  IconData icon,
  String title,
  String sub, {
  required VoidCallback onTap,
}) {
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.03),
      borderRadius: BorderRadius.circular(15),
    ),
    child: ListTile(
      leading: Icon(icon, color: const Color(0xFF00E5FF), size: 22),
      title: Text(title,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w500)),
      subtitle: Text(sub,
          style: const TextStyle(color: Colors.white38, fontSize: 11)),
      trailing: const Icon(Icons.arrow_forward_ios,
          color: Colors.white24, size: 12),
      onTap: onTap,
    ),
  );
}

Widget _buildLogoutButton(BuildContext context) {
  return Padding(
    padding: const EdgeInsets.all(25.0),
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 55),
        side: const BorderSide(color: Colors.redAccent),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
      ),
      onPressed: () async {
        await FirebaseAuth.instance.signOut();
        if (!context.mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
      },
      child: const Text(
        "LOGOUT SESSION",
        style: TextStyle(
          color: Colors.redAccent,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
    ),
  );
}

// ___Dialog Helpers______________________________________________
void _showComingSoon(BuildContext context, String feature) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1B263B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(feature,
          style: GoogleFonts.orbitron(
              color: const Color(0xFF00E5FF), fontSize: 16)),
      content: const Text(
        'This feature is coming in the next update.',
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK',
              style: TextStyle(color: Color(0xFF00E5FF))),
        ),
      ],
    ),
  );
}

void _showLanguageDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1B263B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('App Language',
          style: GoogleFonts.orbitron(
              color: const Color(0xFF00E5FF), fontSize: 16)),
      content: const Text(
        'Currently only English is supported.\nMore languages coming soon.',
        style: TextStyle(color: Colors.white70),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK',
              style: TextStyle(color: Color(0xFF00E5FF))),
        ),
      ],
    ),
  );
}

void _showAboutDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      backgroundColor: const Color(0xFF1B263B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text('About GridEye',
          style: GoogleFonts.orbitron(
              color: const Color(0xFF00E5FF), fontSize: 16)),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'GridEye — Smart Grid Monitoring System',
            style: TextStyle(
                color: Colors.white, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Version: 1.0.0\nPlatform: Flutter + Firebase\n'
            'Purpose: Real-time electricity grid monitoring and theft detection.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK',
              style: TextStyle(color: Color(0xFF00E5FF))),
        ),
      ],
    ),
  );
}