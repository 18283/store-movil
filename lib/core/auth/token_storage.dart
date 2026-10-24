import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persistencia segura del token de sesión (keystore/keychain nativo).
class TokenStorage {
  static const _tokenKey = 'access_token';
  static const _userKey = 'offline_user';
  final _storage = const FlutterSecureStorage();

  Future<void> guardar(String token) =>
      _storage.write(key: _tokenKey, value: token);

  Future<String?> leer() => _storage.read(key: _tokenKey);

  Future<void> guardarUsuario(String usuarioJson) =>
      _storage.write(key: _userKey, value: usuarioJson);

  Future<String?> leerUsuario() => _storage.read(key: _userKey);

  Future<void> borrar() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userKey);
  }
}
