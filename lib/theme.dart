import 'package:flutter/material.dart';

/// A limited palette: old paper, bruised shadows and amber lamplight.
class SS {
  static const readingFamily = 'LiberationSans';
  static const table = Color(0xFF101015);
  static const tableUp = Color(0xFF242029);
  static const surface = Color(0xFF211F26);
  static const surfaceUp = Color(0xFF302B32);
  static const line = Color(0xFF65584F);
  static const rojo = Color(0xFFA04E54);
  static const rojoUp = Color(0xFFD7837C);
  static const azul = Color(0xFF527F83);
  static const azulUp = Color(0xFF8DB3AE);
  static const mana = Color(0xFFCEA86B);
  static const win = Color(0xFFA6B58A);
  static const react = Color(0xFF9C8BA9);
  static const ink = Color(0xFFE3D7BF);
  static const mute = Color(0xFFA79B8D);
  static Color of(bool red) => red ? rojo : azul;
  static Color upOf(bool red) => red ? rojoUp : azulUp;
  static const title = TextStyle(
      fontFamily: readingFamily,
      fontSize: 22,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
      color: ink);
  static const sub = TextStyle(fontSize: 14, color: mute, height: 1.4);
  static const body = TextStyle(fontSize: 16, color: ink, height: 1.4);
  static const numStyle = TextStyle(
      fontFamily: readingFamily,
      fontFeatures: [FontFeature.tabularFigures()],
      fontWeight: FontWeight.w700,
      color: ink);
  static ThemeData theme() => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: table,
        fontFamily: readingFamily,
        colorScheme: const ColorScheme.dark(
            primary: mana, secondary: azul, surface: surface),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 16, height: 1.4),
          bodySmall: TextStyle(fontSize: 14, height: 1.4),
          labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        tooltipTheme: const TooltipThemeData(textStyle: body),
      );
  static BoxDecoration tableBg() => const BoxDecoration(
        image: DecorationImage(
            image: AssetImage('assets/art/room.png'),
            fit: BoxFit.cover,
            filterQuality: FilterQuality.none,
            opacity: 0.16),
        gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [tableUp, table]),
      );
  static BoxDecoration panel({Color accent = line, bool raised = false}) =>
      BoxDecoration(
        color: raised ? surfaceUp : surface,
        border: Border.all(color: accent, width: 2),
        boxShadow: const [
          BoxShadow(color: Color(0xFF09090C), offset: Offset(4, 4))
        ],
      );
}
