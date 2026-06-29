import 'package:logging/logging.dart';
import 'package:otel_logging_dart/otel_logging_dart.dart';
import 'package:test/test.dart';

void main() {
  const mapper = SeverityMapper();

  group('SeverityMapper', () {
    test('maps standard logging levels to OTLP severity numbers', () {
      expect(
          mapper.fromLevel(Level.FINEST).number, SeverityMapper.severityTrace);
      expect(mapper.fromLevel(Level.FINE).number, SeverityMapper.severityDebug);
      expect(
          mapper.fromLevel(Level.CONFIG).number, SeverityMapper.severityDebug);
      expect(mapper.fromLevel(Level.INFO).number, SeverityMapper.severityInfo);
      expect(
          mapper.fromLevel(Level.WARNING).number, SeverityMapper.severityWarn);
      expect(
          mapper.fromLevel(Level.SEVERE).number, SeverityMapper.severityError);
      expect(
          mapper.fromLevel(Level.SHOUT).number, SeverityMapper.severityFatal);
    });

    test('uses the lower-cased level name as severity text', () {
      expect(mapper.fromLevel(Level.INFO).text, 'info');
      expect(mapper.fromLevel(Level.SEVERE).text, 'severe');
    });

    test('buckets arbitrary custom level values', () {
      expect(mapper.fromValue(850).number, SeverityMapper.severityInfo);
      expect(mapper.fromValue(1500).number, SeverityMapper.severityFatal);
      expect(mapper.fromValue(100).number, SeverityMapper.severityTrace);
    });
  });
}
