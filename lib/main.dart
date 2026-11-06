import 'l10n/game_text.dart';
import 'l10n/language_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter/services.dart';

import 'game_config.dart';
import 'story.dart';
import 'ui/pixel_art.dart';
import 'sfx.dart';
import 'theme.dart';
import 'ui/game_screen.dart';
import 'ui/online_lobby.dart';
import 'ui/archive_screen.dart';
import 'ui/album_screen.dart';
import 'play_preferences.dart';
import 'portal/portal_ads.dart';
import 'story_progress.dart';
import 'collection_progress.dart';
import 'daily_challenge.dart';
import 'campaign.dart';
import 'rooms.dart';
import 'ui/daily_screen.dart';
import 'ui/campaign_screen.dart';
import 'ui/rooms_screen.dart';
import 'platform/local_store.dart';
import 'ui/chapter_screen.dart';
import 'ui/options_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PlayPreferences.instance.load();
  await StoryProgress.instance.load();
  CollectionProgress.instance =
      CollectionProgress(store: createStore('collection'));
  await CollectionProgress.instance.load();
  DailyProgress.instance = DailyProgress(store: createStore('daily'));
  await DailyProgress.instance.load();
  CampaignProgress.instance = CampaignProgress(store: createStore('campaign'));
  await CampaignProgress.instance
      .load(firstChapterComplete: StoryProgress.instance.chapterComplete);
  RoomProgress.instance = RoomProgress(store: createStore('rooms'));
  await RoomProgress.instance.load();
  PortalAds.instance.initialize();
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
    return ListenableBuilder(
        listenable: PlayPreferences.instance,
        builder: (context, _) => MaterialApp(
              title: Story.title,
              locale: Locale(PlayPreferences.instance.language),
              supportedLocales: const [Locale('es'), Locale('en')],
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              debugShowCheckedModeBanner: false,
              theme: SS.theme(),
              builder: (context, child) => ColoredBox(
                color: SS.table,
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    disableAnimations:
                        MediaQuery.disableAnimationsOf(context) ||
                            PlayPreferences.instance.reduceMotion,
                    textScaler: MediaQuery.textScalerOf(context).clamp(
                        minScaleFactor: PlayPreferences.instance.textScale),
                  ),
                  child: LanguageScope(
                      language: PlayPreferences.instance.language,
                      child: ListenableBuilder(
                          listenable: PortalAds.instance,
                          builder: (context, _) => Stack(children: [
                                Positioned.fill(
                                    child: _ResponsiveStage(child: child!)),
                                if (PortalAds.instance.blocked) ...[
                                  const ModalBarrier(
                                      dismissible: false,
                                      color: Color(0xE6101015)),
                                  const Center(
                                      child: Material(
                                          color: Colors.transparent,
                                          child: GameText('PAUSA PUBLICITARIA',
                                              style: SS.title))),
                                ],
                              ]))),
                ),
              ),
              home: const TitleScreen(),
            ));
  }
}

