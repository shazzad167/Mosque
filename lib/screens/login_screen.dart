import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'map_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _loading = false;

  // ---------------- LOGIN FUNCTION ----------------

  Future<void> _login() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      _showMessage('Username and password are required');
      return;
    }

    setState(() => _loading = true);

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(username)
          .get();

      if (!doc.exists) {
        _showMessage('User not found');
        return;
      }

      final data = doc.data();
      if (data == null || data['password'] != password) {
        _showMessage('Incorrect password');
        return;
      }

      if (!mounted) return;

      // ✅ SUCCESS → DIRECTLY GO TO MAP SCREEN (AUTHORIZED)
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => const MapScreen(
            isAuthorized: true, // 🔐 ADMIN / AUTH USER
          ),
        ),
      );
    } catch (e) {
      _showMessage('Login failed. Try again.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  // ---------------- MESSAGE HELPER ----------------

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // ---------------- UI ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Username',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _loading ? null : _login,
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Login'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
