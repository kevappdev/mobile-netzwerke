Map<String, dynamic>? toStrDynMap(Object? o) {
  if (o is Map) {
    final out = <String, dynamic>{};
    o.forEach((k, v) {
      out[k.toString()] = v;
    });
    return out;
  }
  return null;
}


