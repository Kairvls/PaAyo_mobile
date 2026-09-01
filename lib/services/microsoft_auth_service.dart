import 'package:flutter_appauth/flutter_appauth.dart';

class MicrosoftAuthService {
  static const String clientId =
      "e018b49c-cea5-459c-bd1c-bb322128494a";

  static const String tenantId =
      "0597b255-289d-49a3-8316-33b7a3174f92";

  static const String redirectUrl =
      "msauth://ph.edu.stiormoc.paayo";

  final FlutterAppAuth appAuth = const FlutterAppAuth();

  AuthorizationServiceConfiguration get _serviceConfiguration {
    return AuthorizationServiceConfiguration(
      authorizationEndpoint:
          "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/authorize",
      tokenEndpoint:
          "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token",
    );
  }

  /// First sign-in: account picker. Returning sign-in: saved email + password (+ MFA).
  Future<AuthorizationTokenResponse?> signIn({String? loginHint}) async {
    final trimmedHint = loginHint?.trim();
    final hasHint = trimmedHint != null && trimmedHint.isNotEmpty;

    return await appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        clientId,
        redirectUrl,
        serviceConfiguration: _serviceConfiguration,
        scopes: const [
          "openid",
          "profile",
          "email",
          "offline_access",
          "User.Read",
        ],
        promptValues: [hasHint ? "login" : "select_account"],
        additionalParameters: hasHint ? {"login_hint": trimmedHint} : null,
      ),
    );
  }
}
