import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'api_exception.dart';

/// Wrapper fino sobre `http` para hablar con el backend FastAPI:
/// arma la URL, serializa/deserializa JSON y traduce los errores
/// (`detail` de FastAPI, sea texto simple o lista de validación de Pydantic)
/// a un [ApiException] con un mensaje legible.
class ApiClient {
  final String? Function() getToken;

  ApiClient({required this.getToken});

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  Map<String, String> _headers({bool auth = true}) {
    final headers = {'Content-Type': 'application/json'};
    final token = auth ? getToken() : null;
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Para `/auth/login`, que espera `application/x-www-form-urlencoded`
  /// (OAuth2PasswordRequestForm de FastAPI), no JSON.
  Future<dynamic> postForm(String path, Map<String, String> fields) async {
    final res = await _wrap(() => http.post(_uri(path), body: fields));
    return _decode(res);
  }

  Future<dynamic> get(String path, {bool auth = true}) async {
    final res = await _wrap(
      () => http.get(_uri(path), headers: _headers(auth: auth)),
    );
    return _decode(res);
  }

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final res = await _wrap(
      () => http.post(
        _uri(path),
        headers: _headers(auth: auth),
        body: body == null ? null : jsonEncode(body),
      ),
    );
    return _decode(res);
  }

  Future<dynamic> patch(
    String path, {
    Map<String, dynamic>? body,
    bool auth = true,
  }) async {
    final res = await _wrap(
      () => http.patch(
        _uri(path),
        headers: _headers(auth: auth),
        body: body == null ? null : jsonEncode(body),
      ),
    );
    return _decode(res);
  }

  Future<dynamic> delete(String path, {bool auth = true}) async {
    final res = await _wrap(
      () => http.delete(_uri(path), headers: _headers(auth: auth)),
    );
    return _decode(res);
  }

  Future<http.Response> _wrap(Future<http.Response> Function() call) async {
    try {
      return await call();
    } on SocketException {
      throw ApiException(
        'No se pudo conectar con el servidor. Revisá tu conexión.',
      );
    } on http.ClientException {
      throw ApiException(
        'No se pudo conectar con el servidor. Revisá tu conexión.',
      );
    }
  }

  dynamic _decode(http.Response res) {
    final bodyText = res.body.isEmpty ? null : utf8.decode(res.bodyBytes);
    final decoded = bodyText == null ? null : jsonDecode(bodyText);

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return decoded;
    }

    throw ApiException(
      _mensajeError(decoded),
      statusCode: res.statusCode,
      codigo: _codigoError(decoded),
      data: decoded is Map<String, dynamic> ? decoded : null,
    );
  }

  String _mensajeError(dynamic decoded) {
    if (decoded is Map) {
      final detail = decoded['detail'];
      if (detail is String && detail.trim().isNotEmpty) return detail;
      if (detail is Map) {
        for (final clave in ['mensaje', 'detail', 'msg']) {
          final valor = detail[clave];
          if (valor is String && valor.trim().isNotEmpty) return valor;
        }
      }
      if (detail is List && detail.isNotEmpty) {
        final primero = detail.first;
        if (primero is Map && primero['msg'] != null) {
          return primero['msg'].toString();
        }
      }
      final mensaje = decoded['mensaje'];
      if (mensaje is String && mensaje.trim().isNotEmpty) return mensaje;
    }
    return 'Ocurrió un error inesperado. Intentá de nuevo.';
  }

  /// Código de negocio: puede venir en el nivel superior (`codigo`) o dentro
  /// de `detail` cuando el backend usa `HTTPException(detail={...})`.
  String? _codigoError(dynamic decoded) {
    if (decoded is! Map) return null;
    final directo = decoded['codigo'];
    if (directo is String && directo.isNotEmpty) return directo;
    final detail = decoded['detail'];
    if (detail is Map) {
      final codigo = detail['codigo'];
      if (codigo is String && codigo.isNotEmpty) return codigo;
    }
    return null;
  }
}
