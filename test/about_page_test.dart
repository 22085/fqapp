import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fqapp/pages/about_page.dart';
import 'package:fqapp/services/app_theme.dart';

/// 关于页：只留版本行，点按复制版本号。
void main() {
  Future<void> pumpAbout(WidgetTester tester) async {
    // 页面内容高于默认 800x600 视口，ListView 外的行不会被构建；
    // 拉高测试视口让整页一次排完，断言才能覆盖每一行。
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 1800);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.createTheme(Brightness.light),
        home: const AboutPage(),
      ),
    );
    await tester.pump();
  }

  testWidgets('关于页只渲染版本行', (tester) async {
    await pumpAbout(tester);

    expect(find.text('什锦铺'), findsOneWidget);
    expect(find.text('小说 / 短剧 / 漫剧 / 漫画 / 听书聚合客户端'), findsOneWidget);
    expect(find.text('项目介绍'), findsNothing);
    expect(
      find.textContaining('所有签名与解密都在你的手机本地完成'),
      findsNothing,
    );

    expect(find.text('当前版本'), findsOneWidget);
    expect(find.text(AboutPage.versionText), findsOneWidget);
    expect(find.text('检查更新'), findsNothing);
    expect(find.text('开源许可'), findsNothing);
    expect(find.text('GPL-3.0 与第三方组件许可'), findsNothing);
    expect(find.text('Source Code'), findsNothing);
    expect(find.text('问题反馈'), findsNothing);

    expect(find.text('支持作者'), findsNothing);
    expect(find.text('前往爱发电'), findsNothing);
    expect(find.text('微信赞赏'), findsNothing);
    expect(find.textContaining('仅限个人学习研究使用'), findsNothing);
  });

  testWidgets('点当前版本行复制版本号并提示', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );

    await pumpAbout(tester);
    await tester.tap(find.text('当前版本'));
    await tester.pump();

    expect(copied, AboutPage.versionText);
    expect(find.text('已复制版本号'), findsOneWidget);
  });
}
