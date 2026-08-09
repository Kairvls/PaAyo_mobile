import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../services/auth_service.dart';
import '../../services/microsoft_auth_service.dart';
import '../home/home_screen.dart';

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
  static const _ink = Color(0xFF0F172A);
  static const _muted = Color(0xFF64748B);
  static const _soft = Color(0xFFF3F4F6);

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
        message:
            "You closed the Microsoft sign-in window. Tap below when you're ready to try again.",
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
            "This Microsoft account is not authorized for equipment management. Only STI College Ormoc Maintenance Personnel can continue.",
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
            "We couldn't reach the PaAyo server. Check your Wi‑Fi and try again.",
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

  String? _extractName(Map data) {
    // Try a few common shapes so the dashboard greeting can be personalized.
    final candidates = <dynamic>[
      data["name"],
      data["display_name"],
      data["full_name"],
      data["user"] is Map ? data["user"]["name"] : null,
      data["user"] is Map ? data["user"]["display_name"] : null,
      data["user"] is Map ? data["user"]["full_name"] : null,
      data["personnel"] is Map ? data["personnel"]["name"] : null,
    ];

    for (final c in candidates) {
      final value = c?.toString().trim();
      if (value != null && value.isNotEmpty) {
        // Use just the first name for a friendly greeting.
        return value.split(RegExp(r"\s+")).first;
      }
    }
    return null;
  }

  int? _extractUserId(Map data) {
    final candidates = <dynamic>[
      data["user"] is Map ? data["user"]["id"] : null,
      data["user"] is Map ? data["user"]["user_id"] : null,
      data["id"],
      data["user_id"],
    ];
    for (final c in candidates) {
      final id = int.tryParse(c?.toString() ?? "");
      if (id != null) return id;
    }
    return null;
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

      final name = _extractName(data);
      if (name != null) {
        await storage.write(key: "name", value: name);
      }

      final userId = _extractUserId(data);
      if (userId != null) {
        await storage.write(key: "user_id", value: userId.toString());
      }

      if (!mounted) return;

      Navigator.pushReplacementNamed(
        context,
        "/dashboard",
      );
    } on DioException catch (e) {
      if (!mounted) return;

      final status = e.response?.statusCode;
      if (status == 401 || status == 403) {
        _showFeedback(
          kind: _LoginFeedbackKind.denied,
          title: "Access not allowed",
          message:
              "Your account signed in with Microsoft, but it is not registered as Maintenance Personnel in PaAyo. Please use an authorized account or contact your administrator.",
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

  void _goBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => const HomeScreen(initialPage: 1),
        ),
      );
    }
  }

  Color get _feedbackColor {
    switch (feedbackKind) {
      case _LoginFeedbackKind.denied:
        return const Color(0xFFB91C1C);
      case _LoginFeedbackKind.cancelled:
        return _muted;
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
        return _soft;
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
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Material(
                  color: _soft,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _goBack,
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        Icons.arrow_back_rounded,
                        size: 22,
                        color: _ink,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.sizeOf(context).height -
                          MediaQuery.paddingOf(context).vertical -
                          140,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          "assets/images/scan_login2.png",
                          height: 220,
                          fit: BoxFit.contain,
                          filterQuality: FilterQuality.high,
                        ),
                        const SizedBox(height: 28),
                        const Text(
                          "Sign in",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: _ink,
                            letterSpacing: -0.6,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          "Use your Office 365 account to manage\ncampus equipment and maintenance.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14.5,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                            color: _muted,
                          ),
                        ),
                        if (feedbackKind != _LoginFeedbackKind.none) ...[
                          const SizedBox(height: 22),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                            decoration: BoxDecoration(
                              color: _feedbackBackground,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  _feedbackIcon,
                                  size: 20,
                                  color: _feedbackColor,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        feedbackTitle,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: _feedbackColor,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        feedbackMessage,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          height: 1.4,
                                          color: Color(0xFF475569),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              _Office365Button(
                loading: loading,
                denied: feedbackKind == _LoginFeedbackKind.denied,
                onPressed: loading ? null : login,
              ),
              const SizedBox(height: 14),
              const Text(
                "Maintenance Personnel only",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Office365Button extends StatelessWidget {
  final bool loading;
  final bool denied;
  final VoidCallback? onPressed;

  const _Office365Button({
    required this.loading,
    required this.denied,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final label = loading
        ? "Signing in…"
        : denied
            ? "Try another account"
            : "Continue with Microsoft";

    return SizedBox(
      width: double.infinity,
      height: 52,
      child: Material(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Opacity(
            opacity: onPressed == null ? 0.72 : 1,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                else
                  Image.asset(
                    "assets/images/microsoft_logo.png",
                    width: 22,
                    height: 22,
                    fit: BoxFit.contain,
                  ),
                const SizedBox(width: 12),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
