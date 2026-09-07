import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'controllers/contact_controller.dart';
import 'screens/home_screen.dart';

class TaggedContactApp extends StatelessWidget {
  const TaggedContactApp({super.key, required this.controller});

  final ContactController controller;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      final settings = controller.settings;
      final colors = ColorScheme.fromSeed(
        seedColor: const Color(0xFF286653),
        brightness: Brightness.light,
        primary: const Color(0xFF286653),
        surface: const Color(0xFFFFFEFA),
        onSurface: Color(settings.textColor),
      );
      final theme = ThemeData(
        useMaterial3: true,
        colorScheme: colors,
        scaffoldBackgroundColor: Color(settings.backgroundColor),
        fontFamily: 'sans-serif',
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: colors.surface,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: colors.outlineVariant),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        chipTheme: ChipThemeData(
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: colors.surface,
          indicatorColor: const Color(0xFFDAE9DD),
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(
              color: colors.onSurface,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
      return MaterialApp(
        title: '태그연락처',
        debugShowCheckedModeBanner: false,
        locale: const Locale('ko'),
        supportedLocales: const [Locale('ko')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: theme.copyWith(
          textTheme: theme.textTheme.apply(
            bodyColor: Color(settings.textColor),
            displayColor: Color(settings.textColor),
          ),
        ),
        builder: (context, child) {
          final media = MediaQuery.of(context);
          // 기기의 접근성 글자 배율에 사용자가 선택한 배율을 더한다.
          return MediaQuery(
            data: media.copyWith(
              textScaler: TextScaler.linear(
                media.textScaler.scale(settings.fontScale),
              ),
            ),
            child: child!,
          );
        },
        home: HomeScreen(controller: controller),
      );
    },
  );
}
