import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'splash_screen.dart';
import 'admin_dashboard.dart';

void main() async {
  // Firebase initialization
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); 
  runApp(GridEyeApp());
}

class GridEyeApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GridEye',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Color(0xFF0D1B2A),
        textTheme: GoogleFonts.montserratTextTheme(
          ThemeData.dark().textTheme,
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => SplashScreen(),
        '/login': (context) => GridEyeLogin(),
        '/roleSelection': (context) => RoleSelectionScreen(),
        '/adminDashboard': (context) => AdminDashboard(),
      },
    );
  }
}

// ==========================================
// LOGIN SCREEN
// ==========================================
class GridEyeLogin extends StatefulWidget {
  @override
  _GridEyeLoginState createState() => _GridEyeLoginState();
}

class _GridEyeLoginState extends State<GridEyeLogin> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      // Login successful, navigate to role selection
      Navigator.pushReplacementNamed(context, '/roleSelection');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login Failed: ${e.toString()}"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0D1B2A),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30.0, vertical: 80.0),
          child: Column(
            children: [
              Image.asset('assets/images/logo.png', width: 150),
              SizedBox(height: 20),
              Text("GridEye", style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF00E5FF), letterSpacing: 2)),
              Text("Smart Grid Monitoring System", style: TextStyle(color: Colors.white70, fontSize: 14)),
              SizedBox(height: 60),

              // Email Field
              TextField(
                controller: _emailController,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.email_outlined, color: Color(0xFF00E5FF)),
                  hintText: 'Corporate Email',
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                ),
              ),
              SizedBox(height: 20),

              // Password Field
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.lock_outline, color: Color(0xFF00E5FF)),
                  hintText: 'Password',
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                ),
              ),
              SizedBox(height: 30),

              // Login Button
              GestureDetector(
                onTap: _isLoading ? null : _handleLogin,
                child: Container(
                  width: double.infinity, height: 55,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    gradient: LinearGradient(colors: [Color(0xFF00E5FF), Color(0xFF008CAB)]),
                  ),
                  child: Center(
                    child: _isLoading 
                      ? CircularProgressIndicator(color: Colors.black)
                      : Text("LOGIN", style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
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

// ==========================================
// ROLE SELECTION SCREEN
// ==========================================
class RoleSelectionScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF0D1B2A),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              "Identify Your Role",
              style: GoogleFonts.orbitron(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF00E5FF),
                letterSpacing: 1.5,
              ),
            ),
            SizedBox(height: 10),
            Text(
              "Select access level to continue",
              style: TextStyle(color: Colors.white54),
            ),
            SizedBox(height: 50),
            
            // Utility Admin Card
            _buildRoleCard(
              context,
              title: "Utility Admin",
              subtitle: "Monitor Grid & Theft Alerts",
              icon: Icons.admin_panel_settings_outlined,
              onTap: () {
                Navigator.pushReplacementNamed(context, '/adminDashboard');
              },
            ),
            
            SizedBox(height: 20),
            
            // Consumer Card
            _buildRoleCard(
              context,
              title: "Consumer Portal",
              subtitle: "View Usage & Report Faults",
              icon: Icons.bolt_outlined,
              onTap: () => print("Consumer Dashboard"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleCard(BuildContext context, {required String title, required String subtitle, required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Color(0xFF00E5FF).withOpacity(0.2)),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Color(0xFF00E5FF).withOpacity(0.1),
              radius: 30,
              child: Icon(icon, color: Color(0xFF00E5FF), size: 30),
            ),
            SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(subtitle, style: TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
            Spacer(),
            Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 16),
          ],
        ),
      ),
    );
  }
}