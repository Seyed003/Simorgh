import 'package:aghelan_ghiamat/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boots to the home page', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AghelanApp()));
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
