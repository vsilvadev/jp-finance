import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;

import '../../../app/app_controller.dart';
import '../../../core/database/database.dart' as db;

class JsonBackupData {
  const JsonBackupData({
    required this.moneyEntries,
    required this.categories,
    required this.expenses,
  });

  final List<BackupMoneyEntry> moneyEntries;
  final List<BackupCategory> categories;
  final List<BackupExpense> expenses;

  factory JsonBackupData.parse(Uint8List bytes) {
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('O arquivo não contém um JSON válido.');
    }
    if (decoded is! Map<String, dynamic> ||
        decoded['format'] != 'jp_finance_backup' ||
        decoded['version'] != 1) {
      throw const FormatException(
        'Este arquivo não é um backup compatível do Japão.',
      );
    }
    _date(decoded['exportedAt'], 'exportedAt');

    final moneyEntries = _readList(
      decoded['moneyEntries'],
      'moneyEntries',
      (row) => BackupMoneyEntry(
        id: _positiveInt(row['id'], 'moneyEntries.id'),
        amount: _positiveInt(row['amount'], 'moneyEntries.amount'),
        createdAt: _date(row['createdAt'], 'moneyEntries.createdAt'),
      ),
    );
    final categories = _readList(
      decoded['categories'],
      'categories',
      (row) => BackupCategory(
        id: _positiveInt(row['id'], 'categories.id'),
        name: _text(row['name'], 'categories.name', maxLength: 50),
        icon: _text(row['icon'], 'categories.icon', maxLength: 8),
        budgetAmount: _nonNegativeInt(
          row['budgetAmount'],
          'categories.budgetAmount',
        ),
        createdAt: _date(row['createdAt'], 'categories.createdAt'),
      ),
    );
    final expenses = _readList(
      decoded['expenses'],
      'expenses',
      (row) => BackupExpense(
        id: _positiveInt(row['id'], 'expenses.id'),
        categoryId: _positiveInt(row['categoryId'], 'expenses.categoryId'),
        name: _text(row['name'], 'expenses.name', maxLength: 80),
        amount: _positiveInt(row['amount'], 'expenses.amount'),
        createdAt: _date(row['createdAt'], 'expenses.createdAt'),
      ),
    );

    _ensureUniqueIds(moneyEntries.map((row) => row.id), 'entradas de dinheiro');
    _ensureUniqueIds(categories.map((row) => row.id), 'categorias');
    _ensureUniqueIds(expenses.map((row) => row.id), 'gastos');

    final totalPlaced = moneyEntries.fold<int>(
      0,
      (sum, row) => sum + row.amount,
    );
    final totalAllocated = categories.fold<int>(
      0,
      (sum, row) => sum + row.budgetAmount,
    );
    if (totalAllocated > totalPlaced) {
      throw const FormatException(
        'O backup aloca mais dinheiro do que o total colocado.',
      );
    }
    final categoryById = {
      for (final category in categories) category.id: category,
    };
    final spentByCategory = <int, int>{};
    for (final expense in expenses) {
      final category = categoryById[expense.categoryId];
      if (category == null) {
        throw FormatException(
          'O gasto ${expense.name} aponta para uma categoria inexistente.',
        );
      }
      final spent = (spentByCategory[category.id] ?? 0) + expense.amount;
      if (spent > category.budgetAmount) {
        throw FormatException(
          'Os gastos da categoria ${category.name} ultrapassam o orçamento.',
        );
      }
      spentByCategory[category.id] = spent;
    }

    return JsonBackupData(
      moneyEntries: moneyEntries,
      categories: categories,
      expenses: expenses,
    );
  }
}

class BackupMoneyEntry {
  const BackupMoneyEntry({
    required this.id,
    required this.amount,
    required this.createdAt,
  });
  final int id;
  final int amount;
  final DateTime createdAt;
}

class BackupCategory {
  const BackupCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.budgetAmount,
    required this.createdAt,
  });
  final int id;
  final String name;
  final String icon;
  final int budgetAmount;
  final DateTime createdAt;
}

