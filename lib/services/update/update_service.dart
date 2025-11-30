import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'package:package_info_plus/package_info_plus.dart';

import '../storage/settings_service.dart';
import 'github_release.dart';

/// Service for checking and handling app updates via GitHub Releases.
class UpdateService {
  static const String _repoOwner = 'Void-n-Null';
  static const String _repoName = 'Imagine-App';
  static const String _apiUrl =
      'https://api.github.com/repos/$_repoOwner/$_repoName/releases/latest';

  final http.Client _httpClient;
  String? currentVersion;

  UpdateService({http.Client? httpClient})
      : _httpClient = httpClient ?? http.Client();

  /// Checks if an update is available.
  /// Returns the release info if an update is available and should be shown,
  /// or null if no update is available or user has opted out.
  Future<GitHubRelease?> checkForUpdate() async {
    try {
      // Get current app version
      final packageInfo = await PackageInfo.fromPlatform();
      final version = packageInfo.version;
      currentVersion = version;

      // Check if user has disabled update reminders
      if (SettingsService.instance.dontRemindMeForUpdates) {
        debugPrint('UpdateService: User has disabled update reminders');
        return null;
      }

      final release = await _fetchLatestRelease(version);
      if (release == null) {
        debugPrint('UpdateService: Could not fetch latest release');
        return null;
      }

      // Skip pre-releases and drafts
      if (release.prerelease || release.draft) {
        debugPrint('UpdateService: Latest release is prerelease/draft, skipping');
        return null;
      }

      // Check if this version should be skipped
      final skippedVersion = SettingsService.instance.skippedUpdateVersion;
      if (skippedVersion == release.version) {
        debugPrint('UpdateService: User skipped version ${release.version}');
        return null;
      }

      // Compare versions
      if (_isNewerVersion(release.version, version)) {
        debugPrint(
            'UpdateService: New version available: ${release.version} (current: $version)');
        return release;
      }

      debugPrint(
          'UpdateService: No update needed (latest: ${release.version}, current: $version)');
      return null;
    } catch (e) {
      debugPrint('UpdateService: Error checking for updates: $e');
      return null;
    }
  }

  /// Fetches the latest release from GitHub.
  Future<GitHubRelease?> _fetchLatestRelease(String currentVersion) async {
    try {
      final response = await _httpClient.get(
        Uri.parse(_apiUrl),
        headers: {
          'Accept': 'application/vnd.github.v3+json',
          'User-Agent': 'ImagineApp/$currentVersion',
        },
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return GitHubRelease.fromJson(json);
      } else if (response.statusCode == 404) {
        debugPrint('UpdateService: No releases found (404)');
        return null;
      } else {
        debugPrint(
            'UpdateService: GitHub API error: ${response.statusCode} ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('UpdateService: Network error: $e');
      return null;
    }
  }

  /// Compares two semantic versions.
  /// Returns true if [newVersion] is greater than [currentVersion].
  bool _isNewerVersion(String newVersion, String currentVersion) {
    final newParts = _parseVersion(newVersion);
    final currentParts = _parseVersion(currentVersion);

    for (int i = 0; i < 3; i++) {
      final newPart = i < newParts.length ? newParts[i] : 0;
      final currentPart = i < currentParts.length ? currentParts[i] : 0;

      if (newPart > currentPart) return true;
      if (newPart < currentPart) return false;
    }

    return false;
  }

  /// Parses a version string into a list of integers.
  List<int> _parseVersion(String version) {
    // Remove 'v' prefix if present
    String cleaned = version;
    if (cleaned.startsWith('v') || cleaned.startsWith('V')) {
      cleaned = cleaned.substring(1);
    }

    // Remove build number suffix (e.g., +1)
    final plusIndex = cleaned.indexOf('+');
    if (plusIndex != -1) {
      cleaned = cleaned.substring(0, plusIndex);
    }

    // Parse major.minor.patch
    return cleaned.split('.').map((s) => int.tryParse(s) ?? 0).toList();
  }

  /// Gets the current platform identifier.
  String getCurrentPlatform() {
    if (kIsWeb) return 'web';
    if (Platform.isAndroid) return 'android';
    if (Platform.isIOS) return 'ios';
    if (Platform.isWindows) return 'windows';
    if (Platform.isLinux) return 'linux';
    if (Platform.isMacOS) return 'macos';
    return 'unknown';
  }

  /// Initiates the update process for the current platform.
  Future<bool> initiateUpdate(GitHubRelease release) async {
    final platform = getCurrentPlatform();
    debugPrint('UpdateService: Initiating update for platform: $platform');

    switch (platform) {
      case 'android':
        return _updateAndroid(release);
      case 'ios':
        return _updateIOS(release);
      case 'windows':
      case 'linux':
      case 'macos':
        return _updateDesktop(release, platform);
      case 'web':
        return _updateWeb(release);
      default:
        return _openReleasePage(release);
    }
  }

  /// Android: Download and install APK.
  Future<bool> _updateAndroid(GitHubRelease release) async {
    final downloadUrl = release.getDownloadUrlForPlatform('android');
    if (downloadUrl != null) {
      return _launchUrl(downloadUrl);
    }
    // Fallback to releases page
    return _openReleasePage(release);
  }

  /// iOS: Open App Store or releases page.
  Future<bool> _updateIOS(GitHubRelease release) async {
    // TODO: If you have an App Store ID, use:
    // return _launchUrl('https://apps.apple.com/app/id<APP_STORE_ID>');
    
    // For now, open the releases page
    return _openReleasePage(release);
  }

  /// Desktop: Download installer.
  Future<bool> _updateDesktop(GitHubRelease release, String platform) async {
    final downloadUrl = release.getDownloadUrlForPlatform(platform);
    if (downloadUrl != null) {
      return _launchUrl(downloadUrl);
    }
    // Fallback to releases page
    return _openReleasePage(release);
  }

  /// Web: Open releases page.
  Future<bool> _updateWeb(GitHubRelease release) async {
    return _openReleasePage(release);
  }

  /// Opens the GitHub releases page in the browser.
  Future<bool> _openReleasePage(GitHubRelease release) async {
    return _launchUrl(release.htmlUrl);
  }

  /// Launches a URL in the system browser.
  Future<bool> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      debugPrint('UpdateService: Cannot launch URL: $url');
      return false;
    } catch (e) {
      debugPrint('UpdateService: Error launching URL: $e');
      return false;
    }
  }

  /// Marks the current release as skipped (user chose "No Thanks").
  Future<void> skipVersion(String version) async {
    await SettingsService.instance.setSkippedUpdateVersion(version);
  }

  /// Disables all future update reminders (user chose "Don't Remind Me").
  Future<void> disableUpdateReminders() async {
    await SettingsService.instance.setDontRemindMeForUpdates(true);
  }

  /// Re-enables update reminders.
  Future<void> enableUpdateReminders() async {
    await SettingsService.instance.setDontRemindMeForUpdates(false);
    await SettingsService.instance.setSkippedUpdateVersion(null);
  }
}
