import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/providers/app_providers.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_typography.dart';
import '../../../app/widgets/action_buttons.dart';
import '../../../app/widgets/brand_logo.dart';
import '../../../core/l10n/app_localizations.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();
  final _shopNameController = TextEditingController();
  bool _isLoading = false;
  bool _isRegistering = false;
  String? _localErrorMessage;

  Future<void> _onAuthenticate() async {
    if (!(_formKey.currentState?.validate() ?? false) || _isLoading) return;
    setState(() {
      _isLoading = true;
      _localErrorMessage = null;
    });
    final controller = ref.read(appSyncControllerProvider);
    try {
      if (_isRegistering) {
        await controller.register(
          phone: _phoneController.text.trim(),
          pin: _pinController.text,
          shopName: _shopNameController.text.trim().isEmpty
              ? null
              : _shopNameController.text.trim(),
        );
      } else {
        await controller.login(
          phone: _phoneController.text.trim(),
          pin: _pinController.text,
        );
      }
      if (!mounted) return;
      if (controller.isAuthenticated) {
        await persistActiveShopId(ref, controller.shopId);
        final tokenStore = ref.read(backendApiClientProvider).tokenStore;
        if (_isRegistering) {
          final registeredName = _shopNameController.text.trim().isNotEmpty
              ? _shopNameController.text.trim()
              : '';
          await tokenStore.saveShopName(registeredName);
          ref.read(shopNameProvider.notifier).setShopName(registeredName);
        } else {
          final savedName = await tokenStore.readShopName();
          if (savedName != null && savedName.isNotEmpty) {
            ref.read(shopNameProvider.notifier).setShopName(savedName);
          }
        }
        if (mounted) context.go('/dashboard');
      }
    } catch (error) {
      _localErrorMessage = error.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _pinController.dispose();
    _shopNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = ref.watch(appSyncControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 24),
                Center(
                  child: Column(
                    children: [
                      const AstawashBrandLogo(
                        size: 56,
                        color: AppColors.primary,
                        showBadgeBackground: true,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        l10n.welcomeBack,
                        style: AppTypography.h1,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.signInSubtitle,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 36),
                Text(
                  l10n.phoneNumber,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: InputDecoration(
                    hintText: l10n.phoneHint,
                    prefixIcon: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: const BoxDecoration(
                        border: Border(
                          right: BorderSide(color: AppColors.border),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '+251',
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length < 9) {
                      return l10n.enterValidPhone;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                Text(
                  l10n.pin,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _pinController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  obscuringCharacter: '•',
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: InputDecoration(
                    hintText: l10n.pinHint,
                    prefixIcon: const Icon(
                      Icons.lock_outline_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().length != 4) {
                      return l10n.enterValidPin;
                    }
                    return null;
                  },
                ),
                if (_isRegistering) ...[
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _shopNameController,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(labelText: l10n.shopNameLabel),
                  ),
                ],
                const SizedBox(height: 32),
                AstawashPrimaryButton(
                  label: _isRegistering ? l10n.registerButton : l10n.signIn,
                  isLoading: _isLoading,
                  onPressed: _onAuthenticate,
                ),
                if (!_isRegistering) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => setState(() => _isRegistering = true),
                    child: Text(l10n.registerButton),
                  ),
                ] else ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => setState(() => _isRegistering = false),
                    child: Text(l10n.loginButton),
                  ),
                ],
                if (_localErrorMessage != null ||
                    controller.errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _localErrorMessage ?? controller.errorMessage!,
                    style: TextStyle(color: AppColors.error),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
