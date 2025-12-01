import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/bestbuy/bestbuy.dart';
import '../../theme/app_colors.dart';

class StoreAvailabilitySection extends StatelessWidget {
  const StoreAvailabilitySection({
    super.key,
    required this.isLoading,
    required this.error,
    required this.availability,
    required this.userPostalCode,
    required this.onRetry,
    required this.onSearchByPostalCode,
    required this.onUseCurrentLocation,
  });

  final bool isLoading;
  final String? error;
  final StoreAvailabilityResponse? availability;
  final String? userPostalCode;
  final VoidCallback onRetry;
  final void Function(String) onSearchByPostalCode;
  final VoidCallback onUseCurrentLocation;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingState();
    }

    if (error == 'location_needed') {
      return _PostalCodeInput(
        userPostalCode: userPostalCode,
        onSearch: onSearchByPostalCode,
        onUseCurrentLocation: onUseCurrentLocation,
      );
    }

    if (error != null) {
      return _buildErrorState(context);
    }

    if (availability != null && availability!.hasAvailableStores) {
      return _NearestStoreCard(
        availability: availability!,
        userPostalCode: userPostalCode,
        onSearchByPostalCode: onSearchByPostalCode,
        onUseCurrentLocation: onUseCurrentLocation,
      );
    }

    if (availability != null && !availability!.hasAvailableStores) {
      return _buildNoStoresState(context);
    }

    return _buildFindStoreButton();
  }

  Widget _buildLoadingState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primaryBlue,
            ),
          ),
          SizedBox(width: 14),
          Text(
            'Finding nearest store...',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.error_outline,
                  color: AppColors.textSecondary.withValues(alpha: 0.7), size: 20),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Could not find nearby stores',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              ),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
          const SizedBox(height: 8),
          _PostalCodeInput(
            compact: true,
            userPostalCode: userPostalCode,
            onSearch: onSearchByPostalCode,
            onUseCurrentLocation: onUseCurrentLocation,
          ),
        ],
      ),
    );
  }

  Widget _buildNoStoresState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.store_outlined,
                  color: AppColors.textSecondary.withValues(alpha: 0.7), size: 20),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('No stores with this product nearby',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _PostalCodeInput(
            compact: true,
            userPostalCode: userPostalCode,
            onSearch: onSearchByPostalCode,
            onUseCurrentLocation: onUseCurrentLocation,
          ),
        ],
      ),
    );
  }

  Widget _buildFindStoreButton() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onRetry,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_on_outlined, size: 20, color: AppColors.primaryBlue),
              SizedBox(width: 8),
              Text('Find Nearest Store',
                  style: TextStyle(
                      color: AppColors.primaryBlue, fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PostalCodeInput extends StatelessWidget {
  const _PostalCodeInput({
    this.compact = false,
    required this.userPostalCode,
    required this.onSearch,
    required this.onUseCurrentLocation,
  });

  final bool compact;
  final String? userPostalCode;
  final void Function(String) onSearch;
  final VoidCallback onUseCurrentLocation;

  @override
  Widget build(BuildContext context) {
    final controller = TextEditingController(text: userPostalCode);

    return Container(
      padding: compact ? EdgeInsets.zero : const EdgeInsets.all(16),
      decoration: compact
          ? null
          : BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!compact) ...[
            Row(
              children: [
                Icon(Icons.location_on_outlined,
                    color: AppColors.textSecondary.withValues(alpha: 0.7), size: 20),
                const SizedBox(width: 12),
                const Text('Enter your ZIP code to find stores',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  maxLength: 5,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 16, letterSpacing: 2),
                  decoration: InputDecoration(
                    hintText: '12345',
                    hintStyle: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.5), letterSpacing: 2),
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: () {
                  if (controller.text.length == 5) onSearch(controller.text);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Search',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          if (userPostalCode != null) ...[
            const SizedBox(height: 12),
            Center(
              child: TextButton.icon(
                onPressed: onUseCurrentLocation,
                icon: const Icon(Icons.my_location, size: 16),
                label: const Text('Use Current Location'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primaryBlue),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NearestStoreCard extends StatelessWidget {
  const _NearestStoreCard({
    required this.availability,
    required this.userPostalCode,
    required this.onSearchByPostalCode,
    required this.onUseCurrentLocation,
  });

  final StoreAvailabilityResponse availability;
  final String? userPostalCode;
  final void Function(String) onSearchByPostalCode;
  final VoidCallback onUseCurrentLocation;

  @override
  Widget build(BuildContext context) {
    final store = availability.nearestStore!;
    final otherStoresCount = availability.stores.length - 1;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryBlue.withValues(alpha: 0.1),
            AppColors.primaryBlue.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(store),
          const SizedBox(height: 12),
          _buildAddress(store),
          if (store.lowStock) _buildLowStockWarning(),
          if (availability.ispuEligible) _buildPickupInfo(store),
          if (otherStoresCount > 0) _buildOtherStoresLink(context, otherStoresCount),
          const SizedBox(height: 14),
          _buildActions(context, store),
        ],
      ),
    );
  }

  Widget _buildHeader(StoreAvailability store) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.store, color: AppColors.primaryBlue, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Nearest Store with Stock',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              Text(store.name ?? 'Best Buy',
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
        ),
        if (store.distance != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.accentYellow.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.directions_car_outlined, size: 14, color: AppColors.accentYellow),
                const SizedBox(width: 4),
                Text(store.distanceFormatted ?? '',
                    style: const TextStyle(
                        color: AppColors.accentYellow, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildAddress(StoreAvailability store) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.location_on_outlined,
            size: 16, color: AppColors.textSecondary.withValues(alpha: 0.7)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(store.fullAddress,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13, height: 1.4)),
        ),
      ],
    );
  }

  Widget _buildLowStockWarning() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.accentYellow.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.warning_amber_rounded, size: 14, color: AppColors.accentYellow),
            SizedBox(width: 6),
            Text('Low Stock - Act Fast!',
                style: TextStyle(
                    color: AppColors.accentYellow, fontWeight: FontWeight.w600, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildPickupInfo(StoreAvailability store) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Icon(Icons.check_circle, size: 14, color: AppColors.success.withValues(alpha: 0.8)),
          const SizedBox(width: 6),
          Text(
            store.minPickupHours != null
                ? 'Ready for pickup in ${store.minPickupHours}+ hours'
                : 'Eligible for in-store pickup',
            style: const TextStyle(color: AppColors.success, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildOtherStoresLink(BuildContext context, int count) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        children: [
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => _showAllStores(context),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Text('+$count more store${count == 1 ? '' : 's'} nearby',
                      style: const TextStyle(
                          color: AppColors.primaryBlue, fontWeight: FontWeight.w600, fontSize: 13)),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, size: 18, color: AppColors.primaryBlue),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, StoreAvailability store) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _openDirections(store),
            icon: const Icon(Icons.directions, size: 18),
            label: const Text('Directions'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryBlue,
              side: const BorderSide(color: AppColors.primaryBlue),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showPostalCodeDialog(context),
            icon: const Icon(Icons.search, size: 18),
            label: const Text('Change Location'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.border),
              padding: const EdgeInsets.symmetric(vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),
      ],
    );
  }

  void _showAllStores(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.store, color: AppColors.primaryBlue),
                  const SizedBox(width: 12),
                  Text('${availability.stores.length} Stores with Stock',
                      style: const TextStyle(
                          color: AppColors.textPrimary, fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
            ),
            const Divider(color: AppColors.border, height: 1),
            Expanded(
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: availability.stores.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final store = availability.stores[index];
                  return _StoreListItem(store: store, isNearest: index == 0);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPostalCodeDialog(BuildContext context) {
    final controller = TextEditingController(text: userPostalCode);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Enter ZIP Code', style: TextStyle(color: AppColors.textPrimary)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 5,
          autofocus: true,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 20, letterSpacing: 4),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: '12345',
            hintStyle: TextStyle(
                color: AppColors.textSecondary.withValues(alpha: 0.5), letterSpacing: 4),
            counterText: '',
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            filled: true,
            fillColor: AppColors.surfaceVariant,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (controller.text.length == 5) onSearchByPostalCode(controller.text);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue),
            child: const Text('Search', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _openDirections(StoreAvailability store) async {
    final address = Uri.encodeComponent(store.fullAddress);
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$address';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

class _StoreListItem extends StatelessWidget {
  const _StoreListItem({required this.store, required this.isNearest});

  final StoreAvailability store;
  final bool isNearest;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isNearest ? AppColors.primaryBlue.withValues(alpha: 0.1) : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isNearest ? AppColors.primaryBlue.withValues(alpha: 0.3) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(store.name ?? 'Best Buy',
                        style: const TextStyle(
                            color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
                    if (isNearest) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('NEAREST',
                            style: TextStyle(
                                color: Colors.white, fontWeight: FontWeight.bold, fontSize: 9)),
                      ),
                    ],
                    if (store.lowStock) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.accentYellow.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text('LOW STOCK',
                            style: TextStyle(
                                color: AppColors.accentYellow,
                                fontWeight: FontWeight.bold,
                                fontSize: 9)),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(store.fullAddress,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (store.distance != null)
                Text(store.distanceFormatted ?? '',
                    style: const TextStyle(
                        color: AppColors.accentYellow, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 6),
              InkWell(
                onTap: () => _openDirections(store),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.directions, size: 14, color: AppColors.primaryBlue),
                      SizedBox(width: 4),
                      Text('Go',
                          style: TextStyle(
                              color: AppColors.primaryBlue, fontWeight: FontWeight.w600, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openDirections(StoreAvailability store) async {
    final address = Uri.encodeComponent(store.fullAddress);
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$address';
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
