import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meatvo_official/design_system/theme/meatvo_theme.dart';
import 'package:meatvo_official/models/product_model.dart';
import 'package:meatvo_official/ui/organisms/meatvo_product_card.dart';

void main() {
  testWidgets('MeatvoProductCard does not overflow at 320dp width', (tester) async {
    // Covers grid cell sizing used on category/catalog screens.
    await tester.binding.setSurfaceSize(const Size(320, 600));

    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: MeatvoTheme.light,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 148,
              height: MeatvoProductCard.gridCardHeight(320),
              child: MeatvoProductCard(
                product: ProductModel(
                  id: '1',
                  name: 'Premium Chicken Breast Boneless Extra Long Name',
                  price: 299,
                  unit: '500g',
                  categoryId: 'c1',
                  isAvailable: true,
                ),
                displayPrice: 249,
                displayUnit: '500g',
                originalPrice: 299,
                discountPercent: 15,
                inStock: true,
                onAdd: () {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('MeatvoProductCard shows ordering paused overlay and Closed CTA',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: MeatvoTheme.light,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 148,
              height: 320,
              child: MeatvoProductCard(
                product: ProductModel(
                  id: '2',
                  name: 'Chicken Curry Cut',
                  price: 199,
                  unit: '500g',
                  categoryId: 'c1',
                  isAvailable: true,
                ),
                displayPrice: 199,
                displayUnit: '500g',
                inStock: true,
                orderingPaused: true,
                onAdd: () {},
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Ordering paused'), findsOneWidget);
    expect(find.text('Closed'), findsOneWidget);
  });
}
