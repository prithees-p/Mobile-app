import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../api_service.dart';
import 'package:learning/main.dart';
class Signuppage extends StatefulWidget {
  const Signuppage({super.key});

  @override
  State<Signuppage> createState() => _SignuppageState();
}

class _SignuppageState extends State<Signuppage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  String? _selectedRole;
  bool _isLoading = false; // Added to show a loading state

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (_nameController.text.isEmpty || _emailController.text.isEmpty || _selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields")),
      );
      return;
    }

    setState(() => _isLoading = true);

    bool success = await signupfunction(
      _nameController.text, 
      _emailController.text, 
      _selectedRole
    );

    setState(() => _isLoading = false);

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Signup Successful!")),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ChangePasswordPage(email: _emailController.text),
        ),
      );
    }
  }

  Future<bool> signupfunction(String name, String email, String? role) async {
    try {
      final response = await ApiService().dio.post(
        "/api/method/great_indian.great_indian.utils.api.signupfunction", 
        data: {"name": name, "email": email, "role": role, "phone": _phoneController.text},
      );
      return response.statusCode == 200;
    } catch (e) {
      print(e);
      debugPrint("Error during signup: $e");
      return false;
    } 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Sign Up")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Icon(Icons.app_registration, size: 80, color: Colors.blue),
            const SizedBox(height: 40),
            
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email Address',
                prefixIcon: Icon(Icons.email),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            DropdownButtonFormField<String>(
              value: _selectedRole,
              hint: const Text("Select your role"),
              decoration: const InputDecoration(
                labelText: 'I am a...',
                prefixIcon: Icon(Icons.work),
                border: OutlineInputBorder(),
              ),
              items: ['Job Seeker', 'Job Poster'].map((String role) {
                return DropdownMenuItem<String>(value: role, child: Text(role));
              }).toList(),
              onChanged: (val) => setState(() => _selectedRole = val),
            ),
            const SizedBox(height: 30),
            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSignup,
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text("Sign Up", style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}


class ChangePasswordPage extends StatefulWidget {
  final String email; 
  const ChangePasswordPage({super.key, required this.email});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _obscureText = true;
  bool _obscureText2 = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    final pwd = _passwordController.text;
    final confirmPwd = _confirmPasswordController.text;

    // Validation
    if (pwd.isEmpty || pwd.length < 6) {
      _showSnackBar("Password must be at least 6 characters");
      return;
    }
    if (pwd != confirmPwd) {
      _showSnackBar("Passwords do not match!");
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await ApiService().dio.post(
        "/api/method/great_indian.great_indian.utils.api.set_password",
        data: {
          "email": widget.email,
          "password": pwd,
        },
      );

      if (response.statusCode == 200 && mounted) {
        _showSnackBar("Password set successfully!");
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => LoginPage(
              preFilledEmail: widget.email,
              preFilledPassword: pwd,
            ),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      _showSnackBar("Error setting password: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Set Password")),
      body: SingleChildScrollView( // Added to prevent keyboard overflow
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Text(
              "Setting password for: ${widget.email}",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            
            TextFormField(
              controller: _passwordController,
              obscureText: _obscureText,
              decoration: InputDecoration(
                labelText: 'New Password',
                prefixIcon: const Icon(Icons.lock),
                suffixIcon: IconButton(
                  icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureText = !_obscureText),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscureText2,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscureText2 ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureText2 = !_obscureText2),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updatePassword,
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Save Password"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}