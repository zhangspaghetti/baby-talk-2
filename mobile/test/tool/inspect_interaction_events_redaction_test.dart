import 'package:flutter_test/flutter_test.dart';

import '../../tool/inspect_interaction_events.dart';

void main() {
  test('inspect redaction 会脱敏手机号、验证码与敏感凭据字段', () {
    const raw =
        'request timeout token=secret 13800138000 246810 session=abc sessionId=sess-123 secret=my-secret';

    final redacted = redactSensitiveTextForInspect(raw);

    expect(redacted, isNotNull);
    expect(redacted, contains('token=[REDACTED]'));
    expect(redacted, contains('138****8000'));
    expect(redacted, contains('******'));
    expect(redacted, contains('session=[REDACTED]'));
    expect(redacted, contains('sessionId=[REDACTED]'));
    expect(redacted, contains('secret=[REDACTED]'));
    expect(redacted, isNot(contains('session=abc')));
    expect(redacted, isNot(contains('sess-123')));
    expect(redacted, isNot(contains('my-secret')));
  });
}
