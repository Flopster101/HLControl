import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'src/core/controllers/headphone_controller.dart';
import 'src/ui/screens/home_screen.dart';
import 'src/ui/theme/app_theme.dart';
import 'src/ui/theme/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize ThemeController and pre-load settings to avoid splash theme flashing
  final themeController = ThemeController();
  await themeController.loadSettings();

  // Initialize HeadphoneController (coordinates real Bluetooth & simulated states)
  final headphoneController = HeadphoneController(themeController);

  runApp(HlControlApp(
    themeController: themeController,
    headphoneController: headphoneController,
  ));
}

class HlControlApp extends StatelessWidget {
  const HlControlApp({
    super.key,
    required this.themeController,
    required this.headphoneController,
  });

  final ThemeController themeController;
  final HeadphoneController headphoneController;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) {
        return DynamicColorBuilder(
          builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
            final useDynamic = themeController.useDynamicColor &&
                defaultTargetPlatform == TargetPlatform.android;

            return MaterialApp(
              title: 'HL Control',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.buildTheme(
                Brightness.light,
                useDynamic ? lightDynamic : null,
              ),
              darkTheme: AppTheme.buildTheme(
                Brightness.dark,
                useDynamic ? darkDynamic : null,
              ),
              themeMode: themeController.themeMode,
              home: HomeScreen(
                themeController: themeController,
                headphoneController: headphoneController,
              ),
            );
          },
        );
      },
    );
  }
}
