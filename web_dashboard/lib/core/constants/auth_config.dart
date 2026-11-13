/// Centralized Authentication and Demo Configuration.
/// 
/// This module isolates presentation and demo bypass logic so that
/// it can be safely toggled or completely removed when publishing to production.
class AuthConfig {
  AuthConfig._();

  /// Master switch for presentation demo accounts.
  /// 
  /// Set to [false] in production builds to completely disable any bypass.
  static const bool enableDemoBypass = true;

  /// Dedicated demo account email for frictionless presentations.
  static const String demoEmail = 'markkevincanonoy99@gmail.com';

  /// Evaluates whether the provided user input matches the authorized demo bypass account.
  /// 
  /// When [enableDemoBypass] is false, this always returns false.
  static bool isDemoAccount(String input) {
    if (!enableDemoBypass) return false;
    final clean = input.trim().toLowerCase();
    return clean == demoEmail;
  }
}
