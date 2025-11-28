import 'package:flutter/material.dart';
import '../../services/openrouter/openrouter_models.dart';
import '../../theme/app_colors.dart';

/// Recommended model configuration
class RecommendedModel {
  final String id;
  final String name;
  final String tagline;
  final String description;
  final Color accentColor;
  final IconData icon;

  const RecommendedModel({
    required this.id,
    required this.name,
    required this.tagline,
    required this.description,
    required this.accentColor,
    required this.icon,
  });
}

/// Predefined recommended models
const List<RecommendedModel> _recommendedModels = [
  RecommendedModel(
    id: 'openai/gpt-5.1-codex-mini',
    name: 'GPT-5.1 Codex Mini',
    tagline: 'Best Overall',
    description: 'Follows instructions with exceptional precision. Perfect for structured tasks and coding.',
    accentColor: Color(0xFF6366F1),
    icon: Icons.code_rounded,
  ),
  RecommendedModel(
    id: 'anthropic/claude-haiku-4.5',
    name: 'Claude Haiku 4.5',
    tagline: 'Best Cheap',
    description: 'The best cheap model for everyday tasks. Excellent quality at a fraction of the cost.',
    accentColor: Color(0xFFD97706),
    icon: Icons.local_fire_department_rounded,
  ),
  RecommendedModel(
    id: 'x-ai/grok-4.1-fast:free',
    name: 'Grok 4.1 Fast',
    tagline: 'Best Free',
    description: 'The best free model available. Fast responses with impressive reasoning capabilities at zero cost.',
    accentColor: Color(0xFF10B981),
    icon: Icons.bolt_rounded,
  ),
  RecommendedModel(
    id: 'google/gemini-2.5-flash-preview-09-2025',
    name: 'Gemini 2.5 Flash',
    tagline: 'Smart & Cheap',
    description: 'A great balance of really cheap and smart enough. Ideal for quick questions and research.',
    accentColor: Color(0xFF3B82F6),
    icon: Icons.flash_on_rounded,
  ),
];

/// Bottom sheet for selecting a model with recommended section
class ModelSelectorSheet extends StatefulWidget {
  final List<OpenRouterModel> models;
  final String selectedModelId;
  final bool isLoading;
  final VoidCallback onRefresh;
  final void Function(OpenRouterModel) onModelSelected;
  
  const ModelSelectorSheet({
    super.key,
    required this.models,
    required this.selectedModelId,
    required this.isLoading,
    required this.onRefresh,
    required this.onModelSelected,
  });

  @override
  State<ModelSelectorSheet> createState() => _ModelSelectorSheetState();
}

