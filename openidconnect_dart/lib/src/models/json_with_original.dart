import 'package:json_annotation/json_annotation.dart';

Object? readSelf(Map<dynamic, dynamic> src, String key) {
  return src;
}

Duration? durationFromSeconds(int? value) {
  if (value == null) return null;
  return Duration(seconds: value);
}

Duration requiredDurationFromSeconds(int value) {
  return Duration(seconds: value);
}

class JsonObjectWithOriginal {
  @JsonKey(
    readValue: readSelf,
    name: '',
    includeToJson: false,
    includeFromJson: true,
  )
  final Map<String, dynamic> src;

  const JsonObjectWithOriginal({required this.src});
}
