import 'package:flutter_appauth/flutter_appauth.dart';

class MicrosoftAuthService {
  static const String clientId =
      "e018b49c-cea5-459c-bd1c-bb322128494a";

  static const String tenantId =
      "0597b255-289d-49a3-8316-33b7a3174f92";

  /// Must match Azure → Authentication → Mobile and desktop applications.
  /// Keep this simple (no signature-hash path). The MSAL Android hash URI
  /// often fails to return into flutter_appauth after "Continue".
  static const String redirectUrl =
      "msauth://ph.edu.stiormoc.paayo";

  final FlutterAppAuth appAuth = const FlutterAppAuth();

  Future<AuthorizationTokenResponse?> signIn() async {
    return await appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        clientId,
        redirectUrl,
        serviceConfiguration: AuthorizationServiceConfiguration(
          authorizationEndpoint:
              "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/authorize",
          tokenEndpoint:
              "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token",
        ),
        scopes: const [
          "openid",
          "profile",
          "email",
          "offline_access",
          "User.Read",
        ],
        promptValues: const ["select_account"],
      ),
    );
  }
}
