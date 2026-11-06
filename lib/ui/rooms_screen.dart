import 'package:flutter/material.dart';
import '../rooms.dart';
import '../collection_progress.dart';
import '../campaign.dart';
import '../theme.dart';
import '../l10n/game_text.dart';
import 'room_backdrop.dart';

class RoomsScreen extends StatelessWidget {
  const RoomsScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const GameText('HABITACIONES')),
        body: ListenableBuilder(
            listenable: Listenable.merge([
              RoomProgress.instance,
              CollectionProgress.instance,
              CampaignProgress.instance
            ]),
            builder: (context, _) => Center(
                    child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: ListView(padding: const EdgeInsets.all(20), children: [
                    const GameText(
                        'Cada lugar guarda una versión distinta de la misma noche. Son cambios visuales, sin ventajas en la mesa.',
                        style: SS.body),
                    const SizedBox(height: 16),
                    for (final room in roomSkins)
                      Card(
                          child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    SizedBox(
                                        height: 130,
                                        child: room.id == 'study'
                                            ? DecoratedBox(
                                                decoration: SS.tableBg())
                                            : CustomPaint(
                                                painter:
                                                    RoomScenePainter(room.id))),
                                    const SizedBox(height: 12),
                                    GameText(room.title, style: SS.title),
                                    if (!RoomProgress.instance.unlocked(room))
                                      GameText(
                                          'Recuperá ${room.memories} recuerdos o completá la noche ${room.night + 1}.',
                                          style: SS.sub),
                                    FilledButton(
                                        onPressed:
                                            RoomProgress.instance.unlocked(room)
                                                ? () => RoomProgress.instance
                                                    .select(room.id)
                                                : null,
                                        child: GameText(
                                            RoomProgress.instance.effective ==
                                                    room.id
                                                ? 'HABITACIÓN ELEGIDA'
                                                : 'ELEGIR HABITACIÓN')),
                                  ]))),
                    if (RoomProgress.instance.saveError != null)
                      GameText(RoomProgress.instance.saveError!, style: SS.sub),
                  ]),
                ))),
      );
}
