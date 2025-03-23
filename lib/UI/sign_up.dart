import 'package:flutter/material.dart';
import 'otp.dart';

class SignUpScreen extends StatefulWidget {
  @override
  _SignUpScreenState createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  String? errorMessage;

  void _signUp() {
    if (passwordController.text != confirmPasswordController.text) {
      setState(() {
        errorMessage = "Passwords do not match!";
      });
      return;
    }

    setState(() {
      errorMessage = null;
    });

    // Chuyển sang màn hình OTP
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => OTPScreen(email: emailController.text)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Sign Up")),
      body: Padding(
        padding: EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: nameController, decoration: InputDecoration(labelText: "Name")),
              SizedBox(height: 10),
              TextField(controller: emailController, decoration: InputDecoration(labelText: "Email")),
              SizedBox(height: 10),
              TextField(controller: phoneController, decoration: InputDecoration(labelText: "Phone")),
              SizedBox(height: 10),
              TextField(controller: passwordController, decoration: InputDecoration(labelText: "Password"), obscureText: true),
              SizedBox(height: 10),
              TextField(controller: confirmPasswordController, decoration: InputDecoration(labelText: "Confirm Password"), obscureText: true),
              SizedBox(height: 10),
              if (errorMessage != null)
                Text(errorMessage!, style: TextStyle(color: Colors.red)),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: _signUp,
                child: Text("Sign Up"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
