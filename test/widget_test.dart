import 'package:flutter_test/flutter_test.dart';

import 'package:la_ultima_mano/main.dart';

void main() {
  testWidgets('muestra la pantalla de título', (WidgetTester tester) async {
    await tester.pumpWidget(const LaUltimaManoApp());
    await tester.pump();

    expect(find.text('LA ÚLTIMA\nMANO'), findsOneWidget);
    expect(find.text('SENTARSE A LA MESA'), findsOneWidget);
    expect(find.text('JUGAR ONLINE · SALA PRIVADA'), findsOneWidget);
  });
}
