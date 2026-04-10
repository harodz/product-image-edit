/// Best-effort redaction so pipeline logs shown in the UI do not echo secrets.
String redactSecretsInLogLine(String line) {
  if (line.isEmpty) {
    return line;
  }
  var s = line;
  for (final name in [
    'GEMINI_API_KEY',
    'GOOGLE_API_KEY',
  ]) {
    final re = RegExp(
      '${RegExp.escape(name)}\\s*=\\s*[^\\s#]+',
      caseSensitive: false,
    );
    s = s.replaceAll(re, '$name=***');
  }
  // Typical Google API key material (defense if a library prints it).
  s = s.replaceAll(RegExp(r'\bAIza[0-9A-Za-z_-]{20,}\b'), '***');
  return s;
}
