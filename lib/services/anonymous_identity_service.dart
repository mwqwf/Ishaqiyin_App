import 'package:firebase_auth/firebase_auth.dart';

/// ينشئ الهوية المجهولة مرة واحدة ويمنع سباق عدة طلبات عند بدء التطبيق.
class AnonymousIdentityService {
  AnonymousIdentityService._();

  static Future<User>? _signingIn;

  static Future<User> ensureSignedIn() async {
    final current = FirebaseAuth.instance.currentUser;
    if (current != null) return current;
    final active = _signingIn;
    if (active != null) return active;

    final operation = FirebaseAuth.instance.signInAnonymously().then((cred) {
      final user = cred.user;
      if (user == null) throw StateError('anonymous_auth_failed');
      return user;
    });
    _signingIn = operation;
    try {
      return await operation;
    } finally {
      if (identical(_signingIn, operation)) _signingIn = null;
    }
  }
}
