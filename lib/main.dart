import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'game_config.dart';
import 'story.dart';
import 'ui/pixel_art.dart';
import 'sfx.dart';
import 'theme.dart';
import 'ui/game_screen.dart';
import 'ui/online_lobby.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }
  runApp(const LaUltimaManoApp());
}

class LaUltimaManoApp extends StatelessWidget {
  const LaUltimaManoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: Story.title,
      debugShowCheckedModeBanner: false,
      theme: SS.theme(),
      // El juego está pensado para un celular. En una ventana de escritorio
      // mucho más ancha (o más alta) que eso, en vez de dejarlo fijo y chico
      // con bandas vacías a los costados, se escala para aprovechar el alto
      // disponible, como haría un emulador.
      builder: (context, child) => ColoredBox(
        color: SS.table,
        child: _ResponsiveStage(child: child!),
      ),
      home: const TitleScreen(),
    );
  }
}

/// Escala el diseño (pensado para ~480×860) al alto disponible, sin
/// reescribir ninguna pantalla: todo el árbol de widgets sigue creyendo
/// que vive en esas medidas, solo se pinta más grande o más chico.
///
/// En una ventana bien panorámica, escalar solo por el alto deja el diseño
/// angosto y bandas enormes a los costados: además de escalar, se le da un
/// poco más de ancho de "lienzo" (hasta 620) para que las filas con
/// Expanded/flex de GameScreen se estiren y aprovechen ese espacio, en vez
/// de dejarlo vacío.
class _ResponsiveStage extends StatelessWidget {
  static const double _designMinW = 480;
  static const double _designMaxW = 620;
  // Stage height keeps the table readable on desktop.
  static const double _designH = 960;

  final Widget child;
  const _ResponsiveStage({required this.child});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final heightScale = box.maxHeight / _designH;
        final widthScaleAtMin = box.maxWidth / _designMinW;
        final scale =
            (heightScale < widthScaleAtMin ? heightScale : widthScaleAtMin)
                .clamp(0.7, 1.8)
                .toDouble();
        final designW =
            (box.maxWidth / scale).clamp(_designMinW, _designMaxW).toDouble();
        return Center(
          child: FittedBox(
            fit: BoxFit.contain,
            child: SizedBox(width: designW, height: _designH, child: child),
          ),
        );
      },
    );
  }
}

class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key});
  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen>
    with SingleTickerProviderStateMixin {
  GameMode _mode = GameMode.classic;
  late final AnimationController _ambience = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat();
  @override
  void initState() {
    super.initState();
    Sfx.i.init();
  }

  @override
  void dispose() {
    _ambience.dispose();
    super.dispose();
  }

  void _begin() {
    Sfx.i.tap();
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => GameScreen(rules: GameRules(_mode)),
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/art/room.png',
                fit: BoxFit.cover,
                filterQuality: FilterQuality.none,
                errorBuilder: (_, __, ___) =>
                    const ColoredBox(color: SS.table)),
            const DecoratedBox(
                decoration: BoxDecoration(
              gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x44101015),
                    Color(0xAA101015),
                    Color(0xFF101015)
                  ],
                  stops: [
                    0,
                    0.35,
                    0.8
                  ]),
            )),
            IgnorePointer(
                child: AnimatedBuilder(
                    animation: _ambience,
                    builder: (_, __) =>
                        CustomPaint(painter: PixelDust(_ambience.value)))),
            SafeArea(
                child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 22),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text('ARCHIVO 067  /  NO CONFIAR EN NADIE',
                        textAlign: TextAlign.center, style: SS.sub),
                    const Spacer(flex: 3),
                    const Text('LA ÚLTIMA\nMANO',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontFamily: 'Pixelify',
                            fontSize: 58,
                            height: 0.95,
                            letterSpacing: 3,
                            color: SS.ink,
                            shadows: [
                              Shadow(
                                  color: Color(0xFF09090C),
                                  offset: Offset(4, 4))
                            ])),
                    const SizedBox(height: 16),
                    const Text(Story.subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 10, letterSpacing: 2, color: SS.mana)),
                    const Spacer(),
                    const Text(Story.opening,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 16, height: 1.55, color: SS.ink)),
                    const SizedBox(height: 24),
                    const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          PixelSigil(seed: 6, color: SS.rojoUp, size: 28),
                          SizedBox(width: 16),
                          Text('6  /  7', style: SS.title),
                          SizedBox(width: 16),
                          PixelSigil(seed: 7, color: SS.azulUp, size: 28),
                        ]),
                    const SizedBox(height: 12),
                    const Text(Story.objective,
                        textAlign: TextAlign.center, style: SS.sub),
                    const Spacer(),
                    const Text('ELEGÍ CÓMO RECORDAR',
                        textAlign: TextAlign.center, style: SS.sub),
                    const SizedBox(height: 12),
                    Row(children: [
                      for (final mode in GameMode.values)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                shape: const RoundedRectangleBorder(),
                                side: BorderSide(
                                    color: _mode == mode ? SS.mana : SS.line,
                                    width: 2),
                                foregroundColor:
                                    _mode == mode ? SS.mana : SS.mute,
                                backgroundColor:
                                    SS.table.withValues(alpha: 0.8),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 14),
                              ),
                              onPressed: () => setState(() => _mode = mode),
                              child: Text(GameRules(mode).label),
                            ),
                          ),
                        )
                    ]),
                    const SizedBox(height: 10),
                    SizedBox(
                        height: 42,
                        child: Text(GameRules(_mode).blurb,
                            textAlign: TextAlign.center, style: SS.sub)),
                    const SizedBox(height: 10),
                    FilledButton(
                      style: FilledButton.styleFrom(
                          shape: const RoundedRectangleBorder(),
                          backgroundColor: SS.mana,
                          foregroundColor: SS.table,
                          padding: const EdgeInsets.symmetric(vertical: 18)),
                      onPressed: _begin,
                      child: const Text('SENTARSE A LA MESA',
                          style: TextStyle(fontSize: 19, letterSpacing: 2)),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) => const OnlineLobbyScreen())),
                      child: const Text('JUGAR ONLINE · SALA PRIVADA',
                          style: TextStyle(color: SS.azulUp)),
                    ),
                    const SizedBox(height: 10),
                    const Text('Tres desconocidos. Una salida. Ningún reloj.',
                        textAlign: TextAlign.center, style: SS.sub),
                  ]),
            )),
          ],
        ),
      );
}
