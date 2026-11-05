import '../l10n/game_text.dart';
import '../l10n/language_picker.dart';
import 'package:flutter/material.dart';
import '../play_preferences.dart';
import '../model.dart';
import '../sfx.dart';
import '../theme.dart';
import '../collection_progress.dart';

class OptionsScreen extends StatelessWidget {
  final Map<String, ActionCard>? cards;
  const OptionsScreen({super.key, this.cards});
  @override
  Widget build(BuildContext context) => DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
            title: const GameText('A TU MANERA'),
            bottom: const TabBar(tabs: [
              Tab(child: GameText('AJUSTES')),
              Tab(child: GameText('CARTAS'))
            ])),
        body: TabBarView(
            children: [const _PreferencesPanel(), CardGuide(cards: cards)]),
      ));
}

class _PreferencesPanel extends StatelessWidget {
  const _PreferencesPanel();
  @override
  Widget build(BuildContext context) {
    final preferences = PlayPreferences.instance;
    return ListenableBuilder(
        listenable:
            Listenable.merge([preferences, CollectionProgress.instance]),
        builder: (context, _) =>
            ListView(padding: const EdgeInsets.all(24), children: [
              const GameText('La mesa también puede escucharte.',
                  style: SS.title),
              const SizedBox(height: 24),
              GameText(
                  'Colección: ${CollectionProgress.instance.points} puntos',
                  style: SS.title),
              const GameText(
                  'Victoria: 30 puntos. Partida terminada: 10. Los marcos no cambian las reglas.',
                  style: SS.sub),
              DropdownButton<String>(
                  isExpanded: true,
                  value: CollectionProgress.instance.frame,
                  items: [
                    const DropdownMenuItem(
                        value: 'plain', child: GameText('Sin marco · libre')),
                    DropdownMenuItem(
                        value: 'amber',
                        enabled: CollectionProgress.instance.unlocked('amber'),
                        child: const GameText('Marco Ámbar · 40 puntos')),
                    DropdownMenuItem(
                        value: 'echo',
                        enabled: CollectionProgress.instance.unlocked('echo'),
                        child: const GameText('Marco Eco · 100 puntos')),
                  ],
                  onChanged: (name) {
                    if (name != null) {
                      CollectionProgress.instance.selectFrame(name);
                    }
                  }),
              if (CollectionProgress.instance.saveError != null)
                GameText(CollectionProgress.instance.saveError!, style: SS.sub),
              const SizedBox(height: 16),
              const GameText('PULSO Y ANCLAJE', style: SS.title),
              const GameText(
                  'En la edición Pulso ganás una carga al cerrar tu turno. Con 3 cargas, Anclaje ajusta un recuerdo propio en +1 o −1. Al comenzar con mano llena podés cambiar una carta antes de actuar.',
                  style: SS.body),
              const SizedBox(height: 16),
              const LanguagePicker(),
              const SizedBox(height: 20),
              GameText('Volumen: ${(preferences.volume * 100).round()} %',
                  style: SS.body),
              Slider(
                  value: preferences.volume,
                  divisions: 10,
                  label: '${(preferences.volume * 100).round()} %',
                  onChanged: (v) => preferences.update(volume: v)),
              OutlinedButton(
                  onPressed: () => Sfx.i.play('play'),
                  child: const GameText('PROBAR SONIDO')),
              const SizedBox(height: 20),
              const GameText('Tamaño de lectura', style: SS.title),
              const SizedBox(height: 8),
              DropdownButton<double>(
                  isExpanded: true,
                  value: preferences.textScale,
                  items: const [
                    DropdownMenuItem(value: 1.0, child: GameText('Normal')),
                    DropdownMenuItem(value: 1.1, child: GameText('Grande')),
                    DropdownMenuItem(value: 1.2, child: GameText('Más grande'))
                  ],
                  onChanged: (value) {
                    if (value != null) preferences.update(textScale: value);
                  }),
              const GameText(
                  'Se respeta también el tamaño de letra que elegiste en tu sistema.',
                  style: SS.sub),
              const SizedBox(height: 20),
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const GameText('Reducir movimiento'),
                  subtitle: const GameText(
                      'Sin destellos de pantalla, sacudidas, escenas animadas ni escritura progresiva. Los tiempos de reacción no cambian.'),
                  value: preferences.reduceMotion,
                  onChanged: (value) =>
                      preferences.update(reduceMotion: value)),
              const SizedBox(height: 20),
              SwitchListTile(
                  key: const ValueKey('tension-setting'),
                  contentPadding: EdgeInsets.zero,
                  title: const GameText('Atmósfera de tensión'),
                  subtitle: const GameText(
                      'Latidos suaves, luz cambiante y rivales inquietos. Las reglas no cambian.'),
                  value: preferences.tension,
                  onChanged: (value) => preferences.update(tension: value)),
              SwitchListTile(
                  key: const ValueKey('device-hints-setting'),
                  contentPadding: EdgeInsets.zero,
                  title: const GameText('Guiños al dispositivo'),
                  subtitle: const GameText(
                      'Opcional: usa el sistema, el idioma del juego y la hora local en diálogos. No lee archivos ni datos personales; no se envía al servidor.'),
                  value: preferences.deviceHints,
                  onChanged: (value) => preferences.update(deviceHints: value)),
              const SizedBox(height: 20),
              GameText(
                  preferences.saveError ??
                      'Tus preferencias se guardan solo en este equipo.',
                  style: SS.sub),
            ]));
  }
}

