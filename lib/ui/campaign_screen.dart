import 'package:flutter/material.dart';
import '../campaign.dart';
import '../theme.dart';
import '../l10n/game_text.dart';
import 'game_screen.dart';
import 'room_backdrop.dart';

class CampaignScreen extends StatelessWidget {
  const CampaignScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const GameText('TRES NOCHES')),
        body: ListenableBuilder(
            listenable: CampaignProgress.instance,
            builder: (context, _) => Center(
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 620),
                      child: ListView(
                          padding: const EdgeInsets.all(20),
                          children: [
                            const GameText(
                                'Tres voces recuerdan la misma puerta. Cada noche tiene sus propias reglas, explicadas antes de sentarte.',
                                style: SS.body),
                            const SizedBox(height: 16),
                            for (var i = 0; i < campaignNights.length; i++)
                              Card(
                                  child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            GameText(campaignNights[i].title,
                                                style: SS.title),
                                            GameText(
                                                campaignNights[i].character,
                                                style: SS.sub),
                                            const SizedBox(height: 12),
                                            FilledButton(
                                                onPressed: CampaignProgress
                                                        .instance
                                                        .unlocked(i)
                                                    ? () => Navigator.of(context).push(
                                                        MaterialPageRoute<void>(
                                                            builder: (_) =>
                                                                _NightScreen(
                                                                    night: campaignNights[
                                                                        i])))
                                                    : null,
                                                child: GameText(CampaignProgress
                                                        .instance.completed
                                                        .contains(
                                                            campaignNights[i].id)
                                                    ? 'VOLVER A ESTA NOCHE'
                                                    : CampaignProgress.instance.unlocked(i)
                                                        ? 'ENTRAR A LA NOCHE'
                                                        : 'COMPLETÁ LA NOCHE ANTERIOR')),
                                          ]))),
                            if (CampaignProgress.instance.saveError != null)
                              GameText(CampaignProgress.instance.saveError!,
                                  style: SS.sub),
                          ])),
                )),
      );
}

class _NightScreen extends StatefulWidget {
  final CampaignNight night;
  const _NightScreen({required this.night});
  @override
  State<_NightScreen> createState() => _NightScreenState();
}

class _NightScreenState extends State<_NightScreen> {
  bool _busy = false;
  bool? _won;
  Future<void> _play() async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => GameScreen(night: widget.night)));
    if (mounted) {
      setState(() {
        _busy = false;
        _won = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: GameText(widget.night.title)),
        body: Center(
            child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: ListView(padding: const EdgeInsets.all(20), children: [
                  SizedBox(
                      height: 160,
                      child: CustomPaint(
                          painter: RoomScenePainter(widget.night.room))),
                  const SizedBox(height: 20),
                  GameText(widget.night.character, style: SS.title),
                  GameText(
                      _won == true
                          ? widget.night.ending
                          : _won == false
                              ? 'La puerta se abrió para otra voz. Esta noche todavía te espera.'
                              : widget.night.opening,
                      style: SS.body),
                  const SizedBox(height: 20),
                  const GameText('CONDICIONES DE ESTA NOCHE', style: SS.title),
                  GameText(widget.night.rules.label, style: SS.body),
                  GameText(widget.night.rules.blurb, style: SS.body),
                  const SizedBox(height: 12),
                  const GameText(
                      'Ganar desbloquea la siguiente noche y su habitación. Las derrotas también pueden dejar recuerdos en el álbum.',
                      style: SS.sub),
                  FilledButton(
                      onPressed: _busy ? null : _play,
                      child: const GameText('SENTARSE A ESTA MESA')),
                ]))),
      );
}
