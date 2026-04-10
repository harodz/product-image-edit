import 'package:flutter_test/flutter_test.dart';
import 'package:product_image_edit_frontend/utils/log_redaction.dart';

void main() {
  test('redacts GEMINI_API_KEY assignments in log lines', () {
    expect(
      redactSecretsInLogLine('export GEMINI_API_KEY=secret123'),
      'export GEMINI_API_KEY=***',
    );
    expect(
      redactSecretsInLogLine('GOOGLE_API_KEY=abc'),
      'GOOGLE_API_KEY=***',
    );
  });

  test('redacts typical AIza-prefixed material', () {
    expect(
      redactSecretsInLogLine('token AIzaSyDummyKeyMaterialForTestRedaction_xxxxx end'),
      'token *** end',
    );
  });
}
