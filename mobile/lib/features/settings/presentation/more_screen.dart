import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers/app_providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/widgets/action_buttons.dart';
import '../../../app/widgets/brand_logo.dart';
import '../../../core/l10n/app_localizations.dart';
import '../../../core/sync/app_sync_controller.dart';

class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});

  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen> {
  Future<void> _onSyncNow() async {
    final controller = ref.read(appSyncControllerProvider);
    if (!controller.isAuthenticated) {
      context.go('/signin');
      return;
    }
    await controller.synchronize();
  }

  Future<void> _onLogout() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.logoutConfirmTitle),
        content: Text(l10n.logoutConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.logout),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await ref.read(appSyncControllerProvider).logout();
    await clearActiveSession(ref);
    if (mounted) {
      context.go('/signin');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final shopName = ref.watch(shopNameProvider);
    final deviceId = ref.watch(deviceIdProvider);
    final currentLocale = ref.watch(localeProvider);
    final syncController = ref.watch(appSyncControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(l10n.more), automaticallyImplyLeading: false),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Shop Profile Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const AstawashBrandLogo(
                      size: 40,
                      color: AppColors.primary,
                      showBadgeBackground: true,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shopName.isNotEmpty
                                ? shopName
                                : l10n.defaultShopName,
                            style: AppTypography.h3,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${l10n.deviceIdLabel}: ${deviceId.substring(0, deviceId.length > 18 ? 18 : deviceId.length)}',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Language Selector Card
              Text(l10n.languageSetting, style: AppTypography.h3),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    InkWell(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(16),
                      ),
                      onTap: () => ref
                          .read(localeProvider.notifier)
                          .setLocale(const Locale('en')),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.languageEnglish,
                              style: AppTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Icon(
                              currentLocale.languageCode == 'en'
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: currentLocale.languageCode == 'en'
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    InkWell(
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(16),
                      ),
                      onTap: () => ref
                          .read(localeProvider.notifier)
                          .setLocale(const Locale('am')),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.languageAmharic,
                              style: AppTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Icon(
                              currentLocale.languageCode == 'am'
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: currentLocale.languageCode == 'am'
                                  ? AppColors.primary
                                  : AppColors.textMuted,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Offline & Synchronization Card
              Text(l10n.offlineAndSync, style: AppTypography.h3),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: AnimatedBuilder(
                  animation: syncController,
                  builder: (context, _) {
                    final statusText = switch (syncController.status) {
                      AppSyncStatus.idle =>
                        syncController.isAuthenticated
                            ? l10n.syncIdle
                            : l10n.authenticationRequired,
                      AppSyncStatus.syncing => l10n.syncInProgress,
                      AppSyncStatus.success => l10n.syncSuccess,
                      AppSyncStatus.failure =>
                        syncController.isAuthenticated
                            ? l10n.syncFailed
                            : l10n.authenticationFailed,
                    };
                    final statusColor =
                        syncController.status == AppSyncStatus.failure
                        ? Theme.of(context).colorScheme.error
                        : AppColors.primary;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: statusColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                statusText,
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (syncController.errorMessage
                            case final message?) ...[
                          const SizedBox(height: 8),
                          SelectableText(
                            message,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                        if (syncController.lastReport case final report?
                            when syncController.status ==
                                AppSyncStatus.success) ...[
                          const SizedBox(height: 8),
                          Text(
                            l10n.syncResult(
                              report.customersPushed,
                              report.entriesPushed,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        AstawashSecondaryButton(
                          label: l10n.syncNow,
                          isLoading:
                              syncController.status == AppSyncStatus.syncing,
                          icon: const Icon(Icons.sync_rounded, size: 20),
                          onPressed: _onSyncNow,
                        ),
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // About Section
              Text(l10n.aboutAstawash, style: AppTypography.h3),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.appTitle,
                      style: AppTypography.h2.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.appVersion,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      l10n.appDescription,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Logout Button
              AstawashSecondaryButton(
                label: l10n.logout,
                icon: const Icon(
                  Icons.logout_rounded,
                  size: 20,
                  color: AppColors.error,
                ),
                onPressed: _onLogout,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
