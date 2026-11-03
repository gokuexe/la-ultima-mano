import 'package:flutter/material.dart';
import '../play_preferences.dart';
import '../model.dart';
import '../sfx.dart';
import '../theme.dart';

class OptionsScreen extends StatelessWidget {
  const OptionsScreen({super.key});
  @override
  Widget build(BuildContext context) => DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
            title: const Text('A TU MANERA'),
            bottom: const TabBar(
                tabs: [Tab(text: 'AJUSTES'), Tab(text: 'CARTAS')])),
        body: const TabBarView(children: [_PreferencesPanel(), CardGuide()]),
      ));
}

class _PreferencesPanel extends StatelessWidget {
  const _PreferencesPanel();
  @override
  Widget build(BuildContext context) {
    final preferences = PlayPreferences.instance;
    return ListenableBuilder(
        listenable: preferences,
        builder: (context, _) =>
            ListView(padding: const EdgeInsets.all(24), children: [
              const Text('La mesa también puede escucharte.', style: SS.title),
              const SizedBox(height: 24),
              Text('Volumen: ${(preferences.volume * 100).round()} %',
                  style: SS.body),
              Slider(
                  value: preferences.volume,
                  divisions: 10,
                  label: '${(preferences.volume * 100).round()} %',
                  onChanged: (v) => preferences.update(volume: v)),
              OutlinedButton(
                  onPressed: () => Sfx.i.play('play'),
                  child: const Text('PROBAR SONIDO')),
              const SizedBox(height: 20),
              const Text('Tamaño de lectura', style: SS.title),
              const SizedBox(height: 8),
              DropdownButton<double>(
                  isExpanded: true,
                  value: preferences.textScale,
                  items: const [
                    DropdownMenuItem(value: 1.0, child: Text('Normal')),
                    DropdownMenuItem(value: 1.1, child: Text('Grande')),
                    DropdownMenuItem(value: 1.2, child: Text('Más grande'))
                  ],
                  onChanged: (value) {
                    if (value != null) preferences.update(textScale: value);
                  }),
              const Text(
                  'Se respeta también el tamaño de letra que elegiste en tu sistema.',
                  style: SS.sub),
              const SizedBox(height: 20),
              SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Reducir movimiento'),
                  subtitle: const Text(
                      'Sin destellos de pantalla, sacudidas, confeti ni escritura progresiva. Los tiempos de reacción no cambian.'),
                  value: preferences.reduceMotion,
                  onChanged: (value) =>
                      preferences.update(reduceMotion: value)),
              const SizedBox(height: 20),
              Text(
                  preferences.saveError ??
                      'Tus preferencias se guardan solo en este equipo.',
                  style: SS.sub),
            ]));
  }
}

class CardGuide extends StatefulWidget {
  const CardGuide({super.key});
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
    final cards = kCards.values
        .where((card) =>
            (_family == null || card.family == _family) &&
            normalize('${card.name} ${card.desc}')
                .contains(normalize(_query.trim())))
        .toList();
    return Column(children: [
      Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(children: [
            TextField(
                decoration: const InputDecoration(
                    labelText: 'Buscar una carta',
                    prefixIcon: Icon(Icons.search)),
                onChanged: (v) => setState(() => _query = v)),
            DropdownButton<CardFamily?>(
                isExpanded: true,
                value: _family,
                items: [
                  const DropdownMenuItem<CardFamily?>(
                      value: null, child: Text('Todas las familias')),
                  for (final family in CardFamily.values)
                    DropdownMenuItem<CardFamily?>(
                        value: family, child: Text(labels[family]!)),
                ],
                onChanged: (value) => setState(() => _family = value)),
            Text(
                '${cards.length} de ${kCards.length} cartas · Consultá sin usar lucidez.',
                style: SS.sub),
            const Text('La partida sigue mientras consultás esta guía.',
                style: SS.sub),
            const SizedBox(height: 12),
          ])),
      Expanded(
          child: cards.isEmpty
              ? const Center(
                  child: Padding(
                      padding: EdgeInsets.all(24),
                      child:
                          Text('No hay cartas que coincidan con tu búsqueda.')))
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
                              Text(card.name, style: SS.title),
                              const SizedBox(height: 8),
                              Text(
                                  '${labels[card.family]} · ${card.cost} lucidez',
                                  style: SS.sub),
                              const SizedBox(height: 8),
                              Text(card.desc, style: SS.body),
                              if (card.isReaction)
                                const Padding(
                                    padding: EdgeInsets.only(top: 8),
                                    child: Text(
                                        'Se responde cuando el juego abre una ventana de reacción.',
                                        style: SS.sub)),
                            ]));
                  })),
    ]);
  }
}
