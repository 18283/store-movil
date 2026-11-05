/// URL base del backend FastAPI.
///
/// Por defecto apunta a http://10.0.2.2:8000 (emulador de Android).
/// Para producción o Render, override con:
///   flutter run --dart-define=API_BASE_URL=https://store-backend-i4g0.onrender.com
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );
}
