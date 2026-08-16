import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app/theme/app_theme.dart';
import 'package:mobile/core/runtime/candidate_build_identity.dart';
import 'package:mobile/features/settings/presentation/screens/about_screen.dart';
import 'package:mobile/features/settings/presentation/screens/help_feedback_screen.dart';

void main() {
  testWidgets('Help describes actual remote sync and retains no TODO actions', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.build(), home: const HelpFeedbackScreen()),
    );

    await tester.tap(find.text('数据会同步到云端吗？'));
    await tester.pumpAndSettle();

    expect(
      find.text('登录后，宝宝档案、照护记录和家庭共享信息会与账号云端数据同步；未登录或网络不可用时，App 只使用本机可用的缓存。'),
      findsOneWidget,
    );
    expect(find.text('当前版本所有数据仅存储在本地设备，不会上传到服务器。'), findsNothing);
    expect(find.text('发送邮件'), findsNothing);
    expect(find.text('给我们评分'), findsNothing);
  });

  testWidgets('About displays immutable build and candidate identity only', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.build(), home: const AboutScreen()),
    );

    expect(
      find.text(CandidateBuildIdentity.current.appVersion),
      findsOneWidget,
    );
    expect(
      find.text(CandidateBuildIdentity.current.candidateId),
      findsOneWidget,
    );
    expect(find.text('数据存储'), findsOneWidget);
    expect(find.text('本地缓存与已登录账号云端数据'), findsOneWidget);
    expect(find.text('隐私政策'), findsNothing);
    expect(find.text('用户协议'), findsNothing);
  });
}
