import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Standard labeled text field ("COLLEGE EMAIL ID" style uppercase label
/// + rounded input) used across login and form screens.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
    this.isRequired = false,
    this.prefixIcon,
    this.suffixIcon,
    this.enabled = true,
    this.textInputAction,
    this.focusNode,
    this.autofillHints,
  });

  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final int maxLines;
  final bool isRequired;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final bool enabled;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final Iterable<String>? autofillHints;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          RichText(
            text: TextSpan(
              style: AppTypography.label.copyWith(fontSize: 12),
              children: [
                TextSpan(text: label!.toUpperCase()),
                if (isRequired)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(color: AppColors.error),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: onChanged,
          maxLines: obscureText ? 1 : maxLines,
          enabled: enabled,
          textInputAction: textInputAction,
          focusNode: focusNode,
          autofillHints: autofillHints,
          style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18) : null,
            suffixIcon: suffixIcon,
          ),
        ),
      ],
    );
  }
}

/// Multi-line variant for "Technical Skills" / "Work Experience" style
/// fields.
class AppTextArea extends StatelessWidget {
  const AppTextArea({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.validator,
    this.isRequired = false,
    this.minLines = 4,
  });

  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final bool isRequired;
  final int minLines;

  @override
  Widget build(BuildContext context) {
    return AppTextField(
      label: label,
      hint: hint,
      controller: controller,
      validator: validator,
      isRequired: isRequired,
      maxLines: minLines,
      keyboardType: TextInputType.multiline,
    );
  }
}