class CardGuide extends StatefulWidget {
  final Map<String, ActionCard>? cards;
  const CardGuide({super.key, this.cards});
  @override
  State<CardGuide> createState() => _CardGuideState();
}

class _CardGuideState extends State<CardGuide> {
  String _query = '';
  CardFamily? _family;
  static const labels = {
    CardFamily.motor: 'Modificar recuerdos',
    CardFamily.interaccion: 'Interacción',
    CardFamily.riesgo: 'Riesgo',
    CardFamily.reaccion: 'Reacciones',
    CardFamily.info: 'Información'
  };
  String normalize(String text) {
    var value = text.toLowerCase();
    const accents = {
      'á': 'a',
      'é': 'e',
      'í': 'i',
      'ó': 'o',
      'ú': 'u',
      'ü': 'u'
    };
    accents.forEach((from, to) {
      value = value.replaceAll(from, to);
    });
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final catalog = widget.cards ?? kBalancedCards;
    final cards = catalog.values
        .where((card) =>
            (_family == null || card.family == _family) &&
            normalize(
                    '${card.name} ${card.desc} ${context.tr(card.name)} ${context.tr(card.desc)}')
                .contains(normalize(_query.trim())))
        .toList();
    return Column(children: [
      Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(children: [
            TextField(
                decoration: InputDecoration(
                    labelText: context.tr('Buscar una carta'),
                    prefixIcon: Icon(Icons.search)),
                onChanged: (v) => setState(() => _query = v)),
            DropdownButton<CardFamily?>(
                isExpanded: true,
                value: _family,
                items: [
                  const DropdownMenuItem<CardFamily?>(
                      value: null, child: GameText('Todas las familias')),
                  for (final family in CardFamily.values)
                    DropdownMenuItem<CardFamily?>(
                        value: family, child: GameText(labels[family]!)),
                ],
                onChanged: (value) => setState(() => _family = value)),
            GameText(
                '${cards.length} de ${catalog.length} cartas · Consultá sin usar lucidez.',
                style: SS.sub),
            const GameText('La partida sigue mientras consultás esta guía.',
                style: SS.sub),
            const SizedBox(height: 12),
          ])),
      Expanded(
          child: cards.isEmpty
              ? const Center(
                  child: Padding(
                      padding: EdgeInsets.all(24),
                      child: GameText(
                          'No hay cartas que coincidan con tu búsqueda.')))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  itemCount: cards.length,
                  itemBuilder: (context, index) {
                    final card = cards[index];
                    return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: SS.panel(),
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GameText(card.name, style: SS.title),
                              const SizedBox(height: 8),
                              GameText(
                                  '${labels[card.family]} · ${card.cost} lucidez',
                                  style: SS.sub),
                              const SizedBox(height: 8),
                              GameText(card.desc, style: SS.body),
                              if (card.isReaction)
                                const Padding(
                                    padding: EdgeInsets.only(top: 8),
                                    child: GameText(
                                        'Se responde cuando el juego abre una ventana de reacción.',
                                        style: SS.sub)),
                            ]));
                  })),
    ]);
  }
}
