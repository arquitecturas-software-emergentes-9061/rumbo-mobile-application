import 'package:http/http.dart' as http;
import '../domain/session.dart';
import 'session_facade.dart';

// Public http.Client contract for contexts such as profiles. The underlying
// client belongs to DI; closing this wrapper does not close that shared client.
class AuthorizedClient extends http.BaseClient {
  AuthorizedClient(this.inner, this.session);
  final http.Client inner;
  final SessionFacade session;
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bytes = await request.finalize().toBytes();
    Future<http.StreamedResponse> attempt() {
      final copy = http.Request(request.method, request.url)
        ..headers.addAll(request.headers)
        ..followRedirects = request.followRedirects
        ..maxRedirects = request.maxRedirects
        ..persistentConnection = request.persistentConnection
        ..bodyBytes = bytes;
      final token = session.currentAccessToken;
      if (token != null) copy.headers['Authorization'] = 'Bearer $token';
      return inner.send(copy);
    }

    final response = await attempt();
    if (response.statusCode != 401) return response;
    await response.stream.drain<void>();
    if (!await session.refresh()) {
      throw const SessionFailure('Tu sesión expiró. Inicia sesión de nuevo.');
    }
    return attempt();
  }
}
