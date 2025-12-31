class OpenRouterConfig {
  static const String authUrl = 'https://openrouter.ai/auth';
  static const String tokenUrl = 'https://openrouter.ai/api/v1/auth/keys';

  // GitHub Pages redirect proxy - accepts the OAuth callback and redirects to the app
  // The HTML page at this URL redirects to imagineapp://auth/callback with the code
  static const String callbackUrl = 'https://void-n-null.github.io/Imagine-App/auth.html';

  // Deep link scheme for the app (used by the redirect proxy)
  static const String callbackScheme = 'imagineapp';
}

