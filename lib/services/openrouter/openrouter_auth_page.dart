import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import '../../config/openrouter_config.dart';
import '../../theme/app_colors.dart';
import 'openrouter_auth_service.dart';

/// OpenRouter OAuth authentication page.
///
/// Uses flutter_web_auth_2 which opens a secure browser tab
/// (Chrome Custom Tabs on Android, ASWebAuthenticationSession on iOS).
/// Google OAuth works properly in these secure browser contexts.
class OpenRouterAuthPage extends StatefulWidget {
  const OpenRouterAuthPage({super.key});

  @override
  State<OpenRouterAuthPage> createState() => _OpenRouterAuthPageState();
}

class _OpenRouterAuthPageState extends State<OpenRouterAuthPage> {
  late final OpenRouterAuthService _authService;
  String? _error;

  @override
  void initState() {
    super.initState();
    _authService = OpenRouterAuthService();
    // Start auth flow immediately
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAuthFlow();
    });
  }

  Future<void> _startAuthFlow() async {
    setState(() => _error = null);

    try {
      // Generate PKCE codes
      final codeVerifier = _authService.generateCodeVerifier();
      final codeChallenge = _authService.generateCodeChallenge(codeVerifier);

      // Store verifier for later exchange
      await _authService.storeVerifier(codeVerifier);

      // Build the auth URL
      final authUrl = _buildAuthUrl(codeChallenge);
      debugPrint('🔐 OpenRouter Auth URL: $authUrl');
      debugPrint('🔑 Callback scheme: ${OpenRouterConfig.callbackScheme}');

      // Launch secure browser and wait for callback
      // flutter_web_auth_2 uses Chrome Custom Tabs / ASWebAuthenticationSession
      // which are secure browser contexts where Google OAuth works!
      final result = await FlutterWebAuth2.authenticate(
        url: authUrl,
        callbackUrlScheme: OpenRouterConfig.callbackScheme,
        options: const FlutterWebAuth2Options(
          timeout: 300, // 5 minute timeout
          preferEphemeral: false, // Use shared session so existing logins work
        ),
      );

      debugPrint('🔗 Auth result: $result');

      // Parse the result URL to get the code
      final uri = Uri.parse(result);
      final code = uri.queryParameters['code'];
      final error = uri.queryParameters['error'];

      if (error != null) {
        throw Exception('Authorization denied: $error');
      }

      if (code == null) {
        throw Exception('No authorization code received');
      }

      debugPrint('✅ Got auth code: $code');

      // Exchange code for API key
      await _authService.exchangeCode(code);

      if (mounted) {
        Navigator.of(context).pop(true); // Success!
      }
    } catch (e) {
      debugPrint('❌ Auth flow error: $e');
      if (mounted) {
        setState(() => _error = _formatError(e));
      }
    }
  }

  String _formatError(dynamic error) {
    final message = error.toString();

    // User cancelled
    if (message.contains('CANCELED') || message.contains('cancelled')) {
      return 'Authentication was cancelled';
    }

    // Timeout
    if (message.contains('timeout') || message.contains('TIMEOUT')) {
      return 'Authentication timed out. Please try again.';
    }

    return 'Authentication failed: $message';
  }

  String _buildAuthUrl(String codeChallenge) {
    final callbackEncoded = Uri.encodeComponent(OpenRouterConfig.callbackUrl);
    final challengeEncoded = Uri.encodeComponent(codeChallenge);
    return '${OpenRouterConfig.authUrl}?callback_url=$callbackEncoded&code_challenge=$challengeEncoded&code_challenge_method=S256';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text('Connect OpenRouter'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return _buildErrorState();
    }

    return _buildLoadingState();
  }

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_open,
                size: 40,
                color: AppColors.primaryBlue,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Connecting to OpenRouter',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Complete sign-in in the browser window...',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(
              color: AppColors.primaryBlue,
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 32),
              Text(
                'Callback: ${OpenRouterConfig.callbackUrl}',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            const Text(
              'Authentication Failed',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _startAuthFlow,
              icon: const Icon(Icons.refresh),
              label: const Text('Try Again'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}
