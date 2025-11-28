import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../config/openrouter_config.dart';
import '../../theme/app_colors.dart';
import 'openrouter_auth_service.dart';

class OpenRouterAuthPage extends StatefulWidget {
  const OpenRouterAuthPage({super.key});

  @override
  State<OpenRouterAuthPage> createState() => _OpenRouterAuthPageState();
}

class _OpenRouterAuthPageState extends State<OpenRouterAuthPage> {
  late final WebViewController _controller;
  late final OpenRouterAuthService _authService;
  late final String _codeVerifier;
  late final String _codeChallenge;
  bool _isLoading = true;
  String? _error;
  String _currentUrl = '';

  // Use a desktop Chrome user agent to avoid mobile detection issues
  static const String _desktopUserAgent = 
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

  @override
  void initState() {
    super.initState();
    _authService = OpenRouterAuthService();
    _initAuth();
  }

  Future<void> _initAuth() async {
    // Generate PKCE codes
    _codeVerifier = _authService.generateCodeVerifier();
    _codeChallenge = _authService.generateCodeChallenge(_codeVerifier);
    
    // Store verifier for later
    await _authService.storeVerifier(_codeVerifier);

    // Build the auth URL
    final authUrl = _buildAuthUrl();
    debugPrint('🔐 OpenRouter Auth URL: $authUrl');
    debugPrint('🔑 Code Verifier: $_codeVerifier');
    debugPrint('🔑 Code Challenge: $_codeChallenge');
    
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(AppColors.background)
      ..setUserAgent(_desktopUserAgent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            if (progress == 100) {
              setState(() => _isLoading = false);
            }
          },
          onPageStarted: (String url) {
            debugPrint('📍 Page started: $url');
            setState(() {
              _isLoading = true;
              _currentUrl = url;
            });
          },
          onPageFinished: (String url) {
            debugPrint('✅ Page finished: $url');
            setState(() => _isLoading = false);
          },
          onNavigationRequest: (NavigationRequest request) {
            debugPrint('🧭 Navigation request: ${request.url}');
            
            // Check if this is our callback URL (localhost)
            if (request.url.startsWith('http://localhost:3000') ||
                request.url.startsWith('http://localhost:3000/')) {
              debugPrint('🎯 Callback detected!');
              _handleCallback(request.url);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onWebResourceError: (WebResourceError error) {
            debugPrint('❌ Web error: ${error.description} for ${error.url}');
            // Check if error URL is our callback (localhost won't actually load)
            if (error.url?.startsWith('http://localhost:3000') ?? false) {
              debugPrint('🎯 Callback detected via error handler!');
              _handleCallback(error.url!);
              return;
            }
            // Don't show error for non-critical resources
            if (error.errorType == WebResourceErrorType.unknown) {
              return;
            }
          },
          onUrlChange: (UrlChange change) {
            debugPrint('🔄 URL changed: ${change.url}');
            if (change.url != null) {
              if (change.url!.startsWith('http://localhost:3000')) {
                debugPrint('🎯 Callback detected via URL change!');
                _handleCallback(change.url!);
              }
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(authUrl));

    setState(() {});
  }

  String _buildAuthUrl() {
    final callbackEncoded = Uri.encodeComponent(OpenRouterConfig.callbackUrl);
    final challengeEncoded = Uri.encodeComponent(_codeChallenge);
    return '${OpenRouterConfig.authUrl}?callback_url=$callbackEncoded&code_challenge=$challengeEncoded&code_challenge_method=S256';
  }

  Future<void> _handleCallback(String url) async {
    debugPrint('🔓 Handling callback: $url');
    final uri = Uri.parse(url);
    final code = uri.queryParameters['code'];
    
    if (code != null) {
      debugPrint('✅ Got auth code: $code');
      setState(() => _isLoading = true);
      
      try {
        await _authService.exchangeCode(code);
        if (mounted) {
          Navigator.of(context).pop(true); // Success
        }
      } catch (e) {
        debugPrint('❌ Exchange failed: $e');
        if (mounted) {
          setState(() {
            _error = 'Failed to complete auth: $e';
            _isLoading = false;
          });
        }
      }
    } else {
      // Check for error
      final error = uri.queryParameters['error'];
      debugPrint('❌ No code in callback. Error: $error');
      setState(() {
        _error = error ?? 'Authentication failed - no code received';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connect OpenRouter'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        actions: [
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.bug_report),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Debug Info'),
                    content: SingleChildScrollView(
                      child: Text(
                        'Current URL:\n$_currentUrl\n\n'
                        'Callback URL:\n${OpenRouterConfig.callbackUrl}\n\n'
                        'Code Challenge:\n$_codeChallenge',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
      body: Stack(
        children: [
          if (_error != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 64, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.error),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _error = null;
                          _isLoading = true;
                        });
                        _initAuth();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else
            WebViewWidget(controller: _controller),
          if (_isLoading)
            Container(
              color: AppColors.background.withValues(alpha: 0.7),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}

