import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/layout/app_content_container.dart';
import '../../core/preferences/app_preferences.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/error_translator.dart';
import 'auth_validation.dart';
import 'auth_widgets.dart';

enum _AuthView { login, signUp, recovery, checkEmail, recoverySent }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.client});

  final SupabaseClient client;

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _confirmEmailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _firstNameFocus = FocusNode();
  final _lastNameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _confirmEmailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  _AuthView _view = _AuthView.login;
  bool _loading = false;
  bool _resending = false;
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  bool _rememberMe = false;
  String? _error;
  String? _pendingEmail;

  bool get _isSignUp => _view == _AuthView.signUp;

  String get _authRedirectUrl {
    final base = Uri.base;
    return base.replace(query: '', fragment: '').toString();
  }

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
  }

  Future<void> _loadRememberedEmail() async {
    final email = await AppPreferences.loadRememberedEmail();
    if (!mounted || email == null) return;
    setState(() {
      _emailController.text = email;
      _rememberMe = true;
    });
  }

  void _setRememberMe(bool value) {
    setState(() => _rememberMe = value);
    if (!value) {
      AppPreferences.setRememberedEmail(null);
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _confirmEmailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameFocus.dispose();
    _lastNameFocus.dispose();
    _emailFocus.dispose();
    _confirmEmailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  void _changeView(_AuthView view) {
    if (_loading || _resending) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _view = view;
      _error = null;
      _obscurePassword = true;
      _obscureConfirmation = true;
    });
  }

  Future<void> _submit() async {
    if (_loading ||
        _view == _AuthView.checkEmail ||
        _view == _AuthView.recoverySent) {
      return;
    }

    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final email = _emailController.text.trim();

      switch (_view) {
        case _AuthView.login:
          await widget.client.auth.signInWithPassword(
            email: email,
            password: _passwordController.text,
          );
          await AppPreferences.setRememberedEmail(
            _rememberMe ? email : null,
          );
          TextInput.finishAutofillContext(shouldSave: _rememberMe);
          break;
        case _AuthView.signUp:
          final fullName = AuthValidation.fullName(
            _firstNameController.text,
            _lastNameController.text,
          );
          final response = await widget.client.auth.signUp(
            email: email,
            password: _passwordController.text,
            data: {'full_name': fullName},
            emailRedirectTo: _authRedirectUrl,
          );
          TextInput.finishAutofillContext(shouldSave: true);
          if (!mounted) return;
          if (response.session == null) {
            setState(() {
              _pendingEmail = email;
              _view = _AuthView.checkEmail;
            });
          }
          break;
        case _AuthView.recovery:
          await widget.client.auth.resetPasswordForEmail(
            email,
            redirectTo: _authRedirectUrl,
          );
          if (!mounted) return;
          setState(() {
            _pendingEmail = email;
            _view = _AuthView.recoverySent;
          });
          break;
        case _AuthView.checkEmail:
        case _AuthView.recoverySent:
          break;
      }
    } catch (error, stackTrace) {
      debugPrint('Auth action failed: $error\n$stackTrace');
      if (!mounted) return;
      final emailNotConfirmed = error is AuthException &&
          error.message.toLowerCase().contains('email not confirmed');
      if (_view == _AuthView.login && emailNotConfirmed) {
        setState(() {
          _pendingEmail = _emailController.text.trim();
          _view = _AuthView.checkEmail;
          _error = null;
        });
      } else {
        setState(() => _error = ErrorTranslator.forDisplay(error));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resendConfirmation() async {
    final email = _pendingEmail;
    if (_resending || email == null || email.isEmpty) return;

    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      await widget.client.auth.resend(
        type: OtpType.signup,
        email: email,
        emailRedirectTo: _authRedirectUrl,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Novo e-mail de confirmação enviado.')),
      );
    } catch (error, stackTrace) {
      debugPrint('Auth resend failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() => _error = ErrorTranslator.forDisplay(error));
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _backToLogin({bool keepEmail = true}) {
    if (!keepEmail) _emailController.clear();
    _passwordController.clear();
    _confirmPasswordController.clear();
    _confirmEmailController.clear();
    _changeView(_AuthView.login);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = AppBreakpoints.fromWidth(constraints.maxWidth);
            final desktop = size == AppLayoutSize.expanded ||
                size == AppLayoutSize.wide;
            if (desktop) return _buildDesktop(context);
            return _buildCompact(context);
          },
        ),
      ),
    );
  }

  Widget _buildCompact(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return AppContentContainer.auth(
      fillHeight: true,
      verticalPadding: 24,
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: EdgeInsets.only(bottom: bottomInset),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AuthBrandMark(centered: true),
            const SizedBox(height: 28),
            _CompactIntro(view: _view),
            const SizedBox(height: 28),
            _buildAuthContent(context),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktop(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final background = AppColors.background(brightness);
    final surface = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Row(
      children: [
        Expanded(
          child: Container(
            color: background,
            padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 44),
            child: const _DesktopBrandPanel(),
          ),
        ),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: surface,
              border: Border(left: BorderSide(color: border)),
            ),
            child: AppContentContainer.auth(
              fillHeight: true,
              alignment: Alignment.center,
              verticalPadding: 32,
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.only(bottom: bottomInset),
                child: _buildAuthContent(context),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAuthContent(BuildContext context) {
    switch (_view) {
      case _AuthView.checkEmail:
        return _buildCheckEmail(context);
      case _AuthView.recoverySent:
        return _buildRecoverySent(context);
      case _AuthView.login:
      case _AuthView.signUp:
      case _AuthView.recovery:
        return _buildForm(context);
    }
  }

  Widget _buildForm(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);

    final title = switch (_view) {
      _AuthView.login => 'Bom te ver de novo.',
      _AuthView.signUp => 'Crie seu espaço.',
      _AuthView.recovery => 'Recupere seu acesso.',
      _ => '',
    };
    final subtitle = switch (_view) {
      _AuthView.login => 'Entre para continuar seu diário financeiro.',
      _AuthView.signUp => 'Poucos dados. O resto a gente organiza depois.',
      _AuthView.recovery => 'Informe seu e-mail para receber as instruções.',
      _ => '',
    };

    return AutofillGroup(
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: AppTypography.section(
                context,
                fontSize: 24,
                color: primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: AppTypography.body(
                context,
                fontSize: 14,
                color: secondary,
              ),
            ),
            const SizedBox(height: 24),
            if (_isSignUp) ...[
              AuthTextField(
                controller: _firstNameController,
                label: 'Nome',
                focusNode: _firstNameFocus,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.givenName],
                validator: AuthValidation.firstName,
                onFieldSubmitted: (_) => _lastNameFocus.requestFocus(),
                enabled: !_loading,
              ),
              const SizedBox(height: 12),
              AuthTextField(
                controller: _lastNameController,
                label: 'Sobrenome',
                focusNode: _lastNameFocus,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.familyName],
                validator: AuthValidation.lastName,
                onFieldSubmitted: (_) => _emailFocus.requestFocus(),
                enabled: !_loading,
              ),
              const SizedBox(height: 12),
            ],
            AuthTextField(
              controller: _emailController,
              label: 'E-mail',
              focusNode: _emailFocus,
              keyboardType: TextInputType.emailAddress,
              textInputAction: _view == _AuthView.recovery
                  ? TextInputAction.done
                  : TextInputAction.next,
              autofillHints: _view == _AuthView.login
                  ? const [AutofillHints.username, AutofillHints.email]
                  : const [AutofillHints.email],
              validator: AuthValidation.email,
              onFieldSubmitted: (_) {
                if (_view == _AuthView.recovery) {
                  _submit();
                } else if (_isSignUp) {
                  _confirmEmailFocus.requestFocus();
                } else {
                  _passwordFocus.requestFocus();
                }
              },
              autocorrect: false,
              enabled: !_loading,
            ),
            if (_isSignUp) ...[
              const SizedBox(height: 12),
              AuthTextField(
                controller: _confirmEmailController,
                label: 'Confirmar e-mail',
                focusNode: _confirmEmailFocus,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (value) => AuthValidation.emailConfirmation(
                  value,
                  _emailController.text,
                ),
                onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                autocorrect: false,
                enabled: !_loading,
              ),
            ],
            if (_view != _AuthView.recovery) ...[
              const SizedBox(height: 12),
              AuthTextField(
                controller: _passwordController,
                label: 'Senha',
                hint: _isSignUp ? 'Pelo menos 6 caracteres' : null,
                focusNode: _passwordFocus,
                textInputAction: _isSignUp
                    ? TextInputAction.next
                    : TextInputAction.done,
                autofillHints: _isSignUp
                    ? const [AutofillHints.newPassword]
                    : const [AutofillHints.password],
                validator: (value) => AuthValidation.password(
                  value,
                  enforceMinimum: _isSignUp,
                ),
                onFieldSubmitted: (_) {
                  if (_isSignUp) {
                    _confirmPasswordFocus.requestFocus();
                  } else {
                    _submit();
                  }
                },
                obscureText: _obscurePassword,
                onToggleObscure: () => setState(
                  () => _obscurePassword = !_obscurePassword,
                ),
                autocorrect: false,
                enabled: !_loading,
              ),
            ],
            if (_isSignUp) ...[
              const SizedBox(height: 12),
              AuthTextField(
                controller: _confirmPasswordController,
                label: 'Confirmar senha',
                focusNode: _confirmPasswordFocus,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                validator: (value) => AuthValidation.passwordConfirmation(
                  value,
                  _passwordController.text,
                ),
                onFieldSubmitted: (_) => _submit(),
                obscureText: _obscureConfirmation,
                onToggleObscure: () => setState(
                  () => _obscureConfirmation = !_obscureConfirmation,
                ),
                autocorrect: false,
                enabled: !_loading,
              ),
            ],
            if (_view == _AuthView.login) ...[
              Row(
                children: [
                  Checkbox(
                    key: const ValueKey('auth-remember-me'),
                    value: _rememberMe,
                    onChanged: _loading
                        ? null
                        : (value) => _setRememberMe(value ?? false),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: _loading
                          ? null
                          : () => _setRememberMe(!_rememberMe),
                      child: Text(
                        'lembrar usuário e senha',
                        style: AppTypography.body(
                          context,
                          fontSize: 12,
                          color: secondary,
                        ),
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => _changeView(_AuthView.recovery),
                    child: const Text('Esqueci minha senha'),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 6),
                child: Text(
                  'o Fôlego guarda seu e-mail; a senha fica com o iPhone ou navegador',
                  style: AppTypography.label(
                    context,
                    fontSize: 9,
                    color: secondary,
                  ),
                ),
              ),
            ] else
              const SizedBox(height: 18),
            if (_error != null) ...[
              AuthErrorMessage(message: _error!),
              const SizedBox(height: 14),
            ],
            AuthSubmitButton(
              label: switch (_view) {
                _AuthView.login => _loading ? 'Entrando...' : 'Entrar',
                _AuthView.signUp => _loading ? 'Criando...' : 'Criar conta',
                _AuthView.recovery =>
                  _loading ? 'Enviando...' : 'Enviar instruções',
                _ => '',
              },
              loading: _loading,
              onPressed: _submit,
            ),
            const SizedBox(height: 10),
            if (_view == _AuthView.recovery)
              TextButton(
                onPressed: _loading ? null : () => _backToLogin(),
                child: const Text('Voltar para entrar'),
              )
            else
              AuthModeSwitch(
                isSignUp: _isSignUp,
                enabled: !_loading,
                onPressed: () => _changeView(
                  _isSignUp ? _AuthView.login : _AuthView.signUp,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckEmail(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthSuccessMessage(
          title: 'Confira seu e-mail.',
          body: 'Enviamos uma confirmação para:',
          detail: _pendingEmail,
        ),
        const SizedBox(height: 24),
        if (_error != null) ...[
          AuthErrorMessage(message: _error!),
          const SizedBox(height: 14),
        ],
        OutlinedButton(
          onPressed: _resending ? null : _resendConfirmation,
          child: Text(_resending ? 'Reenviando...' : 'Reenviar e-mail'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _resending
              ? null
              : () {
                  _confirmEmailController.clear();
                  _passwordController.clear();
                  _confirmPasswordController.clear();
                  _changeView(_AuthView.signUp);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _emailFocus.requestFocus();
                  });
                },
          child: const Text('Usei o e-mail errado'),
        ),
        TextButton(
          onPressed: _resending ? null : () => _backToLogin(),
          child: const Text('Voltar para entrar'),
        ),
      ],
    );
  }

  Widget _buildRecoverySent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthSuccessMessage(
          title: 'Dá uma olhada no e-mail.',
          body:
              'Se esse e-mail estiver cadastrado, você receberá as instruções.',
          detail: _pendingEmail,
        ),
        const SizedBox(height: 24),
        TextButton(
          onPressed: () => _backToLogin(),
          child: const Text('Voltar para entrar'),
        ),
      ],
    );
  }
}

