import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../services/auth_service.dart';
import '../../services/microsoft_auth_service.dart';

enum _LoginFeedbackKind {
  none,
  denied,
  cancelled,
  network,
  generic,
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool loading = false;
  _LoginFeedbackKind feedbackKind = _LoginFeedbackKind.none;
  String feedbackTitle = "";
  String feedbackMessage = "";

  final MicrosoftAuthService microsoft = MicrosoftAuthService();
  final FlutterSecureStorage storage = const FlutterSecureStorage();

  void _clearFeedback() {
    setState(() {
      feedbackKind = _LoginFeedbackKind.none;
      feedbackTitle = "";
      feedbackMessage = "";
    });
  }

  void _showFeedback({
    required _LoginFeedbackKind kind,
    required String title,
    required String message,
  }) {
    setState(() {
      feedbackKind = kind;
      feedbackTitle = title;
      feedbackMessage = message;
    });
  }

  void _mapError(Object error) {
    final text = error.toString().toLowerCase();

    if (text.contains("user_cancelled") ||
        text.contains("user cancelled") ||
        text.contains("login cancelled") ||
        text.contains("sign-in cancelled")) {
      _showFeedback(
        kind: _LoginFeedbackKind.cancelled,
        title: "Sign-in cancelled",
        message: "You closed the Microsoft sign-in window. Tap the button below when you're ready to try again.",
      );
      return;
    }

    if (text.contains("access_denied") ||
        text.contains("does not exist in tenant") ||
        text.contains("external user") ||
        text.contains("aads") ||
        text.contains("unauthorized") ||
        text.contains("forbidden") ||
        text.contains("not authorized") ||
        text.contains("not allowed") ||
        text.contains("maintenance")) {
      _showFeedback(
        kind: _LoginFeedbackKind.denied,
        title: "Access not allowed",
        message:
            "This Microsoft account is not authorized for equipment management.\n\nOnly STI College Ormoc Maintenance Personnel can continue. Please sign in with an approved work account.",
      );
      return;
    }

    if (text.contains("socket") ||
        text.contains("connection") ||
        text.contains("timed out") ||
        text.contains("network") ||
        text.contains("failed host lookup") ||
        text.contains("dioexception")) {
      _showFeedback(
        kind: _LoginFeedbackKind.network,
        title: "Connection problem",
        message:
            "We couldn't reach the PaAyo server. Check your Wi‑Fi connection and try again.",
      );
      return;
    }

    _showFeedback(
      kind: _LoginFeedbackKind.generic,
      title: "Sign-in unsuccessful",
      message:
          "Something went wrong while signing in. Please try again with your Maintenance Personnel account.",
    );
  }

  Future<void> login() async {
    _clearFeedback();

    setState(() {
      loading = true;
    });

    try {
      final result = await microsoft.signIn();

      if (result == null) {
        throw Exception("Login cancelled.");
      }

      final accessToken = result.accessToken;

      if (accessToken == null) {
        throw Exception("No access token received.");
      }

      final response = await AuthService().login(accessToken);
      final data = response.data;
      final status = response.statusCode ?? 0;

      if (status == 401 || status == 403) {
        final serverMessage = data is Map ? data["message"]?.toString() : null;
        throw Exception(
          serverMessage ?? "Unauthorized. Not allowed for maintenance access.",
        );
      }

      if (status != 200 || data is! Map || data["token"] == null) {
        final serverMessage = data is Map ? data["message"]?.toString() : null;
        throw Exception(serverMessage ?? "Login failed.");
      }

      await storage.write(
        key: "token",
        value: data["token"].toString(),
      );

      if (!mounted) return;

      Navigator.pushReplacementNamed(
        context,
        "/scanner",
      );
    } on DioException catch (e) {
      if (!mounted) return;

      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        _showFeedback(
          kind: _LoginFeedbackKind.denied,
          title: "Access not allowed",
          message:
              "Your account signed in with Microsoft, but it is not registered as Maintenance Personnel in PaAyo.\n\nPlease use an authorized account or contact your administrator.",
        );
      } else {
        _mapError(e);
      }
    } catch (e) {
      if (!mounted) return;
      _mapError(e);
    }

    if (mounted) {
      setState(() {
        loading = false;
      });
    }
  }

  Color get _feedbackColor {
    switch (feedbackKind) {
      case _LoginFeedbackKind.denied:
        return const Color(0xFFB91C1C);
      case _LoginFeedbackKind.cancelled:
        return const Color(0xFF64748B);
      case _LoginFeedbackKind.network:
        return const Color(0xFFC2410C);
      case _LoginFeedbackKind.generic:
        return const Color(0xFFB45309);
      case _LoginFeedbackKind.none:
        return Colors.transparent;
    }
  }

  Color get _feedbackBackground {
    switch (feedbackKind) {
      case _LoginFeedbackKind.denied:
        return const Color(0xFFFEF2F2);
      case _LoginFeedbackKind.cancelled:
        return const Color(0xFFF8FAFC);
      case _LoginFeedbackKind.network:
        return const Color(0xFFFFF7ED);
      case _LoginFeedbackKind.generic:
        return const Color(0xFFFFFBEB);
      case _LoginFeedbackKind.none:
        return Colors.transparent;
    }
  }

  IconData get _feedbackIcon {
    switch (feedbackKind) {
      case _LoginFeedbackKind.denied:
        return Icons.lock_outline_rounded;
      case _LoginFeedbackKind.cancelled:
        return Icons.info_outline_rounded;
      case _LoginFeedbackKind.network:
        return Icons.wifi_off_rounded;
      case _LoginFeedbackKind.generic:
        return Icons.error_outline_rounded;
      case _LoginFeedbackKind.none:
        return Icons.info_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  "assets/images/paayo_logo.png",
                  width: 170,
                ),
                const SizedBox(height: 30),
                const Text(
                  "Maintenance Personnel",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Sign in to manage equipment.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Only authorized STI College Ormoc\nMaintenance Personnel may continue.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.black45,
                  ),
                ),
                if (feedbackKind != _LoginFeedbackKind.none) ...[
                  const SizedBox(height: 28),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                    decoration: BoxDecoration(
                      color: _feedbackBackground,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _feedbackColor.withValues(alpha: 0.18),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          _feedbackIcon,
                          size: 34,
                          color: _feedbackColor,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          feedbackTitle,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: _feedbackColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          feedbackMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 14.5,
                            height: 1.45,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 45),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: loading ? null : login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2F2F2F),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFD1D5DB),
                      disabledForegroundColor: const Color(0xFF6B7280),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: Image.asset(
                      "assets/images/microsoft_logo.png",
                      width: 24,
                    ),
                    label: Text(
                      loading
                          ? "Signing In..."
                          : feedbackKind == _LoginFeedbackKind.denied
                              ? "Try another account"
                              : "Log in with Office 365",
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                if (feedbackKind == _LoginFeedbackKind.denied) ...[
                  const SizedBox(height: 14),
                  TextButton(
                    onPressed: loading
                        ? null
                        : () {
                            Navigator.pushReplacementNamed(context, "/home");
                          },
                    child: const Text(
                      "Back to Home",
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
