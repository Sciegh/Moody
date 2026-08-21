/// TODO(secure-storage): the architecture diagram calls for local
/// sensitive/device-specific data (session tokens, "remember me") to go
/// through secure storage, but the supplied HTML has no persisted state to
/// migrate — the "Remember me" checkbox on Login has no backing logic in
/// the source `<script>`. This interface exists so that behavior has a
/// clear home once it's specified, without UI code touching
/// `flutter_secure_storage` directly.
abstract interface class SecureStorageService {
  Future<void> write({required String key, required String value});
  Future<String?> read({required String key});
  Future<void> delete({required String key});
}

/// Real implementation, left unused until a caller needs it.
///
/// ```dart
/// import 'package:flutter_secure_storage/flutter_secure_storage.dart';
///
/// class FlutterSecureStorageService implements SecureStorageService {
///   final _storage = const FlutterSecureStorage();
///
///   @override
///   Future<void> write({required String key, required String value}) =>
///       _storage.write(key: key, value: value);
///
///   @override
///   Future<String?> read({required String key}) => _storage.read(key: key);
///
///   @override
///   Future<void> delete({required String key}) => _storage.delete(key: key);
/// }
/// ```
