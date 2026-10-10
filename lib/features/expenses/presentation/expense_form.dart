import 'package:flutter/material.dart';

import '../../../app/app_controller.dart';
import '../../../core/database/database.dart' as db;
import '../../../core/formatters/money.dart';

Future<void> showExpenseForm(
  BuildContext context,
  AppController controller, {
  int? initialCategoryId,
  db.Expense? expense,
}) async {
  if (controller.categories.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Crie uma categoria antes de registrar gastos.'),
      ),
    );
    return;
  }

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _ExpenseFormSheet(
      controller: controller,
      initialCategoryId: initialCategoryId,
      expense: expense,
    ),
  );
}

class _ExpenseFormSheet extends StatefulWidget {
  const _ExpenseFormSheet({
    required this.controller,
    this.initialCategoryId,
    this.expense,
  });

  final AppController controller;
  final int? initialCategoryId;
  final db.Expense? expense;

  @override
  State<_ExpenseFormSheet> createState() => _ExpenseFormSheetState();
}

class _ExpenseFormSheetState extends State<_ExpenseFormSheet> {
  late final _nameController = TextEditingController(
    text: widget.expense?.name ?? '',
  );
  late final _amountController = TextEditingController(
    text: widget.expense?.amount.toString() ?? '',
  );
  final _formKey = GlobalKey<FormState>();
  late int _selectedCategoryId = _initialCategoryId;

  int get _initialCategoryId {
    final requestedId = widget.expense?.categoryId ?? widget.initialCategoryId;
    if (requestedId != null &&
        widget.controller.categories.any(
          (category) => category.id == requestedId,
        )) {
      return requestedId;
    }
    return widget.controller.categories.first.id;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      4,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.expense == null ? 'Novo gasto' : 'Editar gasto',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<int>(
            initialValue: _selectedCategoryId,
            decoration: const InputDecoration(labelText: 'Categoria'),
            items: widget.controller.categories
                .map(
                  (category) => DropdownMenuItem(
                    value: category.id,
                    child: Text('${category.icon}  ${category.name}'),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _selectedCategoryId = value);
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _nameController,
            autofocus: widget.expense == null,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Nome do gasto',
              hintText: 'Ex.: Ichiran',
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Informe um nome'
                : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Valor',
              prefixText: '¥ ',
            ),
            validator: _validateAmount,
          ),
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _submit,
            child: Text(
              widget.expense == null ? 'Adicionar' : 'Salvar alterações',
            ),
          ),
        ],
      ),
    ),
  );

  String? _validateAmount(String? value) {
    final amount = _parseAmount(value);
    if (amount <= 0) return 'O gasto deve ser maior que zero';

    final category = widget.controller.categories.firstWhere(
      (item) => item.id == _selectedCategoryId,
    );
    final alreadySpent = widget.controller.expenses
        .where(
          (item) =>
              item.categoryId == _selectedCategoryId &&
              item.id != widget.expense?.id,
        )
        .fold<int>(0, (sum, item) => sum + item.amount);
    final remaining = category.budgetAmount - alreadySpent;
    if (amount > remaining) {
      return 'Orçamento insuficiente (${yen(remaining)} disponíveis)';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await widget.controller.saveExpense(
        id: widget.expense?.id,
        categoryId: _selectedCategoryId,
        name: _nameController.text,
        amount: _parseAmount(_amountController.text),
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) _showError(context, error);
    }
  }
}

int _parseAmount(String? value) =>
    int.tryParse((value ?? '').replaceAll(RegExp(r'\D'), '')) ?? 0;

void _showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(error.toString().replaceFirst('Invalid argument(s): ', '')),
    ),
  );
}
