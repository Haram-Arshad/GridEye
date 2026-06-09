import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ConsumerProfileScreen extends StatelessWidget {
  final Map<String, dynamic> userData;
  const ConsumerProfileScreen({super.key, required this.userData});

  @override
  Widget build(BuildContext context) {
    final email    = FirebaseAuth.instance.currentUser?.email ?? '—';
    final meterID  = userData['meterID'] ?? '—';

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
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
      ),
      body: FutureBuilder<DocumentSnapshot>(
        // meters collection se area + city fetch karo
        future: FirebaseFirestore.instance
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

              // ── Profile Header ────────────────────────────
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
                    const SizedBox(height: 15),

                    // Meter ID
                    Text(
                      'Consumer #$meterID',
                      style: GoogleFonts.orbitron(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Location badge
                    if (area != '—')
                      Text(
                        '$area, $city',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),

                    const SizedBox(height: 8),

                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 5,
                      ),
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

              const SizedBox(height: 40),

              // ── Section Label ──────────────────────────────
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
              const SizedBox(height: 15),

              // ── Settings List ──────────────────────────────
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  children: [
                    // Email — read only info tile
                    _buildStaticTile(
                      Icons.email_outlined,
                      "Registered Email",
                      email,
                    ),
                    _buildTapTile(
                      Icons.notifications_active_outlined,
                      "Notifications",
                      "Alert preferences",
                      onTap: () => _showComingSoon(context, "Notifications"),
                    ),
                    _buildTapTile(
                      Icons.language_rounded,
                      "App Language",
                      "English (Default)",
                      onTap: () => _showLanguageInfo(context),
                    ),
                    _buildTapTile(
                      Icons.info_outline_rounded,
                      "About GridEye",
                      "Version 1.0.0",
                      onTap: () => _showAboutDialog(context),
                    ),
                  ],
                ),
              ),

              // ── Logout ─────────────────────────────────────
              Padding(
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
              ),
            ],
          );
        },
      ),
    );
  }

  // ── Tile Builders ─────────────────────────────────────────
  Widget _buildStaticTile(IconData icon, String title, String sub) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF00E5FF), size: 22),
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          sub,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
      ),
    );
  }

  Widget _buildTapTile(
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
        title: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          sub,
          style: const TextStyle(color: Colors.white38, fontSize: 11),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Colors.white24,
          size: 12,
        ),
        onTap: onTap,
      ),
    );
  }

  // ── Dialogs ───────────────────────────────────────────────
  void _showComingSoon(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1B263B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          feature,
          style: GoogleFonts.orbitron(
            color: const Color(0xFF00E5FF),
            fontSize: 16,
          ),
        ),
        content: const Text(
          'This feature is coming in the next update.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(color: Color(0xFF00E5FF)),
            ),
          ),
        ],
      ),
    );
  }

  void _showLanguageInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1B263B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'App Language',
          style: GoogleFonts.orbitron(
            color: const Color(0xFF00E5FF),
            fontSize: 16,
          ),
        ),
        content: const Text(
          'Currently only English is supported.\nMore languages coming soon.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(color: Color(0xFF00E5FF)),
            ),
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
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          'About GridEye',
          style: GoogleFonts.orbitron(
            color: const Color(0xFF00E5FF),
            fontSize: 16,
          ),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GridEye — Smart Grid Monitoring System',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Version: 1.0.0\nPlatform: Flutter + Firebase\nPurpose: Real-time electricity grid monitoring and theft detection.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'OK',
              style: TextStyle(color: Color(0xFF00E5FF)),
            ),
          ),
        ],
      ),
    );
  }
}