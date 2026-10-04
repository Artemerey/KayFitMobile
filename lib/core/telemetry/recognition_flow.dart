import '../feedback/secure_uuid.dart';

enum RecognitionMode { text, voice, photo, chat, barcode, manual }

enum RecognitionEndpoint { parse, chat, save, displayAck, feedback }

enum CacheOutcome { hit, miss, partial, notApplicable }

class RecognitionTelemetry {
  static const allowedKeys = {
    'client_flow_id',
    'client_operation_id',
    'event_type',
    'endpoint',
    'status_code',
    'cache_outcome',
    'provider',
    'model',
    'release_version',
    'build_number',
    'platform',
    'network_class',
    'attempt_count',
    'auth_refresh_count',
    'retry_backoff_ms',
    'tap_to_request_ms',
    'wire_ms',
    'decode_ms',
    'state_update_ms',
    'tap_to_meaningful_frame_ms',
    'result_to_save_tap_ms',
    'save_wire_ms',
    'save_response_to_success_frame_ms',
  };

  static const feedbackContextKeys = {
    'flow_duration_bucket',
    'endpoint_sequence',
    'attempt_count',
    'cache_outcome',
    'terminal_outcome',
  };
}

class RecognitionFlow {
  RecognitionFlow._(this.id, this.mode) : _clock = Stopwatch()..start();

  factory RecognitionFlow.start({required RecognitionMode mode}) =>
      RecognitionFlow._(SecureUuid.v4(), mode);

  factory RecognitionFlow.resume({
    required String id,
    required RecognitionMode mode,
  }) => RecognitionFlow._(id, mode);

  final String id;
  final RecognitionMode mode;
  final Stopwatch _clock;
  final List<RecognitionEndpoint> _sequence = [];
  final List<RecognitionOperation> _operations = [];
  int? meaningfulFrameMs;
  int? saveTapMs;

  RecognitionOperation startOperation(RecognitionEndpoint endpoint) {
    recordEndpoint(endpoint);
    final operation = RecognitionOperation._(
      id: SecureUuid.v4(),
      flowId: id,
      endpoint: endpoint,
      flowClock: _clock,
    );
    _operations.add(operation);
    return operation;
  }

  void recordEndpoint(RecognitionEndpoint endpoint) {
    if (_sequence.isEmpty || _sequence.last != endpoint)
      _sequence.add(endpoint);
  }

  void markMeaningfulFrame() =>
      meaningfulFrameMs ??= _clock.elapsedMilliseconds;
  void markSaveTap() => saveTapMs ??= _clock.elapsedMilliseconds;

  Map<String, Object> feedbackContext({String terminalOutcome = 'feedback'}) {
    final elapsed = _clock.elapsedMilliseconds;
    return {
      'flow_duration_bucket': switch (elapsed) {
        < 2000 => 'lt_2s',
        < 5000 => '2_5s',
        < 15000 => '5_15s',
        < 30000 => '15_30s',
        _ => 'gte_30s',
      },
      'endpoint_sequence': _sequence
          .map(
            (value) => switch (value) {
              RecognitionEndpoint.displayAck ||
              RecognitionEndpoint.feedback => null,
              RecognitionEndpoint.save => 'save',
              RecognitionEndpoint.parse => 'parse',
              RecognitionEndpoint.chat => 'chat',
            },
          )
          .whereType<String>()
          .join('_'),
      'attempt_count': _operations.fold<int>(
        0,
        (sum, item) => sum + item.attemptCount,
      ),
      'cache_outcome': _operations
          .map((item) => item.cacheOutcome)
          .firstWhere(
            (value) => value != CacheOutcome.notApplicable,
            orElse: () => CacheOutcome.notApplicable,
          )
          .name
          .replaceAll('notApplicable', 'not_applicable'),
      'terminal_outcome': terminalOutcome,
    };
  }
}

class RecognitionOperation {
  RecognitionOperation._({
    required this.id,
    required this.flowId,
    required this.endpoint,
    required Stopwatch flowClock,
  }) : _flowClock = flowClock;

  factory RecognitionOperation.forExisting({
    required String flowId,
    required String operationId,
    required RecognitionEndpoint endpoint,
  }) => RecognitionOperation._(
    id: operationId,
    flowId: flowId,
    endpoint: endpoint,
    flowClock: Stopwatch()..start(),
  );

  final String id;
  final String flowId;
  final RecognitionEndpoint endpoint;
  final Stopwatch _flowClock;
  int attemptCount = 1;
  int authRefreshCount = 0;
  int retryBackoffMs = 0;
  CacheOutcome cacheOutcome = CacheOutcome.notApplicable;
  int? _requestStartedMs;
  int? _responseReceivedMs;
  int? _decodedMs;

  void markRequestStarted() =>
      _requestStartedMs ??= _flowClock.elapsedMilliseconds;
  void markAuthRefresh() => authRefreshCount++;
  void markRetry({Duration backoff = Duration.zero}) {
    attemptCount++;
    retryBackoffMs += backoff.inMilliseconds;
  }

  void markResponseReceived({
    CacheOutcome cacheOutcome = CacheOutcome.notApplicable,
  }) {
    _responseReceivedMs ??= _flowClock.elapsedMilliseconds;
    this.cacheOutcome = cacheOutcome;
  }

  void markDecoded() => _decodedMs = _flowClock.elapsedMilliseconds;

  Map<String, Object> safePayload({String eventType = 'client_completed'}) => {
    'client_flow_id': flowId,
    'client_operation_id': id,
    'event_type': eventType,
    'endpoint': switch (endpoint) {
      RecognitionEndpoint.displayAck => 'display_ack',
      _ => endpoint.name,
    },
    'status_code': 'ok',
    'cache_outcome': cacheOutcome.name.replaceAll(
      'notApplicable',
      'not_applicable',
    ),
    'provider': 'none',
    'model': 'none',
    'network_class': 'unknown',
    'attempt_count': attemptCount,
    'auth_refresh_count': authRefreshCount,
    'retry_backoff_ms': retryBackoffMs,
    if (_requestStartedMs != null) 'tap_to_request_ms': _requestStartedMs!,
    if (_requestStartedMs != null && _responseReceivedMs != null)
      'wire_ms': _responseReceivedMs! - _requestStartedMs!,
    if (_responseReceivedMs != null && _decodedMs != null)
      'decode_ms': _decodedMs! - _responseReceivedMs!,
  };
}
