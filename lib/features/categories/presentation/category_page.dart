import 'package:flutter/material.dart';

import '../../../app/app.dart';
import '../../../app/app_controller.dart';
import '../../../core/database/database.dart' as db;
import '../../../core/formatters/money.dart';
import '../../expenses/presentation/expense_form.dart';
import 'category_form.dart';

class CategoryPage extends StatelessWidget {
  const CategoryPage({super.key, required this.categoryId});
  final int categoryId;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    final category = controller.categories
        .where((item) => item.id == categoryId)
        .firstOrNull;
    if (controller.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (category == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Categoria não encontrada.')),
      );
    }
    final expenses = controller.expensesIn(categoryId);
    final spent = controller.spentIn(categoryId);
    final remaining = category.budgetAmount - spent;
    final percent = category.budgetAmount == 0
        ? 0
        : spent * 100 ~/ category.budgetAmount;
    final progress = category.budgetAmount == 0
        ? 0.0
        : (spent / category.budgetAmount).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: Text('${category.icon} ${category.name}'),
        actions: [
          IconButton(
            tooltip: 'Editar categoria',
            onPressed: () =>
                showCategoryForm(context, controller, category: category),
            icon: const Icon(Icons.edit_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _MetricRow(
                    label: 'Orçamento',
                    value: yen(category.budgetAmount),
                  ),
                  const SizedBox(height: 12),
                  _MetricRow(label: 'Gasto', value: yen(spent)),
                  const SizedBox(height: 12),
                  _MetricRow(
                    label: 'Disponível',
                    value: yen(remaining),
                    highlight: true,
                  ),
                  const SizedBox(height: 18),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 10,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '$percent%',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Gastos', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (expenses.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('Nenhum gasto nesta categoria.'),
              ),
            )
          else
            ..._groupByDate(expenses).entries.map(
              (entry) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                    child: Text(
                      entry.key,
                      style: Theme.of(
                        context,
                      ).textTheme.labelLarge?.copyWith(color: Colors.black54),
                    ),
                  ),
                  Card(
                    margin: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (
                          var index = 0;
                          index < entry.value.length;
                          index++
                        ) ...[
                          _ExpenseTile(
                            expense: entry.value[index],
                            controller: controller,
                          ),
                          if (index < entry.value.length - 1)
                            const Divider(height: 1, indent: 16, endIndent: 16),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () =>
            showExpenseForm(context, controller, initialCategoryId: categoryId),
        icon: const Icon(Icons.add),
        label: const Text('Novo gasto'),
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });
  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(color: highlight ? null : Colors.black54),
        ),
      ),
      Text(
        value,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: highlight ? Theme.of(context).colorScheme.primary : null,
        ),
      ),
    ],
  );
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({required this.expense, required this.controller});
  final db.Expense expense;
  final AppController controller;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
    title: Text(expense.name),
    subtitle: Text(
      '${expense.createdAt.hour.toString().padLeft(2, '0')}:${expense.createdAt.minute.toString().padLeft(2, '0')}',
    ),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          yen(expense.amount),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        PopupMenuButton<String>(
          tooltip: 'Ações do gasto',
          onSelected: (action) async {
            if (action == 'edit') {
              await showExpenseForm(context, controller, expense: expense);
            } else if (action == 'delete') {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Excluir gasto?'),
                  content: Text('${expense.name} · ${yen(expense.amount)}'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Excluir'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) await controller.deleteExpense(expense.id);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(value: 'edit', child: Text('Editar')),
            PopupMenuItem(value: 'delete', child: Text('Excluir')),
          ],
        ),
      ],
    ),
  );
}

Map<String, List<db.Expense>> _groupByDate(List<db.Expense> expenses) {
  final groups = <String, List<db.Expense>>{};
  for (final expense in expenses) {
    groups.putIfAbsent(shortDate(expense.createdAt), () => []).add(expense);
  }
  return groups;
}