class _CompactIntro extends StatelessWidget {
  const _CompactIntro({required this.view});

  final _AuthView view;

  @override
  Widget build(BuildContext context) {
    if (view == _AuthView.checkEmail || view == _AuthView.recoverySent) {
      return const SizedBox.shrink();
    }
    final brightness = Theme.of(context).brightness;
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);

    return Column(
      children: [
        Text(
          'Seu saldo não é o que você pode gastar.',
          textAlign: TextAlign.center,
          style: AppTypography.section(
            context,
            fontSize: 19,
            color: primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Um diário financeiro simples pra dar mais espaço às suas escolhas.',
          textAlign: TextAlign.center,
          style: AppTypography.body(
            context,
            fontSize: 13,
            color: secondary,
          ),
        ),
      ],
    );
  }
}

class _DesktopBrandPanel extends StatelessWidget {
  const _DesktopBrandPanel();

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final purple = AppColors.primaryPurple(brightness);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AuthBrandMark(),
        const Spacer(),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Text(
            'Seu saldo não é o que\nvocê pode gastar.',
            style: AppTypography.display(
              context,
              fontSize: 42,
              color: primary,
            ),
          ),
        ),
        const SizedBox(height: 18),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Text(
            'Um diário financeiro simples pra dar mais espaço às suas escolhas.',
            style: AppTypography.body(
              context,
              fontSize: 16,
              color: secondary,
            ),
          ),
        ),
        const SizedBox(height: 34),
        Row(
          children: [
            Container(
              width: 94,
              height: 12,
              decoration: BoxDecoration(
                color: purple,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 52,
              height: 12,
              decoration: BoxDecoration(
                color: AppColors.lime,
                borderRadius: BorderRadius.circular(AppRadii.pill),
              ),
            ),
          ],
        ),
        const Spacer(),
      ],
    );
  }
}
