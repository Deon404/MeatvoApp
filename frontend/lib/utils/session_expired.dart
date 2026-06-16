/// Allows `ApiService` (no Flutter imports) to trigger login navigation without
/// importing screens or creating dependency cycles.
typedef SessionExpiredCallback = void Function();

SessionExpiredCallback? _sessionExpiredHandler;

void registerSessionExpiredHandler(SessionExpiredCallback fn) {
  _sessionExpiredHandler = fn;
}

void notifySessionExpired() {
  _sessionExpiredHandler?.call();
}
