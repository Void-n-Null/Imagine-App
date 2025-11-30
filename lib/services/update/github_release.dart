/// Model representing a GitHub release from the API.
class GitHubRelease {
  final String tagName;
  final String name;
  final String body;
  final String htmlUrl;
  final DateTime publishedAt;
  final bool prerelease;
  final bool draft;
  final List<GitHubAsset> assets;

  GitHubRelease({
    required this.tagName,
    required this.name,
    required this.body,
    required this.htmlUrl,
    required this.publishedAt,
    required this.prerelease,
    required this.draft,
    required this.assets,
  });

  factory GitHubRelease.fromJson(Map<String, dynamic> json) {
    return GitHubRelease(
      tagName: json['tag_name'] ?? '',
      name: json['name'] ?? '',
      body: json['body'] ?? '',
      htmlUrl: json['html_url'] ?? '',
      publishedAt: DateTime.tryParse(json['published_at'] ?? '') ?? DateTime.now(),
      prerelease: json['prerelease'] ?? false,
      draft: json['draft'] ?? false,
      assets: (json['assets'] as List<dynamic>?)
              ?.map((e) => GitHubAsset.fromJson(e))
              .toList() ??
          [],
    );
  }

  /// Gets the version string without the 'v' prefix.
  String get version {
    if (tagName.startsWith('v') || tagName.startsWith('V')) {
      return tagName.substring(1);
    }
    return tagName;
  }

  /// Gets the download URL for a specific platform.
  /// Returns null if no matching asset is found.
  String? getDownloadUrlForPlatform(String platform) {
    final platformLower = platform.toLowerCase();
    
    for (final asset in assets) {
      final nameLower = asset.name.toLowerCase();
      
      if (platformLower == 'android' && 
          (nameLower.endsWith('.apk') || nameLower.contains('android'))) {
        return asset.browserDownloadUrl;
      }
      
      if (platformLower == 'windows' && 
          (nameLower.endsWith('.exe') || 
           nameLower.endsWith('.msix') || 
           nameLower.contains('windows'))) {
        return asset.browserDownloadUrl;
      }
      
      if (platformLower == 'linux' && 
          (nameLower.endsWith('.deb') || 
           nameLower.endsWith('.AppImage') ||
           nameLower.endsWith('.tar.gz') ||
           nameLower.contains('linux'))) {
        return asset.browserDownloadUrl;
      }
      
      if (platformLower == 'macos' && 
          (nameLower.endsWith('.dmg') || 
           nameLower.endsWith('.pkg') ||
           nameLower.contains('macos') ||
           nameLower.contains('darwin'))) {
        return asset.browserDownloadUrl;
      }
    }
    
    return null;
  }
}

/// Model representing a release asset (downloadable file).
class GitHubAsset {
  final String name;
  final String browserDownloadUrl;
  final int size;
  final String contentType;
  final int downloadCount;

  GitHubAsset({
    required this.name,
    required this.browserDownloadUrl,
    required this.size,
    required this.contentType,
    required this.downloadCount,
  });

  factory GitHubAsset.fromJson(Map<String, dynamic> json) {
    return GitHubAsset(
      name: json['name'] ?? '',
      browserDownloadUrl: json['browser_download_url'] ?? '',
      size: json['size'] ?? 0,
      contentType: json['content_type'] ?? '',
      downloadCount: json['download_count'] ?? 0,
    );
  }

  /// Returns the file size in a human-readable format.
  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
