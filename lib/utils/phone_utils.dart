class PhoneUtils {
  /// Normalizes any Pakistani phone format into a standard +923XXXXXXXXX
  static String normalizePhone(String input) {
    // Strip everything except digits and plus sign
    String cleaned = input.replaceAll(RegExp(r'[^\d+]'), '');

    // If starts with 03, replace '0' with '+92'
    if (cleaned.startsWith('03')) {
      cleaned = '+92' + cleaned.substring(1);
    }
    // If starts with 923, prepend '+'
    else if (cleaned.startsWith('923')) {
      cleaned = '+' + cleaned;
    }
    
    return cleaned;
  }

  /// Validates if the phone number is a valid Pakistani format
  static bool isValidPakistaniPhone(String input) {
    final normalized = normalizePhone(input);
    // +92 followed by exactly 10 digits starting with 3
    return RegExp(r'^\+923\d{9}$').hasMatch(normalized);
  }
}
