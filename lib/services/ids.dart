import 'package:uuid/uuid.dart';

/// The time source, injected so tests are deterministic. Always UTC.
typedef Clock = DateTime Function();

DateTime systemClock() => DateTime.now().toUtc();

/// New record IDs are UUID v4 (REC-2); tests inject a counter instead.
typedef IdSource = String Function();

const _uuid = Uuid();
String uuidV4() => _uuid.v4();
