import 'package:dio/dio.dart';
import 'package:fplboardman_admin/core/errors/app_exception.dart';

class ApiClient {
  ApiClient(String baseUrl)
      : _baseUri = Uri.parse(
          baseUrl.replaceFirst(RegExp(r'/+$'), ''),
        ),
        _dio = Dio(
          BaseOptions(
            baseUrl: '${baseUrl.replaceFirst(RegExp(r'/+$'), '')}/v1',
            connectTimeout: const Duration(seconds: 8),
            receiveTimeout: const Duration(seconds: 12),
            headers: const {'Accept': 'application/json'},
          ),
        );

  final Dio _dio;
  final Uri _baseUri;
  Future<String?> Function()? _refreshHandler;

  void setRefreshHandler(Future<String?> Function() handler) {
    _refreshHandler = handler;
  }

  void authorize(String? token) {
    if (token == null) {
      _dio.options.headers.remove('Authorization');
      return;
    }

    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  Future<Map<String, Object?>> get(
    String path, {
    Map<String, Object?>? query,
  }) =>
      _request(
        () => _dio.get<Object?>(path, queryParameters: query),
      );

  Future<Map<String, Object?>> post(
    String path, {
    Map<String, Object?>? data,
    String? idempotencyKey,
    bool allowRefresh = true,

    /// How long to wait for the answer, when the default is too short: a
    /// call that makes the server wait on a payment provider or on FPL.
    Duration? receiveTimeout,
  }) =>
      _request(
        () => _dio.post<Object?>(
          path,
          data: data,
          options: Options(
            headers: idempotencyKey == null
                ? null
                : {'Idempotency-Key': idempotencyKey},
            receiveTimeout: receiveTimeout,
          ),
        ),
        allowRefresh: allowRefresh,
      );

  Future<Map<String, Object?>> put(
    String path, {
    Map<String, Object?>? data,
  }) =>
      _request(
        () => _dio.put<Object?>(path, data: data),
      );

  Future<Map<String, Object?>> patch(
    String path, {
    Map<String, Object?>? data,
  }) =>
      _request(
        () => _dio.patch<Object?>(path, data: data),
      );

  Future<Map<String, Object?>> delete(String path) =>
      _request(() => _dio.delete<Object?>(path));

  /// Creates the short-lived, single-use ticket used for WebSocket auth.
  Future<String> createRealtimeTicket() async {
    final response = await post('/realtime/ticket');
    final ticket = response['ticket'];

    if (ticket is! String || ticket.isEmpty) {
      throw const FormatException(
        'The server returned an invalid realtime ticket.',
      );
    }

    return ticket;
  }

  /// Converts the configured HTTP API origin to its WebSocket equivalent.
  ///
  /// HTTP becomes WS locally, while HTTPS becomes WSS in production.
  Uri realtimeUri(String ticket) {
    final websocketScheme = _baseUri.scheme == 'https' ? 'wss' : 'ws';
    final basePath = _baseUri.path.replaceFirst(RegExp(r'/+$'), '');

    return _baseUri.replace(
      scheme: websocketScheme,
      path: '$basePath/v1/realtime',
      queryParameters: {'ticket': ticket},
    );
  }

  Future<Map<String, Object?>> _request(
    Future<Response<Object?>> Function() execute, {
    bool allowRefresh = true,
  }) async {
    try {
      final response = await execute();
      final responseData = response.data;

      // A 204 (or any reply that is not a JSON object) has nothing to parse.
      if (responseData is! Map<Object?, Object?>) return const {};

      return Map<String, Object?>.from(responseData);
    } on DioException catch (error) {
      if (error.response?.statusCode == 401 &&
          allowRefresh &&
          _refreshHandler != null) {
        final token = await _refreshHandler!();

        if (token != null) {
          authorize(token);
          return _request(execute, allowRefresh: false);
        }
      }

      final responseData = error.response?.data;
      String? code;
      var message = 'Unable to connect. Please try again.';

      if (responseData is Map<Object?, Object?> &&
          responseData['error'] is Map<Object?, Object?>) {
        final errorBody =
            responseData['error']! as Map<Object?, Object?>;
        code = errorBody['code'] as String?;
        message = errorBody['message'] as String? ?? message;
      }

      if (error.response?.statusCode == 401) {
        throw AuthenticationException(message, code: code);
      }

      if ((error.response?.statusCode ?? 500) < 500) {
        throw ValidationException(message, code: code);
      }

      throw NetworkException(message, code: code);
    }
  }
}