import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/storage/storage.dart';
import 'theme/app_colors.dart';
import 'widgets/chat_page.dart';
import 'widgets/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set system UI overlay style for splash
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: AppColors.background,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppColors.background,
    systemNavigationBarIconBrightness: Brightness.light,
  ));
  
  // Initialize storage services
  await SettingsService.initialize();
  await ChatStorageService.initialize();
  await ChatManager.initialize();
  
  runApp(const ImagineApp());
}

class ImagineApp extends StatelessWidget {
  const ImagineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Imagine App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.background,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primaryBlue,
          secondary: AppColors.accentYellow,
          surface: AppColors.surface,
          error: AppColors.error,
          onPrimary: AppColors.background,
          onSecondary: AppColors.background,
          onSurface: AppColors.textPrimary,
          onError: Colors.white,
          outline: AppColors.border,
          outlineVariant: AppColors.border,
          surfaceContainerHighest: AppColors.surfaceVariant,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textPrimary,
          elevation: 0,
          centerTitle: true,
        ),
        cardTheme: CardThemeData(
          color: AppColors.surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppColors.border),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: AppColors.background,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.accentYellow,
          ),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.accentYellow;
            }
            return AppColors.textSecondary;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return AppColors.accentYellow.withValues(alpha: 0.4);
            }
            return AppColors.surfaceVariant;
          }),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.border,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: AppColors.surfaceVariant,
          contentTextStyle: const TextStyle(color: AppColors.textPrimary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: const AppWithSplash(),
    );
  }
}

class AppWithSplash extends StatefulWidget {
  const AppWithSplash({super.key});

  @override
  State<AppWithSplash> createState() => _AppWithSplashState();
}

class _AppWithSplashState extends State<AppWithSplash> {
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const ChatPage(),
        if (_showSplash)
          SplashScreen(
            onComplete: () {
              setState(() {
                _showSplash = false;
              });
            },
          ),
      ],
    );
  }
}
