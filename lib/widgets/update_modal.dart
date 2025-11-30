import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../services/update/update.dart';
import '../theme/app_colors.dart';

/// A modal dialog that prompts the user to update the app.
class UpdateModal extends StatefulWidget {
  final GitHubRelease release;
  final String currentVersion;
  final VoidCallback? onUpdate;
  final VoidCallback? onSkip;
  final VoidCallback? onDontRemind;

  const UpdateModal({
    super.key,
    required this.release,
    required this.currentVersion,
    this.onUpdate,
    this.onSkip,
    this.onDontRemind,
  });

  /// Shows the update modal as a bottom sheet.
  static Future<UpdateAction?> show(
    BuildContext context,
    GitHubRelease release,
    String currentVersion,
  ) async {
    return showModalBottomSheet<UpdateAction>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => UpdateModal(
        release: release,
        currentVersion: currentVersion,
      ),
    );
  }

  @override
  State<UpdateModal> createState() => _UpdateModalState();
}

/// Enum representing the user's choice in the update modal.
enum UpdateAction {
  update,
  skip,
  dontRemind,
}

class _UpdateModalState extends State<UpdateModal>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = screenHeight * 0.75;

    return AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: 0.9 + (_scaleAnimation.value * 0.1),
          child: Opacity(
            opacity: _scaleAnimation.value,
            child: child,
          ),
        );
      },
      child: Container(
        constraints: BoxConstraints(maxHeight: maxHeight),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(bottom: 20),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header with icon
            _buildHeader(),
            const SizedBox(height: 20),

            // Version info
            _buildVersionInfo(),
            const SizedBox(height: 16),

            // Release notes (scrollable)
            if (widget.release.body.isNotEmpty) ...[
              _buildReleaseNotes(),
              const SizedBox(height: 20),
            ],

            // Action buttons
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.system_update_rounded,
            color: AppColors.success,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Update Available',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                widget.release.name.isNotEmpty
                    ? widget.release.name
                    : 'Version ${widget.release.version}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVersionInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildVersionColumn(
              'Current',
              widget.currentVersion,
              AppColors.textSecondary,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: AppColors.border,
          ),
          Expanded(
            child: _buildVersionColumn(
              'Latest',
              widget.release.version,
              AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVersionColumn(String label, String version, Color versionColor) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'v$version',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: versionColor,
          ),
        ),
      ],
    );
  }

  Widget _buildReleaseNotes() {
    return Flexible(
      child: Container(
        constraints: const BoxConstraints(maxHeight: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.article_outlined,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                const Text(
                  'What\'s New',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: MarkdownBody(
                  data: widget.release.body,
                  styleSheet: MarkdownStyleSheet(
                    p: const TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: AppColors.textSecondary,
                    ),
                    h1: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    h2: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    h3: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    listBullet: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                    code: TextStyle(
                      fontSize: 12,
                      backgroundColor: AppColors.surfaceVariant,
                      color: AppColors.accentYellow,
                    ),
                    codeblockDecoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Primary: Update Now
        FilledButton.icon(
          onPressed: _isUpdating ? null : _handleUpdate,
          icon: _isUpdating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.background,
                  ),
                )
              : const Icon(Icons.download_rounded),
          label: Text(_isUpdating ? 'Opening...' : 'Update Now'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.success,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Secondary: Skip This Version
        OutlinedButton(
          onPressed: _isUpdating ? null : _handleSkip,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textPrimary,
            side: const BorderSide(color: AppColors.border),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('No Thanks'),
        ),
        const SizedBox(height: 8),

        // Tertiary: Don't Remind Me
        TextButton(
          onPressed: _isUpdating ? null : _handleDontRemind,
          style: TextButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          child: const Text(
            'Don\'t remind me again',
            style: TextStyle(fontSize: 13),
          ),
        ),
      ],
    );
  }

  Future<void> _handleUpdate() async {
    setState(() => _isUpdating = true);
    widget.onUpdate?.call();
    Navigator.of(context).pop(UpdateAction.update);
  }

  void _handleSkip() {
    widget.onSkip?.call();
    Navigator.of(context).pop(UpdateAction.skip);
  }

  void _handleDontRemind() {
    widget.onDontRemind?.call();
    Navigator.of(context).pop(UpdateAction.dontRemind);
  }
}
