import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';

class AuthBrandMark extends StatelessWidget {
  const AuthBrandMark({super.key, this.centered = false});

  final bool centered;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final text = AppColors.primaryText(brightness);

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.asset(
            'web/icons/Icon-512.png',
            key: const ValueKey('folego-brand-icon'),
            width: 38,
            height: 38,
            filterQuality: FilterQuality.high,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          'Fôlego',
          style: AppTypography.section(context, fontSize: 20, color: text),
        ),
      ],
    );

    if (!centered) return content;
    return Center(child: content);
  }
}

class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.focusNode,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.validator,
    this.onFieldSubmitted,
    this.obscureText = false,
    this.onToggleObscure,
    this.enabled = true,
    this.textCapitalization = TextCapitalization.none,
    this.autocorrect = true,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final FocusNode? focusNode;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final String? Function(String?)? validator;
  final ValueChanged<String>? onFieldSubmitted;
  final bool obscureText;
  final VoidCallback? onToggleObscure;
  final bool enabled;
  final TextCapitalization textCapitalization;
  final bool autocorrect;

  @override
  Widget build(BuildContext context) {
    final suffix = onToggleObscure == null
        ? null
        : IconButton(
            tooltip: obscureText ? 'Mostrar senha' : 'Ocultar senha',
            onPressed: enabled ? onToggleObscure : null,
            icon: Icon(obscureText ? AppIcons.eye : AppIcons.eyeOff),
          );

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      autofillHints: autofillHints,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      obscureText: obscureText,
      enabled: enabled,
      textCapitalization: textCapitalization,
      autocorrect: autocorrect,
      enableSuggestions: !obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        suffixIcon: suffix,
      ),
    );
  }
}

class AuthSubmitButton extends StatelessWidget {
  const AuthSubmitButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: FilledButton(
        onPressed: loading ? null : onPressed,
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 160),
          child: loading
              ? Row(
                  key: const ValueKey('loading'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Text(label),
                  ],
                )
              : Text(label, key: const ValueKey('idle')),
        ),
      ),
    );
  }
}

class AuthErrorMessage extends StatelessWidget {
  const AuthErrorMessage({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brightness = theme.brightness;
    final error = theme.colorScheme.error;
    final border = AppColors.border(brightness);
    final background = AppColors.surface(brightness);

    return Semantics(
      liveRegion: true,
      label: message,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadii.control),
          border: Border.all(color: border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(AppIcons.warning, size: 18, color: error),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: AppTypography.body(context, fontSize: 13, color: error),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AuthModeSwitch extends StatelessWidget {
  const AuthModeSwitch({
    super.key,
    required this.isSignUp,
    required this.onPressed,
    this.enabled = true,
  });

  final bool isSignUp;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final secondary = AppColors.secondaryText(brightness);

    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 2,
      children: [
        Text(
          isSignUp ? 'Já tem conta?' : 'Ainda não tem conta?',
          style: AppTypography.body(context, fontSize: 13, color: secondary),
        ),
        TextButton(
          onPressed: enabled ? onPressed : null,
          child: Text(isSignUp ? 'Entrar' : 'Criar conta'),
        ),
      ],
    );
  }
}

class AuthSuccessMessage extends StatelessWidget {
  const AuthSuccessMessage({
    super.key,
    required this.title,
    required this.body,
    this.detail,
  });

  final String title;
  final String body;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final purple = AppColors.primaryPurple(brightness);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: purple.withValues(alpha: .12),
            borderRadius: BorderRadius.circular(AppRadii.compactCard),
          ),
          child: Icon(AppIcons.check, color: purple),
        ),
        const SizedBox(height: 22),
        Text(
          title,
          style: AppTypography.section(context, fontSize: 22, color: primary),
        ),
        const SizedBox(height: 10),
        Text(
          body,
          style: AppTypography.body(context, fontSize: 14, color: secondary),
        ),
        if (detail != null) ...[
          const SizedBox(height: 8),
          SelectableText(
            detail!,
            style: AppTypography.body(
              context,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: primary,
            ),
          ),
        ],
      ],
    );
  }
}
