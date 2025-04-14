import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  // ... (existing code)
}

class _LoginPageState extends State<LoginPage> {
  // ... (existing code)
}

@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios,
          color: Colors.white,
        ),
        onPressed: () {
          Navigator.pushReplacementNamed(context, '/');  // Navigate back to welcome page
        },
      ),
    ),
    body: // ... (existing code)
  );
}

// ... (rest of the existing code)

onPressed: () async {
  // ... your existing login logic ...
  Navigator.pushReplacementNamed(context, '/home');
}, 