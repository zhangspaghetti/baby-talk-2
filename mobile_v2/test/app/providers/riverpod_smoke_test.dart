import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ProviderScope exposes a read-only provider', (tester) async {
    final valueProvider = Provider<String>((ref) => 'engine-ready');

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, child) {
              return Text(ref.watch(valueProvider));
            },
          ),
        ),
      ),
    );

    expect(find.text('engine-ready'), findsOneWidget);
  });
}
