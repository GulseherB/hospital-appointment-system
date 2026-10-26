import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';

void main() {
  testWidgets('application starts with its title', (WidgetTester tester) async {
    await tester.pumpWidget(const AppointmentApp());

    expect(find.text('Hastane Randevu Sistemi'), findsOneWidget);
  });
}
