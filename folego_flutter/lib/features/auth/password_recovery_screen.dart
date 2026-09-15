import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/layout/app_content_container.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/error_translator.dart';
import 'auth_validation.dart';
import 'auth_widgets.dart';

class PasswordRecoveryScreen extends StatefulWidget {
  const PasswordRecoveryScreen({super.key, required this.client});

  final SupabaseClient client;

  @override
  State<PasswordRecoveryScreen> createState() =>
      _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState extends State<PasswordRecoveryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  final _passwordFocus = FocusNode();
  final _confirmationFocus = FocusNode();

  bool _loading = false;
  bool _signingOut = false;
  bool _success = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    _passwordFocus.dispose();
    _confirmationFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading || _success) return;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.client.auth.updateUser(
        UserAttributes(password: _passwordController.text),
      );
      if (!mounted) return;
      setState(() => _success = true);
    } catch (error, stackTrace) {
      debugPrint('Password recovery update failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() => _error = ErrorTranslator.forDisplay(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _returnToLogin() async {
    if (_signingOut) return;
    setState(() {
      _signingOut = true;
      _error = null;
    });
    try {
      await widget.client.auth.signOut();
    } catch (error, stackTrace) {
      debugPrint('Password recovery sign out failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() => _error = ErrorTranslator.forDisplay(error));
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      body: SafeArea(
        child: AppContentContainer.auth(
          fillHeight: true,
          verticalPadding: 24,
          alignment: Alignment.center,
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.only(bottom: bottomInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AuthBrandMark(centered: true),
                const SizedBox(height: 36),
                if (_success) ...[
                  const AuthSuccessMessage(
                    title: 'Senha atualizada.',
                    body: 'Agora entre de novo com sua nova senha.',
                  ),
                  const SizedBox(height: 24),
                  if (_error != null) ...[
                    AuthErrorMessage(message: _error!),
                    const SizedBox(height: 14),
                  ],
                  AuthSubmitButton(
                    label: _signingOut ? 'Voltando...' : 'Voltar para entrar',
                    loading: _signingOut,
                    onPressed: _returnToLogin,
                  ),
                ] else ...[
                  Text(
                    'Crie uma nova senha.',
                    style: AppTypography.section(
                      context,
                      fontSize: 24,
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Use pelo menos ${AuthValidation.minimumPasswordLength} caracteres.',
                    style: AppTypography.body(
                      context,
                      fontSize: 14,
                      color: secondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  AutofillGroup(
                    child: Form(
                      key: _formKey,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AuthTextField(
                            controller: _passwordController,
                            label: 'Nova senha',
                            focusNode: _passwordFocus,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.newPassword],
                            validator: (value) => AuthValidation.password(
                              value,
                              enforceMinimum: true,
                            ),
                            onFieldSubmitted: (_) =>
                                _confirmationFocus.requestFocus(),
                            obscureText: _obscurePassword,
                            onToggleObscure: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            autocorrect: false,
                            enabled: !_loading,
                          ),
                          const SizedBox(height: 12),
                          AuthTextField(
                            controller: _confirmationController,
                            label: 'Confirmar nova senha',
                            focusNode: _confirmationFocus,
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.newPassword],
                            validator: (value) =>
                                AuthValidation.passwordConfirmation(
                              value,
                              _passwordController.text,
                            ),
                            onFieldSubmitted: (_) => _submit(),
                            obscureText: _obscureConfirmation,
                            onToggleObscure: () => setState(
                              () => _obscureConfirmation =
                                  !_obscureConfirmation,
                            ),
                            autocorrect: false,
                            enabled: !_loading,
                          ),
                          const SizedBox(height: 18),
                          if (_error != null) ...[
                            AuthErrorMessage(message: _error!),
                            const SizedBox(height: 14),
                          ],
                          AuthSubmitButton(
                            label: _loading
                                ? 'Salvando...'
                                : 'Salvar nova senha',
                            loading: _loading,
                            onPressed: _submit,
                          ),
                        ],
                      ),
                    ),
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
