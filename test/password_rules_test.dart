import 'package:flutter_test/flutter_test.dart';
import 'package:proyecto_agro/features/auth/presentation/widgets/password_rules.dart';

void main() {
  test('marca cada requisito de una contrasena fuerte', () {
    final rules = PasswordRules.from('Campo2026!');

    expect(rules.hasMinLength, isTrue);
    expect(rules.hasUppercase, isTrue);
    expect(rules.hasLowercase, isTrue);
    expect(rules.hasNumber, isTrue);
    expect(rules.hasSymbol, isTrue);
    expect(rules.isStrong, isTrue);
  });

  test('no acepta una contrasena incompleta como fuerte', () {
    final rules = PasswordRules.from('campo');

    expect(rules.hasMinLength, isFalse);
    expect(rules.hasUppercase, isFalse);
    expect(rules.hasNumber, isFalse);
    expect(rules.hasSymbol, isFalse);
    expect(rules.isStrong, isFalse);
  });
}
