import 'package:flutter_test/flutter_test.dart';
import 'package:posturer_v02/main.dart';

void main() {
  testWidgets('App shows main navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const PosturerApp());

    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Stats'), findsOneWidget);

    await tester.tap(find.text('Stats'));
    await tester.pump();

    expect(find.text('Recent posture events'), findsOneWidget);
  });
}
