class EcuadorMobilePhone {
  EcuadorMobilePhone._();

  static const countryPrefix = '+593';
  static final localPattern = RegExp(r'^9[0-9]{8}$');
  static final internationalPattern = RegExp(r'^\+5939[0-9]{8}$');

  static String? toInternational(String? localNumber) {
    final digits = (localNumber ?? '').trim();
    if (digits.isEmpty) return null;
    if (!localPattern.hasMatch(digits)) {
      throw ArgumentError('Escribe 9 dígitos de celular, sin el 0 inicial.');
    }
    return '$countryPrefix$digits';
  }

  static String toLocal(String? internationalNumber) {
    final value = internationalNumber?.trim() ?? '';
    if (internationalPattern.hasMatch(value)) {
      return value.substring(countryPrefix.length);
    }
    return '';
  }
}