/// Use the actual viewport. SafeArea accounts for status/navigation bars and cutouts.
/// Wide desktop windows keep a readable column without shrinking any text.
class _ResponsiveStage extends StatelessWidget {
  final Widget child;
  const _ResponsiveStage({required this.child});
  @override
  Widget build(BuildContext context) => SafeArea(
      child: Center(
          child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: SizedBox.expand(child: child))));
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

  bool _starting = false;
  Future<void> _begin() async {
    if (_starting) return;
    setState(() => _starting = true);
    Sfx.i.tap();
    try {
      await PortalAds.instance.requestBreak();
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => GameScreen(rules: GameRules.balanced(_mode))));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
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
            if (!MediaQuery.disableAnimationsOf(context))
              IgnorePointer(
                  child: AnimatedBuilder(
                      animation: _ambience,
                      builder: (_, __) =>
                          CustomPaint(painter: PixelDust(_ambience.value)))),
            SafeArea(
                child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 22),
              child: LayoutBuilder(
                  builder: (context, box) => SingleChildScrollView(
                      child: ConstrainedBox(
                          constraints: BoxConstraints(minHeight: box.maxHeight),
                          child: IntrinsicHeight(
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                const LanguagePicker(),
                                FilledButton(
                                    onPressed: () => Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                            builder: (_) =>
                                                const DailyScreen())),
                                    child: const GameText('LA MANO DE HOY')),
                                OutlinedButton(
                                    onPressed: () => Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                            builder: (_) =>
                                                const CampaignScreen())),
                                    child: const GameText(
                                        'TRES NOCHES · HISTORIA')),
                                const GameText('EDICIÓN PULSO',
                                    style: SS.sub, textAlign: TextAlign.center),
                                OutlinedButton(
                                  onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                          builder: (_) =>
                                              const ChapterScreen())),
                                  child: const GameText('PRÓLOGO Y PRÁCTICA'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                          builder: (_) =>
                                              const ArchiveScreen())),
                                  child: const GameText(
                                      'ARCHIVO 067  /  NO CONFIAR EN NADIE',
                                      textAlign: TextAlign.center,
                                      style: SS.sub),
                                ),
                                ListenableBuilder(
                                  listenable: CollectionProgress.instance,
                                  builder: (context, _) => TextButton.icon(
                                    key: const ValueKey('open-memory-album'),
                                    icon:
                                        const Icon(Icons.auto_stories_outlined),
                                    onPressed: () => Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                            builder: (_) =>
                                                const AlbumScreen())),
                                    label: GameText(
                                        'ÁLBUM DE RECUERDOS · ${CollectionProgress.instance.memories.length}/6'),
                                  ),
                                ),
                                const Spacer(flex: 3),
                                GameText('LA ÚLTIMA\nMANO',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontFamily: 'Pixelify',
                                        fontSize:
                                            (MediaQuery.sizeOf(context).width /
                                                    8.5)
                                                .clamp(32, 58),
                                        height: 0.95,
                                        letterSpacing: 3,
                                        color: SS.ink,
                                        shadows: [
                                          Shadow(
                                              color: Color(0xFF09090C),
                                              offset: Offset(4, 4))
                                        ])),
                                const SizedBox(height: 16),
                                const GameText(Story.subtitle,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 10,
                                        letterSpacing: 2,
                                        color: SS.mana)),
                                const Spacer(),
                                const GameText(Story.opening,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                        fontSize: 16,
                                        height: 1.55,
                                        color: SS.ink)),
                                const SizedBox(height: 24),
                                const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      PixelSigil(
                                          seed: 6, color: SS.rojoUp, size: 28),
                                      SizedBox(width: 16),
                                      GameText('6  /  7', style: SS.title),
                                      SizedBox(width: 16),
                                      PixelSigil(
                                          seed: 7, color: SS.azulUp, size: 28),
                                    ]),
                                const SizedBox(height: 12),
                                const GameText(Story.objective,
                                    textAlign: TextAlign.center, style: SS.sub),
                                const Spacer(),
                                const GameText('ELEGÍ CÓMO RECORDAR',
                                    textAlign: TextAlign.center, style: SS.sub),
                                const SizedBox(height: 12),
                                Row(children: [
                                  for (final mode in GameMode.values)
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 3),
                                        child: OutlinedButton(
                                          style: OutlinedButton.styleFrom(
                                            shape:
                                                const RoundedRectangleBorder(),
                                            side: BorderSide(
                                                color: _mode == mode
                                                    ? SS.mana
                                                    : SS.line,
                                                width: 2),
                                            foregroundColor: _mode == mode
                                                ? SS.mana
                                                : SS.mute,
                                            backgroundColor:
                                                SS.table.withValues(alpha: 0.8),
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 14),
                                          ),
                                          onPressed: () =>
                                              setState(() => _mode = mode),
                                          child: GameText(
                                              GameRules.balanced(mode).label),
                                        ),
                                      ),
                                    )
                                ]),
                                const SizedBox(height: 10),
                                ConstrainedBox(
                                    constraints:
                                        const BoxConstraints(minHeight: 42),
                                    child: GameText(
                                        GameRules.balanced(_mode).blurb,
                                        textAlign: TextAlign.center,
                                        style: SS.sub)),
                                const SizedBox(height: 10),
                                FilledButton(
                                  style: FilledButton.styleFrom(
                                      shape: const RoundedRectangleBorder(),
                                      backgroundColor: SS.mana,
                                      foregroundColor: SS.table,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 18)),
                                  onPressed: _starting ? null : _begin,
                                  child: const GameText('SENTARSE A LA MESA',
                                      style: TextStyle(
                                          fontSize: 19, letterSpacing: 2)),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                          builder: (_) =>
                                              const OnlineLobbyScreen())),
                                  child: const GameText(
                                      'JUGAR ONLINE · SALA PRIVADA',
                                      style: TextStyle(color: SS.azulUp)),
                                ),
                                TextButton(
                                    onPressed: () => Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                            builder: (_) =>
                                                const OptionsScreen())),
                                    child: const GameText(
                                        'AJUSTES Y GUÍA DE CARTAS')),
                                TextButton(
                                    onPressed: () => Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                            builder: (_) =>
                                                const RoomsScreen())),
                                    child: const GameText('HABITACIONES')),
                                const SizedBox(height: 10),
                                const GameText(
                                    'Tres desconocidos. Una salida. Ningún reloj.',
                                    textAlign: TextAlign.center,
                                    style: SS.sub),
                              ]))))),
            )),
          ],
        ),
      );
}
