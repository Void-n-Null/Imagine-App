import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../services/openrouter/openrouter_auth_page.dart';
import '../services/openrouter/openrouter_auth_service.dart';
import '../services/openrouter/openrouter_models.dart';
import '../services/storage/settings_service.dart';
import '../services/update/update_service.dart';
import '../theme/app_colors.dart';
import 'chat/model_selector_sheet.dart';

/// Settings page for app configuration.
class SettingsPage extends StatefulWidget {
  final List<OpenRouterModel> models;
  final String selectedModelId;
  final bool isLoadingModels;
  final VoidCallback onRefreshModels;
  final void Function(OpenRouterModel) onModelSelected;
  final bool isAuthenticated;
  final VoidCallback onAuthChanged;

  const SettingsPage({
    super.key,
    required this.models,
    required this.selectedModelId,
    required this.isLoadingModels,
    required this.onRefreshModels,
    required this.onModelSelected,
    required this.isAuthenticated,
    required this.onAuthChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final SettingsService _settings = SettingsService.instance;
  final OpenRouterAuthService _authService = OpenRouterAuthService();
  
  String _appVersion = '';
  String _buildNumber = '';
  bool _dontRemindForUpdates = false;
  String? _skippedVersion;

  @override
  void initState() {
    super.initState();
    _loadAppInfo();
    _loadUpdateSettings();
  }

  Future<void> _loadAppInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _appVersion = packageInfo.version;
        _buildNumber = packageInfo.buildNumber;
      });
    }
  }

  void _loadUpdateSettings() {
    setState(() {
      _dontRemindForUpdates = _settings.dontRemindMeForUpdates;
      _skippedVersion = _settings.skippedUpdateVersion;
    });
  }

  Future<void> _resetUpdateReminders() async {
    final updateService = UpdateService();
    await updateService.enableUpdateReminders();
    
    if (!mounted) return;
    
    _loadUpdateSettings();
    await HapticFeedback.lightImpact();
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Update reminders have been re-enabled'),
      ),
    );
  }

  void _showModelSelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => ModelSelectorSheet(
        models: widget.models,
        selectedModelId: widget.selectedModelId,
        isLoading: widget.isLoadingModels,
        onRefresh: widget.onRefreshModels,
        onModelSelected: (model) {
          widget.onModelSelected(model);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _connectOpenRouter() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => const OpenRouterAuthPage(),
      ),
    );

    if (result == true) {
      widget.onAuthChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Successfully connected to OpenRouter!')),
        );
      }
    }
  }

  Future<void> _disconnectOpenRouter() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Disconnect OpenRouter?'),
        content: const Text(
          'You will need to reconnect to use AI features.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.logout();
      widget.onAuthChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Disconnected from OpenRouter')),
        );
      }
    }
  }

  String _getSelectedModelName() {
    final model = widget.models.firstWhere(
      (m) => m.id == widget.selectedModelId,
      orElse: () => OpenRouterModel(
        id: widget.selectedModelId,
        name: widget.selectedModelId.split('/').last,
      ),
    );
    return model.name;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // AI Section
          _buildSectionHeader('AI Configuration'),
          const SizedBox(height: 12),
          _buildAISection(),
          
          const SizedBox(height: 32),
          
          // Updates Section
          _buildSectionHeader('Updates'),
          const SizedBox(height: 12),
          _buildUpdatesSection(),
          
          const SizedBox(height: 32),
          
          // About Section
          _buildSectionHeader('About'),
          const SizedBox(height: 12),
          _buildAboutSection(),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildAISection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // OpenRouter Connection
          _buildSettingsTile(
            icon: Icons.cloud_outlined,
            iconColor: widget.isAuthenticated ? AppColors.success : AppColors.textSecondary,
            title: 'OpenRouter',
            subtitle: widget.isAuthenticated ? 'Connected' : 'Not connected',
            trailing: widget.isAuthenticated
                ? OutlinedButton(
                    onPressed: _disconnectOpenRouter,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    child: const Text('Disconnect'),
                  )
                : ElevatedButton(
                    onPressed: _connectOpenRouter,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    child: const Text('Connect'),
                  ),
          ),
          
          const Divider(height: 1, color: AppColors.border),
          
          // Model Selection
          _buildSettingsTile(
            icon: Icons.auto_awesome_rounded,
            iconColor: AppColors.accentYellow,
            title: 'AI Model',
            subtitle: _getSelectedModelName(),
            onTap: widget.isAuthenticated ? _showModelSelector : null,
            trailing: widget.isAuthenticated
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.isLoadingModels)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryBlue,
                          ),
                        )
                      else
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.textSecondary,
                        ),
                    ],
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Connect first',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdatesSection() {
    final hasDisabledReminders = _dontRemindForUpdates || _skippedVersion != null;
    
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Update reminders status
          _buildSettingsTile(
            icon: Icons.notifications_outlined,
            iconColor: hasDisabledReminders ? AppColors.textSecondary : AppColors.success,
            title: 'Update Reminders',
            subtitle: _dontRemindForUpdates 
                ? 'Disabled' 
                : _skippedVersion != null 
                    ? 'Skipping v$_skippedVersion' 
                    : 'Enabled',
            trailing: hasDisabledReminders
                ? TextButton(
                    onPressed: _resetUpdateReminders,
                    child: const Text('Reset'),
                  )
                : const Icon(
                    Icons.check_circle_outlined,
                    color: AppColors.success,
                    size: 20,
                  ),
          ),
          
          if (hasDisabledReminders) ...[
            const Divider(height: 1, color: AppColors.border),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: AppColors.textSecondary.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _dontRemindForUpdates
                          ? 'You chose "Don\'t remind me" for updates. Tap Reset to re-enable.'
                          : 'You skipped version $_skippedVersion. Tap Reset to see it again.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary.withValues(alpha: 0.8),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAboutSection() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildSettingsTile(
            icon: Icons.info_outline_rounded,
            iconColor: AppColors.primaryBlue,
            title: 'Version',
            subtitle: '$_appVersion (Build $_buildNumber)',
          ),
          const Divider(height: 1, color: AppColors.border),
          _buildSettingsTile(
            icon: Icons.code_rounded,
            iconColor: AppColors.textSecondary,
            title: 'Source Code',
            subtitle: 'github.com/Void-n-Null/Imagine-App',
            onTap: () {
              // Could open GitHub URL
            },
            trailing: const Icon(
              Icons.open_in_new_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }
}
