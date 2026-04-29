import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/widgets/app_empty_state.dart';

void main() {
  testWidgets('empty state renders title and action', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppEmptyState(
            title: 'Cart is empty',
            subtitle: 'Products add karke checkout continue karo.',
            actionLabel: 'Browse products',
            onAction: () {},
          ),
        ),
      ),
    );

    expect(find.text('Cart is empty'), findsOneWidget);
    expect(find.text('Browse products'), findsOneWidget);
  });
}
