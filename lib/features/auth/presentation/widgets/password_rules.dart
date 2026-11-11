import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class PasswordRules {
  const PasswordRules({
    required this.hasMinLength,
    required this.hasUppercase,
    required this.hasLowercase,
    required this.hasNumber,
    required this.hasSymbol,
  });

  factory PasswordRules.from(String value) => PasswordRules(
    hasMinLength: value.length >= 8,
    hasUppercase: value.contains(RegExp(r'[A-Z]')),
    hasLowercase: value.contains(RegExp(r'[a-z]')),
    hasNumber: value.contains(RegExp(r'[0-9]')),
    hasSymbol: value.contains(RegExp(r'[^A-Za-z0-9]')),
  );

  final bool hasMinLength;
  final bool hasUppercase;
  final bool hasLowercase;
  final bool hasNumber;
  final bool hasSymbol;

  bool get isStrong =>
      hasMinLength && hasUppercase && hasLowercase && hasNumber && hasSymbol;
}

class PasswordRulesView extends StatelessWidget {
  const PasswordRulesView({super.key, required this.password});

  final String password;

  @override
  Widget build(BuildContext context) {
    final rules = PasswordRules.from(password);
    return Semantics(
      label: 'Requisitos de contrasena',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Rule(done: rules.hasMinLength, text: 'Al menos 8 caracteres'),
          _Rule(done: rules.hasUppercase, text: 'Una letra mayuscula'),
          _Rule(done: rules.hasLowercase, text: 'Una letra minuscula'),
          _Rule(done: rules.hasNumber, text: 'Un numero'),
          _Rule(done: rules.hasSymbol, text: 'Un simbolo, por ejemplo ! o @'),
        ],
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  const _Rule({required this.done, required this.text});

  final bool done;
  final String text;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 180),
    curve: Curves.easeOut,
    margin: const EdgeInsets.only(top: 6),
    child: Row(
      children: [
        Icon(
          done ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
          size: 18,
          color: done ? AppColors.primary : AppColors.textSecondary,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: done ? AppColors.primaryDark : AppColors.textSecondary,
            fontWeight: done ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    ),
  );
}
