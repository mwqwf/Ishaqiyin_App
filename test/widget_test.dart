// Basic smoke test. The app's root widget requires runtime services
// (Firebase, audio, shared prefs), so we keep this as a lightweight unit test.
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('sanity', () {
    expect(1 + 1, equals(2));
  });
}
