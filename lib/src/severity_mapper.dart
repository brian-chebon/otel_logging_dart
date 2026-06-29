import 'package:logging/logging.dart';

/// An OpenTelemetry severity, pairing a numeric severity with its text label.
///
/// See the OpenTelemetry logs data model for the meaning of the numbers:
/// https://opentelemetry.io/docs/specs/otel/logs/data-model/#field-severitynumber
class OtelSeverity {
  /// The OTLP `severityNumber` (1-24).
  final int number;

  /// The OTLP `severityText` (a human readable label such as `info`).
  final String text;

  const OtelSeverity(this.number, this.text);
}

/// Maps `package:logging` [Level] values onto OpenTelemetry severity numbers.
///
/// The mapping is range based so that custom [Level]s (any integer value) are
/// still bucketed into a sensible OTLP severity range:
///
/// | `package:logging`        | value range   | OTLP severity |
/// |--------------------------|---------------|---------------|
/// | `FINEST`, `FINER`        | `[0, 500)`    | `TRACE` (1)   |
/// | `FINE`, `CONFIG`         | `[500, 800)`  | `DEBUG` (5)   |
/// | `INFO`                   | `[800, 900)`  | `INFO` (9)    |
/// | `WARNING`                | `[900, 1000)` | `WARN` (13)   |
/// | `SEVERE`                 | `[1000, 1200)`| `ERROR` (17)  |
/// | `SHOUT`                  | `[1200, ...)` | `FATAL` (21)  |
class SeverityMapper {
  const SeverityMapper();

  /// OpenTelemetry severity number constants (the base of each range).
  static const int severityTrace = 1;
  static const int severityDebug = 5;
  static const int severityInfo = 9;
  static const int severityWarn = 13;
  static const int severityError = 17;
  static const int severityFatal = 21;

  /// Resolve an [OtelSeverity] from a `package:logging` [Level].
  OtelSeverity fromLevel(Level level) => fromValue(level.value, level.name);

  /// Resolve an [OtelSeverity] from a raw level [value] and optional [name].
  ///
  /// The [name] is lower-cased and used as the `severityText`. When omitted the
  /// canonical OTLP label for the bucket is used.
  OtelSeverity fromValue(int value, [String? name]) {
    final int number;
    final String fallbackText;

    if (value < 500) {
      number = severityTrace;
      fallbackText = 'trace';
    } else if (value < 800) {
      number = severityDebug;
      fallbackText = 'debug';
    } else if (value < 900) {
      number = severityInfo;
      fallbackText = 'info';
    } else if (value < 1000) {
      number = severityWarn;
      fallbackText = 'warn';
    } else if (value < 1200) {
      number = severityError;
      fallbackText = 'error';
    } else {
      number = severityFatal;
      fallbackText = 'fatal';
    }

    final text =
        (name != null && name.isNotEmpty) ? name.toLowerCase() : fallbackText;

    return OtelSeverity(number, text);
  }
}
