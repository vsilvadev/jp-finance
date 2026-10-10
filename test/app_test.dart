import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jp_finance/app/app.dart';
import 'package:jp_finance/app/app_controller.dart';
import 'package:jp_finance/core/database/database.dart';
import 'package:jp_finance/features/reports/data/json_backup.dart';
import 'package:jp_finance/features/reports/data/pdf_report.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  testWidgets('home opens with the trip budget and expense action', (
    tester,
  ) async {
    final controller = AppController(database);
    await controller.load();

    await tester.pumpWidget(JapanTripApp(controller: controller));

    expect(find.text('🇯🇵 Japão'), findsOneWidget);
    expect(find.text('DINHEIRO TOTAL COLOCADO'), findsOneWidget);
    expect(find.text('Novo gasto'), findsOneWidget);
  });

  testWidgets('a category opens its details route', (tester) async {
    final controller = AppController(database);
    await controller.load();
    await controller.addMoney(5000);
    await controller.saveCategory(
      name: 'Comida',
      icon: '🍜',
      budgetAmount: 4000,
    );

    await tester.pumpWidget(JapanTripApp(controller: controller));
    await tester.tap(find.text('Comida'));
    await tester.pumpAndSettle();

    expect(find.text('🍜 Comida'), findsOneWidget);
    expect(find.text('Gastos'), findsOneWidget);
  });

  test('category spending cannot exceed its remaining allocation', () async {
    final controller = AppController(database);
    await controller.load();
    await controller.addMoney(5000);
    await controller.saveCategory(
      name: 'Comida',
      icon: '🍜',
      budgetAmount: 4000,
    );
    final category = controller.categories.single;
    await controller.saveExpense(
      categoryId: category.id,
      name: 'Ichiran',
      amount: 3000,
    );

    expect(controller.totalAvailable, 2000);
    expect(controller.availableIn(category), 1000);
    await expectLater(
      controller.saveExpense(
        categoryId: category.id,
        name: 'Sushi',
        amount: 1500,
      ),
      throwsArgumentError,
    );
  });

  test('JSON backup and PDF reports include the stored trip data', () async {
    final controller = AppController(database);
    await controller.load();
    await controller.addMoney(5000);
    await controller.saveCategory(
      name: 'Comida',
      icon: '🍜',
      budgetAmount: 4000,
    );
    final category = controller.categories.single;
    await controller.saveExpense(
      categoryId: category.id,
      name: 'Ichiran',
      amount: 1500,
    );

    final backup =
        jsonDecode(utf8.decode(buildJsonBackup(controller)))
            as Map<String, dynamic>;
    expect(backup['format'], 'jp_finance_backup');
    expect((backup['moneyEntries'] as List).single['amount'], 5000);
    expect((backup['categories'] as List).single['name'], 'Comida');
    expect((backup['expenses'] as List).single['name'], 'Ichiran');

    final fullReport = await buildTripReport(controller);
    final categoryReport = await buildTripReport(
      controller,
      onlyCategory: category,
    );
    expect(utf8.decode(fullReport.take(5).toList()), '%PDF-');
    expect(utf8.decode(categoryReport.take(5).toList()), '%PDF-');

    final reloadedController = AppController(database);
    await reloadedController.load();
    expect(reloadedController.totalPlaced, 5000);
    expect(reloadedController.totalSpent, 1500);
  });
}
