import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../models/user_info.dart';
import 'sign_in.dart';

class ProfileScreen extends StatefulWidget {
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserInfo? userInfo;
  String? error;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchUser();
  }

  void fetchUser() async {
    try {
      final info = await AuthService(baseUrl: 'https://chillguys.fun').getMyInfo();
      setState(() {
        userInfo = info;
        loading = false;
      });
    } catch (e) {
      setState(() {
        error = e.toString();
        loading = false;
      });
    }
  }

  Future<void> _signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('accessToken');
    await prefs.remove('refreshToken');
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => SignInScreen()),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(child: Text(error!, style: TextStyle(color: Colors.red)));
    }
    return Container(
      width: double.infinity,
      height: double.infinity,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: userInfo == null
                  ? Text('No user info')
                  : Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 24),
                  CircleAvatar(
                    radius: 48,
                    backgroundColor: Colors.green[100],
                    child: Icon(Icons.person, size: 60, color: Colors.green[700]),
                  ),
                  SizedBox(height: 18),
                  Text(
                    '${userInfo!.firstName} ${userInfo!.lastName}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF388e3c),
                      fontFamily: 'Montserrat',
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '@${userInfo!.username}',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.green[900],
                      fontFamily: 'Montserrat',
                    ),
                  ),
                  SizedBox(height: 24),
                  Card(
                    elevation: 6,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    color: Colors.white.withOpacity(0.93),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _profileRow(Icons.email, 'Email', userInfo!.email),
                          _profileRow(Icons.phone, 'Phone', userInfo!.phone),
                          _profileRow(Icons.cake, 'Birthday', userInfo!.birthday),
                          _profileRow(Icons.wc, 'Gender', userInfo!.gender),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 32),
                  // You can add more info or widgets here if needed
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 32.0),
            child: ElevatedButton.icon(
              icon: Icon(Icons.logout, color: Colors.white),
              label: Text(
                "Sign Out",
                style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold, fontSize: 17),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600],
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 3,
              ),
              onPressed: _signOut,
            ),
          ),
        ],
      ),
    );
  }

  Widget _profileRow(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Icon(icon, color: Color(0xFF388e3c)),
          SizedBox(width: 14),
          Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontFamily: 'Montserrat',
              fontSize: 16,
              color: Colors.green[900],
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              value ?? '',
              style: TextStyle(
                fontFamily: 'Montserrat',
                fontSize: 16,
                color: Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}