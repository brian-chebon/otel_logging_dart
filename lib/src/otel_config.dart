/// Immutable configuration for the OpenTelemetry log exporter.
///
/// Mirrors the environment-variable surface of the original Laravel package
/// while remaining a plain Dart object so it works on every platform.
class OtelConfig {
  /// Whether log exporting is active. When `false` the exporter is a no-op.
  final bool enabled;

  /// The OTLP/HTTP logs endpoint, e.g. `https://collector.example.com/v1/logs`.
  final String endpoint;

  /// The `service.name` resource attribute.
  final String serviceName;

  /// The `service.version` resource attribute.
  final String serviceVersion;

  /// The `deployment.environment` resource attribute.
  final String environment;

  /// The `host.name` resource attribute.
  final String hostName;

  /// Per-request timeout for the OTLP HTTP call.
  final Duration timeout;

  /// Extra HTTP headers sent with every request (e.g. auth tokens).
  final Map<String, String> headers;

  /// Attributes attached to every exported log record.
  final Map<String, Object?> globalAttributes;

  /// The instrumentation scope name reported in `scopeLogs`.
  final String scopeName;

  /// The instrumentation scope version reported in `scopeLogs`.
  final String scopeVersion;

  const OtelConfig({
    this.enabled = false,
    this.endpoint = '',
    this.serviceName = 'dart-app',
    this.serviceVersion = '1.0.0',
    this.environment = 'production',
    this.hostName = 'unknown',
    this.timeout = const Duration(seconds: 5),
    this.headers = const {},
    this.globalAttributes = const {},
    this.scopeName = 'dart-logs',
    this.scopeVersion = 'unknown',
  });

  /// Build a configuration from a string-keyed [environment] map (typically
  /// `Platform.environment`), recognising the same variables as the original
  /// Laravel package.
  ///
  /// Recognised keys: `OTEL_ENABLED`, `OTEL_EXPORTER_ENDPOINT`,
  /// `OTEL_SERVICE_NAME`, `OTEL_SERVICE_VERSION`, `OTEL_HTTP_TIMEOUT`,
  /// `OTEL_ENVIRONMENT` (falling back to `APP_ENV`).
  factory OtelConfig.fromEnvironment(
    Map<String, String> environment, {
    Map<String, String> headers = const {},
    Map<String, Object?> globalAttributes = const {},
    String hostName = 'unknown',
  }) {
    final timeoutSeconds =
        int.tryParse(environment['OTEL_HTTP_TIMEOUT'] ?? '') ?? 5;
    return OtelConfig(
      enabled: _parseBool(environment['OTEL_ENABLED']),
      endpoint: environment['OTEL_EXPORTER_ENDPOINT'] ?? '',
      serviceName: environment['OTEL_SERVICE_NAME'] ?? 'dart-app',
      serviceVersion: environment['OTEL_SERVICE_VERSION'] ?? '1.0.0',
      environment: environment['OTEL_ENVIRONMENT'] ??
          environment['APP_ENV'] ??
          'production',
      hostName: hostName,
      timeout: Duration(seconds: timeoutSeconds),
      headers: headers,
      globalAttributes: globalAttributes,
    );
  }

  /// Return a copy of this configuration with the given overrides.
  OtelConfig copyWith({
    bool? enabled,
    String? endpoint,
    String? serviceName,
    String? serviceVersion,
    String? environment,
    String? hostName,
    Duration? timeout,
    Map<String, String>? headers,
    Map<String, Object?>? globalAttributes,
    String? scopeName,
    String? scopeVersion,
  }) {
    return OtelConfig(
      enabled: enabled ?? this.enabled,
      endpoint: endpoint ?? this.endpoint,
      serviceName: serviceName ?? this.serviceName,
      serviceVersion: serviceVersion ?? this.serviceVersion,
      environment: environment ?? this.environment,
      hostName: hostName ?? this.hostName,
      timeout: timeout ?? this.timeout,
      headers: headers ?? this.headers,
      globalAttributes: globalAttributes ?? this.globalAttributes,
      scopeName: scopeName ?? this.scopeName,
      scopeVersion: scopeVersion ?? this.scopeVersion,
    );
  }

  static bool _parseBool(String? value) {
    if (value == null) return false;
    switch (value.trim().toLowerCase()) {
      case 'true':
      case '1':
      case 'yes':
      case 'on':
        return true;
      default:
        return false;
    }
  }
}