class _ModelSelectorSheetState extends State<ModelSelectorSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedProvider;
  bool _showAllModels = false;
  
  List<OpenRouterModel> get _filteredModels {
    var models = widget.models;
    
    // Filter by provider
    if (_selectedProvider != null) {
      models = models.where((m) => m.provider == _selectedProvider).toList();
    }
    
    // Filter by search
    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      models = models.where((m) => 
        m.name.toLowerCase().contains(query) ||
        m.id.toLowerCase().contains(query)
      ).toList();
    }
    
    return models;
  }
  
  List<String> get _providers {
    final providers = widget.models.map((m) => m.provider).toSet().toList();
    providers.sort();
    return providers;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _selectRecommendedModel(RecommendedModel recommended) {
    // Find the matching model in the list or create a placeholder
    final model = widget.models.firstWhere(
      (m) => m.id == recommended.id,
      orElse: () => OpenRouterModel(
        id: recommended.id,
        name: recommended.name,
      ),
    );
    widget.onModelSelected(model);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.primaryBlue,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Choose Model',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  if (widget.isLoading)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryBlue,
                      ),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded),
                      onPressed: widget.onRefresh,
                      tooltip: 'Refresh models',
                      color: AppColors.textSecondary,
                    ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // Recommended Models Section
                  if (!_showAllModels && _searchQuery.isEmpty) ...[
                    Text(
                      'RECOMMENDED',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textSecondary,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._recommendedModels.map((model) => _RecommendedModelCard(
                      model: model,
                      isSelected: widget.selectedModelId == model.id,
                      onTap: () => _selectRecommendedModel(model),
                    )),
                    const SizedBox(height: 24),
                    
                    // Browse all models button
                    GestureDetector(
                      onTap: () => setState(() => _showAllModels = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.grid_view_rounded,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Browse all ${widget.models.length} models',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else ...[
                    // Back to recommended
                    if (_searchQuery.isEmpty)
                      GestureDetector(
                        onTap: () => setState(() => _showAllModels = false),
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            children: [
                              Icon(
                                Icons.arrow_back_rounded,
                                size: 18,
                                color: AppColors.primaryBlue,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Back to recommended',
                                style: TextStyle(
                                  color: AppColors.primaryBlue,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    
                    // Search
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search models...',
                        hintStyle: TextStyle(color: AppColors.textSecondary),
                        prefixIcon: Icon(Icons.search_rounded, color: AppColors.textSecondary),
                        filled: true,
                        fillColor: AppColors.surfaceVariant,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                      style: TextStyle(color: AppColors.textPrimary),
                      onChanged: (value) => setState(() => _searchQuery = value),
                    ),
                    
                    // Provider filter
                    if (_providers.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 36,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          children: [
                            _buildProviderChip(null, 'All'),
                            for (final provider in _providers)
                              _buildProviderChip(provider, provider),
                          ],
                        ),
                      ),
                    ],
                    
                    const SizedBox(height: 16),
                    
                    // Model list
                    if (_filteredModels.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 48,
                              color: AppColors.textSecondary.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No models found',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    else
                      ...List.generate(_filteredModels.length, (index) {
                        final model = _filteredModels[index];
                        final isSelected = model.id == widget.selectedModelId;
                        
                        return _ModelListTile(
                          model: model,
                          isSelected: isSelected,
                          onTap: () => widget.onModelSelected(model),
                        );
                      }),
                    const SizedBox(height: 16),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildProviderChip(String? provider, String label) {
    final isSelected = _selectedProvider == provider;
    
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedProvider = provider),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected 
                ? AppColors.primaryBlue.withOpacity(0.15)
                : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.primaryBlue : AppColors.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? AppColors.primaryBlue : AppColors.textPrimary,
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// Card for recommended models with premium styling
class _RecommendedModelCard extends StatefulWidget {
  final RecommendedModel model;
  final bool isSelected;
  final VoidCallback onTap;

  const _RecommendedModelCard({
    required this.model,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_RecommendedModelCard> createState() => _RecommendedModelCardState();
}

class _RecommendedModelCardState extends State<_RecommendedModelCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) {
        setState(() => _isPressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isPressed 
              ? widget.model.accentColor.withOpacity(0.1)
              : widget.isSelected
                  ? widget.model.accentColor.withOpacity(0.08)
                  : AppColors.userMessageBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.isSelected 
                ? widget.model.accentColor.withOpacity(0.5)
                : AppColors.border.withOpacity(0.5),
            width: widget.isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: widget.model.accentColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                widget.model.icon,
                color: widget.model.accentColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        widget.model.name,
                        style: TextStyle(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: widget.model.accentColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          widget.model.tagline,
                          style: TextStyle(
                            color: widget.model.accentColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.model.description,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            
            // Selection indicator
            const SizedBox(width: 12),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: widget.isSelected 
                    ? widget.model.accentColor 
                    : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.isSelected 
                      ? widget.model.accentColor 
                      : AppColors.border,
                  width: 2,
                ),
              ),
              child: widget.isSelected
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 14,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact list tile for all models view
class _ModelListTile extends StatelessWidget {
  final OpenRouterModel model;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModelListTile({
    required this.model,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.primaryBlue.withOpacity(0.1)
              : AppColors.surfaceVariant.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? AppColors.primaryBlue.withOpacity(0.5)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected 
                    ? AppColors.primaryBlue 
                    : AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  model.provider[0].toUpperCase(),
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model.name,
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${model.provider} • ${model.priceDisplay}',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                color: AppColors.primaryBlue,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
