import 'package:test/test.dart';

import '../../tool/verify_practice_ai_helm.dart' as practiceAi;

void main() {
  group('Practice AI Helm verifier', () {
    test(
      'accepts agentic DashScope runtime with isolated app-api credential',
      () {
        expect(
          () => practiceAi.verifyRenderedPracticeAiManifest(
            agenticManifest,
            profile: practiceAi.PracticeAiHelmProfile.agenticQa,
            forbiddenCredentialValues: const {'qa-secret-value'},
          ),
          returnsNormally,
        );
      },
    );

    test('requires agentic runtime to enable custom-scene discovery', () {
      final missingEnabled = agenticManifest.replaceFirst(
        '            enabled: true\n',
        '',
      );

      for (final invalidManifest in <String>[
        missingEnabled,
        agenticManifest.replaceFirst('enabled: true', 'enabled: false'),
      ]) {
        expect(
          () => practiceAi.verifyRenderedPracticeAiManifest(
            invalidManifest,
            profile: practiceAi.PracticeAiHelmProfile.agenticQa,
          ),
          throwsA(isA<practiceAi.PracticeAiHelmVerificationException>()),
        );
      }
    });

    test('rejects provider routes that are duplicate or unknown', () {
      expect(
        () => practiceAi.verifyRenderedPracticeAiManifest(
          agenticManifest.replaceFirst(
            '              - dashscope-qwen\n          custom-scene-quality-judge:',
            '              - dashscope-qwen\n              - dashscope-qwen\n          custom-scene-quality-judge:',
          ),
          profile: practiceAi.PracticeAiHelmProfile.agenticQa,
        ),
        throwsA(isA<practiceAi.PracticeAiHelmVerificationException>()),
      );
      expect(
        () => practiceAi.verifyRenderedPracticeAiManifest(
          agenticManifest.replaceFirst(
            '              - dashscope-qwen\n          custom-scene-repair:',
            '              - unknown-provider\n          custom-scene-repair:',
          ),
          profile: practiceAi.PracticeAiHelmProfile.agenticQa,
        ),
        throwsA(isA<practiceAi.PracticeAiHelmVerificationException>()),
      );
    });

    test(
      'rejects hidden retry fields, non-positive timeout, and two token limits',
      () {
        for (final invalidRuntimeLine in <String>[
          '            retry-attempts: 2\n',
          '            timeout: 0s\n',
          '            max-completion-tokens: 600\n',
        ]) {
          final manifest = invalidRuntimeLine == '            timeout: 0s\n'
              ? agenticManifest.replaceFirst(
                  '            timeout: 20s\n',
                  invalidRuntimeLine,
                )
              : agenticManifest.replaceFirst(
                  '            max-tokens: 600\n',
                  '            max-tokens: 600\n$invalidRuntimeLine',
                );
          expect(
            () => practiceAi.verifyRenderedPracticeAiManifest(
              manifest,
              profile: practiceAi.PracticeAiHelmProfile.agenticQa,
            ),
            throwsA(isA<practiceAi.PracticeAiHelmVerificationException>()),
          );
        }
      },
    );

    test('rejects provider credentials outside dedicated secret or app-api', () {
      final leakedCredential = agenticManifest.replaceFirst(
        '        checksum/practice-ai-runtime: abc123',
        '        checksum/practice-ai-runtime: qa-secret-value',
      );
      expect(
        () => practiceAi.verifyRenderedPracticeAiManifest(
          leakedCredential,
          profile: practiceAi.PracticeAiHelmProfile.agenticQa,
          forbiddenCredentialValues: const {'qa-secret-value'},
        ),
        throwsA(isA<practiceAi.PracticeAiHelmVerificationException>()),
      );

      final workloadLeak = agenticManifest.replaceFirst(
        'kind: Deployment\nmetadata:\n  name: app-api',
        'kind: Deployment\nmetadata:\n  name: gateway\n  labels:\n    app.kubernetes.io/component: gateway\nspec:\n  template:\n    spec:\n      containers:\n        - name: gateway\n          env:\n            - name: BABY_TALK_AI_PROVIDER_DASHSCOPE_QWEN_API_KEY\n              valueFrom:\n                secretKeyRef:\n                  name: practice-ai-secret\n                  key: BABY_TALK_AI_PROVIDER_DASHSCOPE_QWEN_API_KEY\n---\nkind: Deployment\nmetadata:\n  name: app-api',
      );
      expect(
        () => practiceAi.verifyRenderedPracticeAiManifest(
          workloadLeak,
          profile: practiceAi.PracticeAiHelmProfile.agenticQa,
        ),
        throwsA(isA<practiceAi.PracticeAiHelmVerificationException>()),
      );
    });

    test(
      'rejects a production fake profile and validates application fallback removal',
      () {
        expect(
          () => practiceAi.verifyRenderedPracticeAiManifest(
            fakeManifest,
            profile: practiceAi.PracticeAiHelmProfile.production,
          ),
          throwsA(isA<practiceAi.PracticeAiHelmVerificationException>()),
        );
        expect(
          () => practiceAi.verifyBundledApplicationYaml('''
app:
  ai:
    providers:
      primary: {}
'''),
          throwsA(isA<practiceAi.PracticeAiHelmVerificationException>()),
        );
        expect(
          () => practiceAi.verifyBundledApplicationYaml('''
babytalk:
  practice:
    discovery:
      custom-scene:
        max-generation-attempts: 2
'''),
          returnsNormally,
        );
      },
    );

    test('rejects every root app.ai YAML shape', () {
      for (final bundledYaml in <String>[
        '''
app:
    ai: {providers: {}}
''',
        '''
app: {ai: {providers: {}}}
''',
        '''
"app": {'ai': {providers: {}}}
''',
        '''
{app: {ai: {providers: {}}}}
''',
        '''
app.ai.providers: {}
''',
        '''
app: {'ai.providers': {}}
''',
        '''
app: *possibly-containing-ai
''',
        '''
!!str app:
  ai: {providers: {}}
''',
        '''
app:
  !!str ai: {providers: {}}
''',
      ]) {
        expect(
          () => practiceAi.verifyBundledApplicationYaml(bundledYaml),
          throwsA(isA<practiceAi.PracticeAiHelmVerificationException>()),
          reason: bundledYaml,
        );
      }

      expect(
        () => practiceAi.verifyBundledApplicationYaml('''
# app: {ai: {providers: {}}}
application: {ai: {providers: {}}}
feature:
  app:
    ai: {providers: {}}
'''),
        returnsNormally,
      );
    });

    test(
      'requires managed QA secret checksum and external production rollout marker',
      () {
        expect(
          () => practiceAi.verifyRenderedPracticeAiManifest(
            agenticManifest,
            profile: practiceAi.PracticeAiHelmProfile.agenticQa,
          ),
          returnsNormally,
        );
        expect(
          () => practiceAi.verifyRenderedPracticeAiManifest(
            agenticManifest.replaceFirst(
              '        checksum/practice-ai-secret: ${_checksumA}\n',
              '',
            ),
            profile: practiceAi.PracticeAiHelmProfile.agenticQa,
          ),
          throwsA(isA<practiceAi.PracticeAiHelmVerificationException>()),
        );

        final productionManifest = _productionManifest('rotation-1');
        expect(
          () => practiceAi.verifyRenderedPracticeAiManifest(
            productionManifest,
            profile: practiceAi.PracticeAiHelmProfile.production,
          ),
          returnsNormally,
        );
        for (final invalidManifest in <String>[
          productionManifest.replaceFirst(
            '        rollout/practice-ai-secret: "rotation-1"\n',
            '',
          ),
          productionManifest.replaceFirst('"rotation-1"', '""'),
          agenticManifest,
        ]) {
          expect(
            () => practiceAi.verifyRenderedPracticeAiManifest(
              invalidManifest,
              profile: practiceAi.PracticeAiHelmProfile.production,
            ),
            throwsA(isA<practiceAi.PracticeAiHelmVerificationException>()),
          );
        }
      },
    );
  });
}