class BackupExpense {
  const BackupExpense({
    required this.id,
    required this.categoryId,
    required this.name,
    required this.amount,
    required this.createdAt,
  });
  final int id;
  final int categoryId;
  final String name;
  final int amount;
  final DateTime createdAt;
}

Future<void> restoreJsonBackup(
  AppController controller,
  JsonBackupData backup,
) async {
  final database = controller.database;
  await database.transaction(() async {
    await database.delete(database.expenses).go();
    await database.delete(database.categories).go();
    await database.delete(database.moneyEntries).go();

    for (final row in backup.moneyEntries) {
      await database
          .into(database.moneyEntries)
          .insert(
            db.MoneyEntriesCompanion.insert(
              id: Value(row.id),
              amount: row.amount,
              createdAt: Value(row.createdAt),
            ),
          );
    }
    for (final row in backup.categories) {
      await database
          .into(database.categories)
          .insert(
            db.CategoriesCompanion.insert(
              id: Value(row.id),
              name: row.name,
              icon: row.icon,
              budgetAmount: row.budgetAmount,
              createdAt: Value(row.createdAt),
            ),
          );
    }
    for (final row in backup.expenses) {
      await database
          .into(database.expenses)
          .insert(
            db.ExpensesCompanion.insert(
              id: Value(row.id),
              categoryId: row.categoryId,
              name: row.name,
              amount: row.amount,
              createdAt: Value(row.createdAt),
            ),
          );
    }
  });
  await controller.load();
}

List<T> _readList<T>(
  Object? value,
  String name,
  T Function(Map<String, dynamic>) read,
) {
  if (value is! List) throw FormatException('A lista "$name" está ausente.');
  return [
    for (var i = 0; i < value.length; i++)
      if (value[i] is Map<String, dynamic>)
        read(value[i] as Map<String, dynamic>)
      else
        throw FormatException('O item ${i + 1} de "$name" é inválido.'),
  ];
}

int _positiveInt(Object? value, String field) {
  if (value is! int || value <= 0) {
    throw FormatException('O campo "$field" precisa ser um inteiro positivo.');
  }
  return value;
}

int _nonNegativeInt(Object? value, String field) {
  if (value is! int || value < 0) {
    throw FormatException(
      'O campo "$field" precisa ser um inteiro não negativo.',
    );
  }
  return value;
}

String _text(Object? value, String field, {required int maxLength}) {
  if (value is! String || value.trim().isEmpty || value.length > maxLength) {
    throw FormatException(
      'O campo "$field" está vazio ou tem tamanho inválido.',
    );
  }
  return value;
}

DateTime _date(Object? value, String field) {
  if (value is! String) throw FormatException('A data "$field" é inválida.');
  final date = DateTime.tryParse(value);
  if (date == null) throw FormatException('A data "$field" é inválida.');
  return date;
}

void _ensureUniqueIds(Iterable<int> ids, String entity) {
  final values = ids.toSet();
  if (values.length != ids.length) {
    throw FormatException('O backup contém IDs repetidos em $entity.');
  }
}

Uint8List buildJsonBackup(AppController controller) {
  final backup = {
    'format': 'jp_finance_backup',
    'version': 1,
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'moneyEntries': controller.moneyEntries
        .map(
          (entry) => {
            'id': entry.id,
            'amount': entry.amount,
            'createdAt': entry.createdAt.toUtc().toIso8601String(),
          },
        )
        .toList(),
    'categories': controller.categories
        .map(
          (category) => {
            'id': category.id,
            'name': category.name,
            'icon': category.icon,
            'budgetAmount': category.budgetAmount,
            'createdAt': category.createdAt.toUtc().toIso8601String(),
          },
        )
        .toList(),
    'expenses': controller.expenses
        .map(
          (expense) => {
            'id': expense.id,
            'categoryId': expense.categoryId,
            'name': expense.name,
            'amount': expense.amount,
            'createdAt': expense.createdAt.toUtc().toIso8601String(),
          },
        )
        .toList(),
  };
  return Uint8List.fromList(
    utf8.encode(const JsonEncoder.withIndent('  ').convert(backup)),
  );
}
