class OpenRouterConfig {
  static const String authUrl = 'https://openrouter.ai/auth';
  static const String tokenUrl = 'https://openrouter.ai/api/v1/auth/keys';
  
  // OpenRouter requires http/https callback URLs
  // Using localhost which they explicitly support for local apps
  static const String callbackUrl = 'http://localhost:3000/callback';
}

