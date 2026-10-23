import 'sync_models.dart';

abstract interface class SyncApi {
  String get shopId;

  Future<PushAcknowledgements> push({
    required List<SyncCustomerData> customers,
    required List<SyncEntryData> entries,
  });

  Future<SyncPullPage> pull({required BigInt since, required int limit});
}

class SyncApiException implements Exception {
  const SyncApiException({required this.message, this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() => 'SyncApiException($statusCode, $code): $message';
}

class AuthenticationRequiredException extends SyncApiException {
  const AuthenticationRequiredException()
    : super(
        message: 'Authentication is required to synchronize this shop.',
        statusCode: 401,
        code: 'authentication_required',
      );
}
