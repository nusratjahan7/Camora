import 'package:camera_overlay/core/constants/app_constants.dart';
import 'package:camera_overlay/core/theme/app_theme.dart';
import 'package:camera_overlay/features/home/presentation/pages/home_page.dart';
import 'package:camera_overlay/shared/widgets/brand_mark.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home shows the Veylora logo, name and tagline', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(theme: AppTheme.dark, home: const HomePage()),
      ),
    );

    expect(find.byType(BrandMark), findsOneWidget);
    expect(find.bySemanticsLabel('Veylora logo'), findsOneWidget);
    expect(find.text(AppConstants.appName), findsOneWidget);
    expect(find.text('Create what you envision.'), findsOneWidget);
  });

  test('the logo asset is bundled', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final data = await rootBundle.load(BrandMark.asset);
    expect(data.lengthInBytes, greaterThan(0));
  });
}
