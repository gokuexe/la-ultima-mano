import 'package:flutter/material.dart';
import '../daily_challenge.dart';
import '../theme.dart';
import '../l10n/game_text.dart';
import 'game_screen.dart';

class DailyScreen extends StatefulWidget {
  final DateTime Function()? now;
  const DailyScreen({super.key, this.now});
  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen> with WidgetsBindingObserver {
  bool _busy = false;
  DateTime get _now => (widget.now ?? DateTime.now)();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  Future<void> _play() async {
    if (_busy) return;
    setState(() => _busy = true);
    final challenge = DailyChallenge.at(_now);
    final attempt = await DailyProgress.instance.start(challenge.day);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => GameScreen(daily: challenge, dailyAttempt: attempt)));
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final challenge = DailyChallenge.at(_now);
    return Scaffold(
      appBar: AppBar(title: const GameText('LA MANO DE HOY')),
      body: ListenableBuilder(
          listenable: DailyProgress.instance,
          builder: (context, _) {
            final score = DailyProgress.instance.forDay(challenge.day);
            return Center(
                child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child:
                        ListView(padding: const EdgeInsets.all(24), children: [
                      GameText(challenge.day,
                          translate: false, style: SS.title),
                      const SizedBox(height: 16),
                      const GameText(
                          'El mismo reparto inicial para todo el mundo. Intentá escapar en la menor cantidad de turnos propios.',
                          style: SS.body),
                      const SizedBox(height: 12),
                      const GameText(
                          'Podés repetir. Tu mejor victoria se guarda en este equipo. El reparto cambia cada día a las 00:00 UTC.',
                          style: SS.sub),
                      const SizedBox(height: 20),
                      GameText(
                          score.best == null
                              ? 'Todavía no escapaste de esta mano.'
                              : 'Mejor victoria: ${score.best} turnos',
                          style: SS.title),
                      GameText('Intentos: ${score.attempts}', style: SS.body),
                      FilledButton(
                          key: const ValueKey('start-daily'),
                          onPressed: _busy ? null : _play,
                          child: const GameText('JUGAR LA MANO DE HOY')),
                      if (DailyProgress.instance.saveError != null)
                        GameText(DailyProgress.instance.saveError!,
                            style: SS.sub),
                    ])));
          }),
    );
  }
}
