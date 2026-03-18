class NetworkLogEntry {
  final String id;
  final String method; // GET, SET, UPDATE, DELETE, QUERY, STREAM, AUTH
  final String path; // e.g. "users/uid123", "territories"
  final String operation; // e.g. "getUser", "claimTerritory"
  final Map<String, dynamic>? requestData;
  Map<String, dynamic>? responseData;
  final DateTime timestamp;
  int? durationMs;
  String status; // "pending", "success", "error"
  String? error;

  NetworkLogEntry({
    required this.id,
    required this.method,
    required this.path,
    required this.operation,
    this.requestData,
    this.responseData,
    required this.timestamp,
    this.durationMs,
    this.status = 'pending',
    this.error,
  });

  void complete({
    int? durationMs,
    Map<String, dynamic>? responseData,
  }) {
    status = 'success';
    this.durationMs = durationMs;
    this.responseData = responseData;
  }

  void fail({
    int? durationMs,
    String? error,
  }) {
    status = 'error';
    this.durationMs = durationMs;
    this.error = error;
  }
}
