import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import 'attribute_formatter.dart';
import 'log_payload_builder.dart';
import 'otel_config.dart';
import 'otel_log_record.dart';
import 'severity_mapper.dart';

/// Signature for the optional error callback invoked when a log fails to send.
typedef OtelErrorHandler = void Function(Object error, StackTrace stackTrace);

/// Exports log records to an OpenTelemetry collector over OTLP/HTTP (JSON).
///
/// Create one, then either call [emit] with [OtelLogRecord]s directly, or wire
/// it to `package:logging` with [attachToLogger]:
///
/// ```dart
/// final exporter = OtelLogExporter(
///   config: const OtelConfig(
///     enabled: true,
///     endpoint: 'https://collector.example.com/v1/logs',
///     serviceName: 'my-dart-app',
///   ),
/// );
/// Logger.root.level = Level.ALL;
/// exporter.attachToLogger(Logger.root);
/// ```
class OtelLogExporter {
  /// The active configuration.
  final OtelConfig config;

  /// Maps `package:logging` levels to OTLP severities.
  final SeverityMapper severityMapper;

  /// Formats attribute values into OTLP structures.
  final AttributeFormatter attributeFormatter;

  /// Builds OTLP payloads from records.
  final LogPayloadBuilder payloadBuilder;

  final http.Client _client;
  final bool _ownsClient;
  final OtelErrorHandler? _onError;

  bool _inErrorHandler = false;
  bool _closed = false;

  OtelLogExporter({
    required this.config,
    http.Client? client,
    SeverityMapper? severityMapper,
    AttributeFormatter? attributeFormatter,
    LogPayloadBuilder? payloadBuilder,
    OtelErrorHandler? onError,
  })  : severityMapper = severityMapper ?? const SeverityMapper(),
        attributeFormatter = attributeFormatter ?? const AttributeFormatter(),
        payloadBuilder = payloadBuilder ??
            LogPayloadBuilder(
              attributeFormatter:
                  attributeFormatter ?? const AttributeFormatter(),
            ),
        _onError = onError,
        _ownsClient = client == null,
        _client = client ?? http.Client();

  /// Export a single [record].
  ///
  /// No-ops when [OtelConfig.enabled] is `false` or the exporter is closed.
  /// Never throws: send failures are routed to the `onError` callback.
  Future<void> emit(OtelLogRecord record) async {
    if (!config.enabled || _closed) return;

    try {
      final payload = payloadBuilder.build(record, config);
      await _send(payload);
    } catch (error, stackTrace) {
      _handleError(error, stackTrace);
    }
  }

  Future<void> _send(Map<String, Object?> payload) async {
    final endpoint = config.endpoint.trim();
    if (endpoint.isEmpty) {
      throw StateError('OTEL exporter endpoint is not configured.');
    }

    final response = await _client
        .post(
          Uri.parse(endpoint),
          headers: {
            'Content-Type': 'application/json',
            ...config.headers,
          },
          body: jsonEncode(payload),
        )
        .timeout(config.timeout);

    final status = response.statusCode;
    if (status < 200 || status >= 300) {
      throw http.ClientException(
        'OpenTelemetry exporter responded with HTTP $status.',
        Uri.parse(endpoint),
      );
    }
  }

  void _handleError(Object error, StackTrace stackTrace) {
    if (_inErrorHandler) return; // Guard against logging-induced loops.
    _inErrorHandler = true;
    try {
      _onError?.call(error, stackTrace);
    } finally {
      _inErrorHandler = false;
    }
  }

  /// Subscribe to [logger]'s records and export each one.
  ///
  /// Returns the [StreamSubscription] so callers can cancel it. Remember to set
  /// the logger level (e.g. `Logger.root.level = Level.ALL`) so records flow.
  StreamSubscription<LogRecord> attachToLogger(Logger logger) {
    return logger.onRecord.listen((record) {
      emit(OtelLogRecord.fromLogging(record, mapper: severityMapper));
    });
  }

  /// Close the underlying HTTP client (only if this exporter created it).
  void close() {
    _closed = true;
    if (_ownsClient) {
      _client.close();
    }
  }
}
