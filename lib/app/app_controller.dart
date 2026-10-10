import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../core/database/database.dart' as db;

class AppController extends ChangeNotifier {
  AppController(this.database);

  final db.AppDatabase database;
  List<db.MoneyEntry> moneyEntries = [];
  List<db.Category> categories = [];
  List<db.Expense> expenses = [];
  int totalPlaced = 0;
  int totalSpent = 0;
  bool loading = true;

  int get totalAvailable => totalPlaced - totalSpent;
  int get totalAllocated =>
      categories.fold<int>(0, (sum, item) => sum + item.budgetAmount);
  int get unallocated => totalPlaced - totalAllocated;

  int spentIn(int categoryId) => expenses
      .where((expense) => expense.categoryId == categoryId)
      .fold<int>(0, (sum, expense) => sum + expense.amount);

  int availableIn(db.Category category) =>
      category.budgetAmount - spentIn(category.id);

  List<db.Expense> expensesIn(int categoryId) =>
      expenses.where((expense) => expense.categoryId == categoryId).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  Future<void> load() async {
    moneyEntries = await (database.select(
      database.moneyEntries,
    )..orderBy([(entry) => OrderingTerm.desc(entry.createdAt)])).get();
    categories = await (database.select(
      database.categories,
    )..orderBy([(category) => OrderingTerm.asc(category.createdAt)])).get();
    expenses = await (database.select(
      database.expenses,
    )..orderBy([(expense) => OrderingTerm.desc(expense.createdAt)])).get();
    totalPlaced = moneyEntries.fold<int>(0, (sum, entry) => sum + entry.amount);
    totalSpent = expenses.fold<int>(0, (sum, expense) => sum + expense.amount);
    loading = false;
    notifyListeners();
  }

  Future<void> addMoney(int amount) async {
    if (amount <= 0) throw ArgumentError('Informe um valor maior que zero.');
    await database
        .into(database.moneyEntries)
        .insert(db.MoneyEntriesCompanion.insert(amount: amount));
    await load();
  }

  Future<void> saveCategory({
    int? id,
    required String name,
    required String icon,
    required int budgetAmount,
  }) async {
    final cleanName = name.trim();
    final cleanIcon = icon.trim();
    if (cleanName.isEmpty) throw ArgumentError('Informe o nome da categoria.');
    if (cleanIcon.isEmpty) throw ArgumentError('Informe um ícone.');
    if (budgetAmount < 0) {
      throw ArgumentError('O orçamento não pode ser negativo.');
    }
    final otherAllocated = categories
        .where((category) => category.id != id)
        .fold<int>(0, (sum, category) => sum + category.budgetAmount);
    if (budgetAmount > totalPlaced - otherAllocated) {
      throw ArgumentError(
        'Esse valor ultrapassa o dinheiro ainda não alocado.',
      );
    }
    if (id == null) {
      await database
          .into(database.categories)
          .insert(
            db.CategoriesCompanion.insert(
              name: cleanName,
              icon: cleanIcon,
              budgetAmount: budgetAmount,
            ),
          );
    } else {
      await (database.update(
        database.categories,
      )..where((row) => row.id.equals(id))).write(
        db.CategoriesCompanion(
          name: Value(cleanName),
          icon: Value(cleanIcon),
          budgetAmount: Value(budgetAmount),
        ),
      );
    }
    await load();
  }

  Future<void> saveExpense({
    int? id,
    required int categoryId,
    required String name,
    required int amount,
  }) async {
    final category = categories
        .where((item) => item.id == categoryId)
        .firstOrNull;
    if (category == null) {
      throw ArgumentError('Selecione uma categoria existente.');
    }
    if (name.trim().isEmpty) throw ArgumentError('Informe o nome do gasto.');
    if (amount <= 0) throw ArgumentError('O gasto deve ser maior que zero.');
    final spent = expenses
        .where(
          (expense) => expense.categoryId == categoryId && expense.id != id,
        )
        .fold<int>(0, (sum, expense) => sum + expense.amount);
    if (amount > category.budgetAmount - spent) {
      throw ArgumentError(
        'O orçamento disponível em ${category.name} é insuficiente.',
      );
    }
    if (id == null) {
      await database
          .into(database.expenses)
          .insert(
            db.ExpensesCompanion.insert(
              categoryId: categoryId,
              name: name.trim(),
              amount: amount,
            ),
          );
    } else {
      await (database.update(
        database.expenses,
      )..where((row) => row.id.equals(id))).write(
        db.ExpensesCompanion(
          categoryId: Value(categoryId),
          name: Value(name.trim()),
          amount: Value(amount),
        ),
      );
    }
    await load();
  }

  Future<void> deleteExpense(int id) async {
    await (database.delete(
      database.expenses,
    )..where((row) => row.id.equals(id))).go();
    await load();
  }

  Future<void> deleteAllData() async {
    await database.transaction(() async {
      await database.delete(database.expenses).go();
      await database.delete(database.categories).go();
      await database.delete(database.moneyEntries).go();
    });
    await load();
  }
}
