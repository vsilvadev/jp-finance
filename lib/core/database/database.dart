import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

class MoneyEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get amount => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get icon => text().withLength(min: 1, max: 8)();
  IntColumn get budgetAmount => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get categoryId =>
      integer().references(Categories, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  IntColumn get amount => integer()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

@DriftDatabase(tables: [MoneyEntries, Categories, Expenses])
class AppDatabase extends _$AppDatabase {
  AppDatabase()
    : super(
        driftDatabase(
          name: 'japan_trip',
          web: DriftWebOptions(
            sqlite3Wasm: Uri.parse('sqlite3.wasm'),
            driftWorker: Uri.parse('drift_worker.js'),
          ),
        ),
      );

  AppDatabase.forTesting(super.e);

  @override
  int get schemaVersion => 1;

  Future<int> totalPlaced() async {
    final row = await customSelect(
      'SELECT COALESCE(SUM(amount), 0) AS total FROM money_entries',
    ).getSingle();
    return row.read<int>('total');
  }

  Future<int> totalSpent() async {
    final row = await customSelect(
      'SELECT COALESCE(SUM(amount), 0) AS total FROM expenses',
    ).getSingle();
    return row.read<int>('total');
  }

  Future<int> categorySpent(int categoryId, {int? excludingExpenseId}) async {
    final row = await customSelect(
      'SELECT COALESCE(SUM(amount), 0) AS total FROM expenses '
      'WHERE category_id = ?${excludingExpenseId == null ? '' : ' AND id != ?'}',
      variables: [
        Variable.withInt(categoryId),
        if (excludingExpenseId != null) Variable.withInt(excludingExpenseId),
      ],
    ).getSingle();
    return row.read<int>('total');
  }

  Future<List<Expense>> expensesForCategory(int categoryId) =>
      (select(expenses)
            ..where((expense) => expense.categoryId.equals(categoryId))
            ..orderBy([(expense) => OrderingTerm.desc(expense.createdAt)]))
          .get();

  Future<List<Expense>> recentExpenses({int? categoryId, int? limit}) {
    final query = select(expenses)
      ..orderBy([(expense) => OrderingTerm.desc(expense.createdAt)]);
    if (categoryId != null) {
      query.where((expense) => expense.categoryId.equals(categoryId));
    }
    if (limit != null) query.limit(limit);
    return query.get();
  }
}
