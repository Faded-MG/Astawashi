import 'package:dio/dio.dart';

import 'sync_api.dart';
import 'sync_models.dart';
import 'token_store.dart';

class BackendApiClient implements SyncApi {
  BackendApiClient({
    required String baseUrl,
    this._shopId,
    required this._tokenStore,
    Dio? dio,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl,
               connectTimeout: const Duration(seconds: 10),
               receiveTimeout: const Duration(seconds: 20),
               sendTimeout: const Duration(seconds: 20),
               headers: const {'content-type': 'application/json'},
             ),
           );

  final Dio _dio;
  final TokenStore _tokenStore;
  String? _shopId;

  bool get isAuthenticated => _shopId != null;

  @override
  String get shopId =>
      _shopId ?? (throw StateError('Authenticate before synchronizing.'));

  static Future<BackendApiClient> restore({
    required String baseUrl,
    required TokenStore tokenStore,
    Dio? dio,
  }) async {
    final tokens = await tokenStore.read();
    return BackendApiClient(
      baseUrl: baseUrl,
      shopId: tokens?.shopId,
      tokenStore: tokenStore,
      dio: dio,
    );
  }

  Future<String> register({
    required String phone,
    required String pin,
    String? shopName,
  }) async {
    return _authenticate('/auth/register', {
      'phone': phone,
      'pin': pin,
      'shopName': ?shopName,
    });
  }

  Future<String> login({required String phone, required String pin}) {
    return _authenticate('/auth/login', {'phone': phone, 'pin': pin});
  }

  Future<String> _authenticate(String path, Map<String, Object?> body) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(path, data: body);
      final tokens = SessionTokens.fromJson(response.data ?? const {});
      await _tokenStore.save(tokens);
      _shopId = tokens.shopId;
      return tokens.shopId;
    } on DioException catch (error) {
      throw _apiException(error);
    } on FormatException {
      rethrow;
    }
  }

  @override
  Future<PushAcknowledgements> push({
    required List<SyncCustomerData> customers,
    required List<SyncEntryData> entries,
  }) async {
    final response = await _authorized((token) {
      return _dio.post<Map<String, dynamic>>(
        '/sync/push',
        data: {
          'customers': customers
              .map((customer) => customer.toPushJson())
              .toList(),
          'entries': entries.map((entry) => entry.toPushJson()).toList(),
        },
        options: Options(headers: {'authorization': 'Bearer $token'}),
      );
    });
    try {
      return PushAcknowledgements.fromJson(response.data ?? const {});
    } on FormatException catch (error) {
      throw SyncApiException(message: error.message);
    }
  }

  @override
  Future<SyncPullPage> pull({required BigInt since, required int limit}) async {
    final response = await _authorized((token) {
      return _dio.get<Map<String, dynamic>>(
        '/sync/pull',
        queryParameters: {'since': since.toString(), 'limit': limit},
        options: Options(headers: {'authorization': 'Bearer $token'}),
      );
    });
    try {
      return SyncPullPage.fromJson(response.data ?? const {});
    } on FormatException catch (error) {
      throw SyncApiException(message: error.message);
    }
  }

  Future<Response<T>> _authorized<T>(
    Future<Response<T>> Function(String accessToken) request,
  ) async {
    var tokens = await _tokenStore.read();
    if (tokens == null) {
      throw const AuthenticationRequiredException();
    }

    try {
      return await request(tokens.accessToken);
    } on DioException catch (error) {
      if (error.response?.statusCode != 401) {
        throw _apiException(error);
      }
    }

    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/auth/refresh',
        data: {'refreshToken': tokens.refreshToken},
      );
      tokens = SessionTokens.fromJson(response.data ?? const {});
      await _tokenStore.save(tokens);
      _shopId = tokens.shopId;
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        await _tokenStore.clear();
        throw const AuthenticationRequiredException();
      }
      throw _apiException(error);
    } on FormatException catch (error) {
      throw SyncApiException(message: error.message);
    }

    try {
      return await request(tokens.accessToken);
    } on DioException catch (error) {
      if (error.response?.statusCode == 401) {
        await _tokenStore.clear();
        throw const AuthenticationRequiredException();
      }
      throw _apiException(error);
    }
  }

  SyncApiException _apiException(DioException error) {
    final body = error.response?.data;
    final errorObject = body is Map<String, dynamic> ? body['error'] : null;
    final code =
        errorObject is Map<String, dynamic> && errorObject['code'] is String
        ? errorObject['code'] as String
        : null;
    final message =
        errorObject is Map<String, dynamic> && errorObject['message'] is String
        ? errorObject['message'] as String
        : error.message ?? 'The server request failed.';
    return SyncApiException(
      message: message,
      statusCode: error.response?.statusCode,
      code: code,
    );
  }
}
