import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ProfileScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false, // FIXED: Left Aligned
        title: Text(
          "USER PROFILE", 
          style: GoogleFonts.orbitron(color: const Color(0xFF00E5FF), fontSize: 16)
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white70, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 30),
          
          // --- Profile Header Section ---
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.5), width: 2),
                  ),
                  child: const CircleAvatar(
                    radius: 45,
                    backgroundColor: Color(0xFF1B263B),
                    child: Icon(Icons.person_outline, size: 45, color: Color(0xFF00E5FF)),
                  ),
                ),
                const SizedBox(height: 15),
                Text("Consumer #MTR-5520", 
                  style: GoogleFonts.orbitron(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)
                ),
                const Text("GRID MONITORING ACTIVE", 
                  style: TextStyle(color: Colors.greenAccent, fontSize: 10, letterSpacing: 1.5, fontWeight: FontWeight.bold)
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // --- Settings List (Clean & Consistent) ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text("ACCOUNT SETTINGS", 
              style: GoogleFonts.orbitron(color: Colors.white54, fontSize: 12, letterSpacing: 1.2)
            ),
          ),
          const SizedBox(height: 15),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                _buildListTile(Icons.notifications_active_outlined, "Notifications", "Alert preferences"),
                _buildListTile(Icons.lock_outline_rounded, "Security", "Change password & PIN"),
                _buildListTile(Icons.language_rounded, "App Language", "English (Default)"),
                _buildListTile(Icons.info_outline_rounded, "About GridEye", "Version 1.0.2 (Beta)"),
              ],
            ),
          ),

          // --- Logout Button (Clean Outline Style) ---
          Padding(
            padding: const EdgeInsets.all(25.0),
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 55),
                side: const BorderSide(color: Colors.redAccent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              onPressed: () => Navigator.pushReplacementNamed(context, '/roleSelection'),
              child: const Text("LOGOUT SESSION", 
                style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, letterSpacing: 1.5)
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListTile(IconData icon, String title, String sub) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.03),
        borderRadius: BorderRadius.circular(15),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF00E5FF), size: 22),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
        subtitle: Text(sub, style: const TextStyle(color: Colors.white38, fontSize: 11)),
        trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 12),
        onTap: () {},
      ),
    );
  }
}