import 'package:flutter/material.dart';
import 'sign_in.dart';
import 'sign_up.dart';

class WelcomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Gradient background with plant theme
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFb7e7c9),
                  Color(0xFFe0f7fa),
                  Color(0xFFf5fbe7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Decorative plant illustrations
          Positioned(
            top: 0,
            left: 0,
            child: Opacity(
              opacity: 0.18,
              child: Icon(Icons.local_florist, size: 100, color: Colors.green[400]),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Opacity(
              opacity: 0.15,
              child: Icon(Icons.local_florist, size: 50, color: Colors.green),
            ),
          ),
          // Main content
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Card(
                elevation: 16,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
                color: Colors.white.withOpacity(0.96),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Mầm cây icon
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Color(0xFFa8e063), Color(0xFF56ab2f)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        padding: EdgeInsets.all(18),
                        child: Icon(
                          Icons.spa,
                          size: 64,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 18),
                      Text(
                        "Welcome to\n TAD Garden app",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF388e3c),
                          fontFamily: 'Montserrat',
                          letterSpacing: 1.3,
                        ),
                      ),
                      SizedBox(height: 14),
                      Text(
                        "Monitor soil moisture and control your garden's watering system easily.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 17,
                          color: Color(0xFF4e944f),
                          fontFamily: 'Montserrat',
                        ),
                      ),
                      SizedBox(height: 36),
                      ElevatedButton.icon(
                        icon: Icon(Icons.login, color: Colors.white),
                        label: Text(
                          "Sign In",
                          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF56ab2f),
                          padding: EdgeInsets.symmetric(horizontal: 44, vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 6,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => SignInScreen()),
                          );
                        },
                      ),
                      SizedBox(height: 22),
                      TextButton.icon(
                        icon: Icon(Icons.eco, color: Color(0xFF388e3c)),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => SignUpScreen()),
                          );
                        },
                        label: Text(
                          "Don't have an account? Sign up",
                          style: TextStyle(
                            color: Color(0xFF388e3c),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}