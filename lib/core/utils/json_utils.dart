Map<String, dynamic> deepCopyMap(Map<String, dynamic> source) {
  return {
    for (final entry in source.entries) entry.key: deepCopyJsonValue(entry.value),
  };
}

dynamic deepCopyJsonValue(dynamic value) {
  if (value is Map) return deepCopyMap(Map<String, dynamic>.from(value));
  if (value is List) return value.map(deepCopyJsonValue).toList();
  return value;
}

void mergeMapDeep(Map<String, dynamic> target, Map<String, dynamic> updates) {
  for (final entry in updates.entries) {
    final value = entry.value;
    if (value is Map && target[entry.key] is Map) {
      final nestedTarget = Map<String, dynamic>.from(target[entry.key] as Map);
      mergeMapDeep(nestedTarget, Map<String, dynamic>.from(value));
      target[entry.key] = nestedTarget;
    } else {
      target[entry.key] = deepCopyJsonValue(value);
    }
  }
}
