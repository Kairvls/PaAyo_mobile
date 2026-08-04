import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {

  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() =>
      _LoginScreenState();

}

class _LoginScreenState
    extends State<LoginScreen> {

  bool loading = false;

  Future<void> login() async {

    setState(() {

      loading = true;

    });

    try {

      final response =
          await AuthService().login();

      print(response.data);

        if (!mounted) return;

        Navigator.pushReplacementNamed(
        context,
        "/scanner",
        );

    }

    catch (e) {

      print(e);

    }

    setState(() {

      loading = false;

    });

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      body: Center(

        child: ElevatedButton.icon(

          onPressed:

              loading

                  ? null

                  : login,

          icon: const Icon(Icons.login),

          label: Text(

            loading

                ? "Connecting..."

                : "Continue with Microsoft",

          ),

        ),

      ),

    );

  }

}