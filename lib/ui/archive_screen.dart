import 'package:flutter/material.dart';
import '../story.dart';
import '../theme.dart';

/// Optional fiction and basic rules; opening it never starts a match.
class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('ARCHIVO 067')),
        body: Center(
            child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: ListView(padding: const EdgeInsets.all(24), children: [
            const Text(Story.chapter, style: SS.title),
            const SizedBox(height: 20),
            const Text('NOTA ENCONTRADA BAJO TU SILLA', style: SS.sub),
            const SizedBox(height: 8),
            const Text(
                'La letra es tuya. No recordás haberla escrito.\n\n'
                '«Si volvés a despertar acá, no preguntes cuánto tiempo pasó. '
                'Escuchá las historias. Cada persona dejó una parte de sí sobre la mesa. '
                'Vos dejaste dos. La puerta recuerda cuáles.»',
                style: SS.body),
            const SizedBox(height: 24),
            for (final entry in const [
              (
                'LA VIUDA',
                'Habla de una cena que sigue esperando. Cada vez que cuenta la historia, cambia el nombre de quien falta.'
              ),
              (
                'EL TESTIGO',
                'Asegura haber visto lo que pasó. Nunca dice desde dónde miraba.'
              ),
              (
                'EL HUECO',
                'No recuerda haber entrado. Dice que alguien más solía ocupar su silla.'
              ),
              (
                'LA REGLA DE LA PUERTA',
                'Necesitás un 6 y un 7 entre tus dos recuerdos, en cualquier orden. Las cartas de tu mano cambian esos valores. Pagás sus costes con lucidez y podés ceder la palabra para terminar tu turno.'
              ),
              (
                'NO BASTA CON RECORDAR',
                'Cuando estés listo, intentá salir durante tu turno. Los demás pueden reaccionar. En modo Farol también podés intentarlo si estás cerca: leé las reglas del modo antes de confiarte.'
              ),
              (
                'OTRAS VOCES',
                'En una partida local, los tres desconocidos los controla el juego. Online, compartís la mesa con otras personas; los textos de «La habitación» son narración, no mensajes de tus rivales.'
              ),
            ]) ...[
              Text(entry.$1, style: SS.title),
              const SizedBox(height: 8),
              Text(entry.$2, style: SS.body),
              const SizedBox(height: 24),
            ],
            FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('CERRAR EL ARCHIVO')),
          ]),
        )),
      );
}
