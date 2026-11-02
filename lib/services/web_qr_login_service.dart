import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class WebQrLoginSession {
  const WebQrLoginSession({
    required this.sessionId,
    required this.browserSecret,
  });

  final String sessionId;
  final String browserSecret;

  String get qrPayload =>
      'https://kisiden.com/qr-login?sessionId=$sessionId';
}

enum WebQrLoginStatus { pending, expired, cancelled, used, complete }

class WebQrLoginPollResult {
  const WebQrLoginPollResult(this.status, {this.customToken});

  final WebQrLoginStatus status;
  final String? customToken;
}

class WebQrLoginService {
  WebQrLoginService()
    : _functions = FirebaseFunctions.instanceFor(region: 'europe-west1');

  final FirebaseFunctions _functions;

  Future<WebQrLoginSession> createWebSession() async {
    final result = await _functions
        .httpsCallable('createWebQrLoginSession')
        .call();
    final data = _dataMap(result.data);
    final sessionId = data['sessionId'];
    final browserSecret = data['browserSecret'];
    if (sessionId is! String || browserSecret is! String) {
      throw StateError('QR oturum bilgisi sunucudan alınamadı.');
    }

    return WebQrLoginSession(
      sessionId: sessionId,
      browserSecret: browserSecret,
    );
  }

  Future<WebQrLoginPollResult> pollWebSession(
    WebQrLoginSession session,
  ) async {
    final result = await _functions
        .httpsCallable('completeWebQrLoginSession')
        .call({
          'sessionId': session.sessionId,
          'browserSecret': session.browserSecret,
        });
    final data = _dataMap(result.data);
    final status = data['status'];
    switch (status) {
      case 'pending':
        return const WebQrLoginPollResult(WebQrLoginStatus.pending);
      case 'expired':
        return const WebQrLoginPollResult(WebQrLoginStatus.expired);
      case 'cancelled':
        return const WebQrLoginPollResult(WebQrLoginStatus.cancelled);
      case 'used':
        return const WebQrLoginPollResult(WebQrLoginStatus.used);
      case 'complete':
        final customToken = data['customToken'];
        if (customToken is! String || customToken.isEmpty) {
          throw StateError('Web oturum token bilgisi alınamadı.');
        }
        return WebQrLoginPollResult(
          WebQrLoginStatus.complete,
          customToken: customToken,
        );
      default:
        throw StateError('QR oturumundan beklenmeyen yanıt alındı.');
    }
  }

  Future<void> approveMobileSession(String sessionId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      throw FirebaseAuthException(
        code: 'unauthenticated',
        message: 'QR ile giriş için kayıtlı bir hesapla giriş yapın.',
      );
    }
    await _functions.httpsCallable('approveWebQrLoginSession').call({
      'sessionId': sessionId,
    });
  }

  Future<void> cancelWebSession(WebQrLoginSession session) async {
    await _functions.httpsCallable('cancelWebQrLoginSession').call({
      'sessionId': session.sessionId,
      'browserSecret': session.browserSecret,
    });
  }

  Future<void> acknowledgeWebSession(WebQrLoginSession session) async {
    await _functions.httpsCallable('acknowledgeWebQrLoginSession').call({
      'sessionId': session.sessionId,
      'browserSecret': session.browserSecret,
    });
  }

  Map<Object?, Object?> _dataMap(Object? value) {
    if (value is! Map) {
      throw StateError('Sunucudan geçersiz QR oturum yanıtı alındı.');
    }
    return value;
  }
}
