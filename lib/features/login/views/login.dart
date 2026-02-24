import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/login_provider.dart';
import '../pages/server_setup_screen.dart';

/// The entry point for the login feature, providing the [LoginProvider].
class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => LoginProvider(),
      child: const ServerSetupScreen(),
    );
  }
}
