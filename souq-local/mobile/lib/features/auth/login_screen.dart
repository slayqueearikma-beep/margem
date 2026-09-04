import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/validation/form_validators.dart';
import '../../core/services/api_service.dart';
import '../../core/services/app_storage.dart';
import '../../core/services/auth_service.dart';
import '../../core/auth/auth_session_completion.dart';
import '../../core/auth/google_auth_flow.dart';
import '../../core/models/auth_models.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/theme/theme_context.dart';
import '../../core/widgets/app_brand_logo.dart';
import '../../core/widgets/app_buttons.dart';
import '../../core/widgets/error_dialog.dart';
import '../../core/widgets/google_sign_in_button.dart';
import '../../core/widgets/margem_background.dart';
import '../../features/legal/auth_legal_footer.dart';
import '../../l10n/app_localizations.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _loading = false;
  bool _googleLoading = false;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _loginErrorMessage(ApiException error, AppStrings l10n) {
    final message = error.message.trim();
    final lower = message.toLowerCase();
    if (error.statusCode == 401 ||
        lower.contains('invalid email or password')) {
      return l10n.invalidCredentials;
    }
    if (error.statusCode == 422 ||
        lower.contains('valid email') ||
        lower.contains('invalid email')) {
      return l10n.invalidEmailFormat;
    }
    if (message.isNotEmpty) return message;
    return l10n.somethingWentWrong;
  }

  Future<void> _login() async {
    final l10n = context.l10n;
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.enterEmailPassword)));
      return;
    }
    if (!FormValidators.isValidEmail(email)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.invalidEmailFormat)));
      return;
    }

    setState(() => _loading = true);
    try {
      await apiServiceProvider.runSubmit(() async {
        await apiServiceProvider.checkHealth();

        final auth = ref.read(authServiceProvider);
        AuthSession session;
        try {
          session = await auth.login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
        } on MfaRequiredException catch (mfa) {
          if (!mounted) return;
          if (mfa.mfaToken.isEmpty) {
            throw ApiException('Two-factor authentication is required.');
          }
          final code = await _promptMfaCode();
          if (code == null || code.isEmpty) return;
          session = await auth.completeMfaLogin(
            mfaToken: mfa.mfaToken,
            code: code,
          );
        }

        await _completeLogin(session);
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      final message = _loginErrorMessage(e, l10n);
      await showAppErrorDialog(context,
          title: l10n.somethingWentWrong, message: message);
    } catch (e) {
      if (!mounted) return;
      await showAppErrorDialog(context,
          title: l10n.somethingWentWrong, message: l10n.serverUnreachable);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<String?> _promptMfaCode() async {
    final l10n = context.l10n;
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(l10n.twoFactorAuthTitle),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: l10n.twoFactorAuthCodeLabel,
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(l10n.signupOtpVerify),
          ),
        ],
      ),
    );
    controller.dispose();
    return code;
  }

  Future<void> _completeLogin(AuthSession session) async {
    await completeAuthenticatedSessionFromContext(
      ref: ref,
      context: context,
      session: session,
    );
  }

  Future<void> _signInWithGoogle() async {
    if (_loading || _googleLoading) return;
    setState(() => _googleLoading = true);
    try {
      await GoogleAuthFlow.start(context: context, ref: ref);
    } finally {
      if (mounted) setState(() => _googleLoading = false);
    }
  }

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      suffixIcon: suffix,
      filled: true,
      fillColor: context.colors.surfaceVariant.withValues(alpha: 0.65),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: context.colors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: context.colors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: context.colors.primary, width: 1.4),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: MargemBackground(
        child: SafeArea(
          child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            0,
            AppSpacing.screenHorizontal,
            AppSpacing.lg + bottomInset,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppBrandHeader(
                tier: AppLogoTier.header,
                title: l10n.welcomeBack,
                subtitle: l10n.loginSubtitle,
                includeTopSpacing: true,
                titleStyle: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
              ),
              SizedBox(height: AppSpacing.xl),
              GoogleSignInButton(
                onPressed: (_loading || _googleLoading) ? null : _signInWithGoogle,
                isLoading: _googleLoading,
              ),
              const AuthDivider(),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: [
                  AutofillHints.username,
                  AutofillHints.email
                ],
                decoration: _fieldDecoration(
                  label: l10n.email,
                  icon: Icons.email_outlined,
                ),
              ),
              SizedBox(height: AppSpacing.md),
              TextField(
                controller: _passwordController,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                autofillHints: [AutofillHints.password],
                onSubmitted: (_) => _login(),
                decoration: _fieldDecoration(
                  label: l10n.password,
                  icon: Icons.lock_outline,
                  suffix: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  onPressed: () => context.push('/forgot-password'),
                  style: TextButton.styleFrom(
                    foregroundColor: context.colors.textSecondary,
                    padding: EdgeInsets.symmetric(horizontal: 4),
                  ),
                  child: Text(l10n.forgotPassword),
                ),
              ),
              SizedBox(height: AppSpacing.md),
              PrimaryButton(
                label: l10n.logIn,
                onPressed: _login,
                isLoading: _loading,
              ),
              SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => context.push('/onboarding/account-type'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: context.colors.primary,
                    side:
                        BorderSide(color: context.colors.primary, width: 1.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  child: Text(l10n.createAccount),
                ),
              ),
              SizedBox(height: AppSpacing.sm),
              TextButton(
                onPressed: _continueAsGuest,
                child: Text(
                  l10n.guestContinue,
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const AuthLegalFooter(),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Future<void> _continueAsGuest() async {
    final storage = ref.read(appStorageProvider);
    if (storage == null) return;
    await storage.completeOnboarding();
    await storage.saveGuestSession(city: AppConfig.launchCity);
    ref.read(userSessionProvider.notifier).state = storage.getSession();
    if (mounted) context.go('/buyer/home');
  }
}
