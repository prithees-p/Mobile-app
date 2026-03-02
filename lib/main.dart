import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/dashboard.dart';
import 'api_service.dart';
import 'package:dio/dio.dart';
import 'screens/signuppage.dart';
import 'screens/distance_traveled.dart';
import 'package:pay/pay.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await ApiService().init();

  final prefs = await SharedPreferences.getInstance();
  final bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

  runApp(MyApp(isLoggedIn: isLoggedIn));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ERP Login',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: isLoggedIn ? const Dashboard() : const LoginPage(),
    );
  }
}
class LoginPage extends StatefulWidget {
  final String? preFilledEmail;
  final String? preFilledPassword;

  const LoginPage({super.key, this.preFilledEmail, this.preFilledPassword});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  late TextEditingController emailController;
  late TextEditingController passwordController;

  bool isLoading = false;
  bool obscurePassword = true;
  bool rememberMe = true;
  final List<PaymentItem> _paymentItems = [
    PaymentItem(
      label: 'Total',
      amount: '99.99',
      status: PaymentItemStatus.final_price,
    )
  ];
  late final Dio dio;

  @override
  void initState() {
    super.initState();
    dio = ApiService().dio;

    emailController = TextEditingController(text: widget.preFilledEmail ?? "");
    passwordController = TextEditingController(text: widget.preFilledPassword ?? "");

    _loadSavedUser();
  }

  Future<void> _loadSavedUser() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      emailController.text = prefs.getString('savedEmail') ?? '';
    });
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message), 
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> login() async {
    if (emailController.text.isEmpty || passwordController.text.isEmpty) {
      showError("Please fill in all fields");
      return;
    }

    setState(() => isLoading = true);

    try {
      final response = await dio.post(
        "/api/method/login",
        data: {
          "usr": emailController.text.trim(),
          "pwd": passwordController.text.trim(),
        },
      );

      final data = response.data;
      print(data);
      if (response.statusCode == 200 && data["message"] == "Logged In") {
        getrole();
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isLoggedIn', true);
        await prefs.setString('userEmail', emailController.text.trim());
        await prefs.setString('full_name', data["full_name"]);

        if (rememberMe) {
          await prefs.setString('savedEmail', emailController.text.trim());
        } else {
          await prefs.remove('savedEmail');
        }

        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const Dashboard()),
          (route) => false,
        );
      } else {
        showError(data["message"] ?? "Invalid Credentials");
      }
    } catch (e) {
      showError("Server not reachable");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }
  void getrole() async {
    try {
      final response = await dio.get(
        "/api/method/application.application.utils.py.api.get_user_role?username=${emailController.text.trim()}",
      );

      if (response.statusCode == 200) {
        final role = response.data["message"];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userRole', role);
        print(prefs.getString('userRole'));
      }
    } catch (e) {
      debugPrint("Error fetching user role: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- TOP DESIGN SECTION ---
            _buildHeader(size),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Welcome Back",
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
                  ),
                  const Text(
                    "Sign in to manage your ERP",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 40),

                  // --- EMAIL FIELD ---
                  _buildInputLabel("Email Address"),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: emailController,
                    hint: "name@company.com",
                    icon: Icons.email_outlined,
                  ),
                  const SizedBox(height: 25),

                  // --- PASSWORD FIELD ---
                  _buildInputLabel("Password"),
                  const SizedBox(height: 8),
                  _buildTextField(
                    controller: passwordController,
                    hint: "••••••••",
                    icon: Icons.lock_outline,
                    isPassword: true,
                    obscureText: obscurePassword,
                    onSuffixTap: () => setState(() => obscurePassword = !obscurePassword),
                  ),

                  // --- REMEMBER ME & FORGOT PASSWORD ---
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Row(
                      //   children: [
                      //     Checkbox(
                      //       value: rememberMe,
                      //       activeColor: Colors.indigo,
                      //       onChanged: (val) => setState(() => rememberMe = val!),
                      //     ),
                      //     const Text("Remember Me", style: TextStyle(color: Colors.black54)),
                      //   ],
                      // ),
                      TextButton(
                        onPressed: () {},
                        child: const Text("Forgot Password?", style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
                      ),
                      TextButton(child: const Text("Sign Up", style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
                        onPressed: () => 
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const Signuppage())),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo[900],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 5,
                      ),
                      child: isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("SIGN IN", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DistanceTraveledScreen())),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo[700],
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        elevation: 5,
                      ),
                      child: const Text("DISTANCE TRAVELED", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1)),
                    ),
                  ),
                  const SizedBox(height:40),
                  // GooglePayButton(
                  //   paymentConfiguration: PaymentConfiguration.fromJsonString(
                  //       defaultGooglePayConfigString),
                  //   paymentItems: _paymentItems,
                  //   type: GooglePayButtonType.buy,
                  //   margin: const EdgeInsets.only(top: 15.0),
                  //   onPaymentResult: onGooglePayResult,
                  //   loadingIndicator: const Center(
                  //     child: CircularProgressIndicator(),
                  //   ),
                  // ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  void onGooglePayResult(paymentResult) {
    print(paymentResult);
  }
  Widget _buildHeader(Size size) {
    return Container(
      height: size.height * 0.3,
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Colors.indigo,
        gradient: LinearGradient(
          colors: [Color(0xFF1A237E), Colors.indigo],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(bottomRight: Radius.circular(80)),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.business_center_rounded, size: 70, color: Colors.white),
          SizedBox(height: 10),
          Text(
            "JOB CONNECT",
            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 2),
          ),
        ],
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87));
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onSuffixTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.indigo[300]),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(obscureText ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                  onPressed: onSuffixTap,
                )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }
}