const _checksumA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

String _productionManifest(String rolloutVersion) {
  return agenticManifest
      .replaceFirst(
        RegExp(
          r'---\napiVersion: v1\nkind: Secret\nmetadata:\n'
          r'  name: practice-ai-secret\n.*?(?=---\napiVersion: apps/v1)',
          dotAll: true,
        ),
        '',
      )
      .replaceFirst(
        '        checksum/practice-ai-secret: $_checksumA\n',
        '        rollout/practice-ai-secret: "$rolloutVersion"\n',
      );
}

const agenticManifest =
    '''
apiVersion: v1
kind: ConfigMap
metadata:
  name: practice-ai-runtime
data:
  practice-ai-runtime.yml: |
    babytalk:
      practice:
        discovery:
          custom-scene:
            enabled: true
            provider-mode: agentic
    app:
      ai:
        routing-policy:
          version: custom-scene-routing-v1
        providers:
          dashscope-qwen:
            type: openai-compatible
            base-url: https://dashscope.aliyuncs.com/compatible-mode/v1
            api-key-environment-variable: BABY_TALK_AI_PROVIDER_DASHSCOPE_QWEN_API_KEY
            model: qwen3.6-flash
            timeout: 20s
            max-tokens: 600
        capabilities:
          custom-scene-generator:
            provider-names:
              - dashscope-qwen
          custom-scene-quality-judge:
            provider-names:
              - dashscope-qwen
          custom-scene-repair:
            provider-names:
              - dashscope-qwen
---
apiVersion: v1
kind: Secret
metadata:
  name: practice-ai-secret
type: Opaque
data:
  BABY_TALK_AI_PROVIDER_DASHSCOPE_QWEN_API_KEY: cWEtc2VjcmV0LXZhbHVl
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-api
  labels:
    app.kubernetes.io/component: app-api
spec:
  template:
    metadata:
      annotations:
        checksum/practice-ai-runtime: abc123
        checksum/practice-ai-secret: $_checksumA
    spec:
      containers:
        - name: app-api
          env:
            - name: SPRING_CONFIG_ADDITIONAL_LOCATION
              value: /config/practice-ai-runtime.yml
            - name: BABY_TALK_AI_PROVIDER_DASHSCOPE_QWEN_API_KEY
              valueFrom:
                secretKeyRef:
                  name: practice-ai-secret
                  key: BABY_TALK_AI_PROVIDER_DASHSCOPE_QWEN_API_KEY
          volumeMounts:
            - name: practice-ai-runtime
              mountPath: /config/practice-ai-runtime.yml
              subPath: practice-ai-runtime.yml
      volumes:
        - name: practice-ai-runtime
          configMap:
            name: practice-ai-runtime
''';

const fakeManifest = '''
apiVersion: v1
kind: ConfigMap
metadata:
  name: practice-ai-runtime
data:
  practice-ai-runtime.yml: |
    babytalk:
      practice:
        discovery:
          custom-scene:
            provider-mode: fake
    app:
      ai:
        routing-policy:
          version: custom-scene-routing-v1
        providers: {}
        capabilities:
          custom-scene-generator:
            provider-names: []
          custom-scene-quality-judge:
            provider-names: []
          custom-scene-repair:
            provider-names: []
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-api
  labels:
    app.kubernetes.io/component: app-api
spec:
  template:
    metadata:
      annotations:
        checksum/practice-ai-runtime: abc123
    spec:
      containers:
        - name: app-api
          env:
            - name: SPRING_CONFIG_ADDITIONAL_LOCATION
              value: /config/practice-ai-runtime.yml
          volumeMounts:
            - name: practice-ai-runtime
              mountPath: /config/practice-ai-runtime.yml
              subPath: practice-ai-runtime.yml
      volumes:
        - name: practice-ai-runtime
          configMap:
            name: practice-ai-runtime
''';
