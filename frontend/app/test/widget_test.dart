// 应用启动冒烟测试：验证主导航壳正常渲染。
//
// 测试环境无法访问后端（dio 连接超时后 Feed 呈现错误重试态），
// 因此只断言底部导航与页面骨架存在。
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:shortplay_app/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('应用启动冒烟测试：渲染主导航壳', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final authCubit = await bootstrap();
    await tester.pumpWidget(ShortplayApp(authCubit: authCubit));

    // 首帧：底部导航四个入口可见。
    await tester.pump();
    expect(find.text('首页'), findsOneWidget);
    expect(find.text('消息'), findsOneWidget);
    expect(find.text('我的'), findsOneWidget);

    // 快进 16 秒让 Feed 的网络请求超时（测试环境无后端），
    // 页面应呈现「加载失败 + 重试」而不是白屏挂死。
    await tester.pump(const Duration(seconds: 16));
    await tester.pump();
    expect(find.text('重试'), findsOneWidget);
  });
}
