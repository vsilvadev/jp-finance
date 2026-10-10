import 'package:flutter/material.dart';

import '../../../app/app_controller.dart';
import '../../../core/database/database.dart' as db;
import '../../../core/formatters/money.dart';

Future<void> showCategoryForm(
  BuildContext context,
  AppController controller, {
  db.Category? category,
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) =>
        _CategoryFormDialog(controller: controller, category: category),
  );
}

class _CategoryFormDialog extends StatefulWidget {
  const _CategoryFormDialog({required this.controller, this.category});

  final AppController controller;
  final db.Category? category;

  @override
  State<_CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends State<_CategoryFormDialog> {
  late final _nameController = TextEditingController(
    text: widget.category?.name ?? '',
  );
  late final _iconController = TextEditingController(
    text: widget.category?.icon ?? '🍜',
  );
  late final _budgetController = TextEditingController(
    text: widget.category?.budgetAmount.toString() ?? '',
  );
  final _formKey = GlobalKey<FormState>();

  int get _maximum {
    final otherAllocated = widget.controller.categories
        .where((item) => item.id != widget.category?.id)
        .fold<int>(0, (sum, item) => sum + item.budgetAmount);
    return widget.controller.totalPlaced - otherAllocated;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _iconController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.category;
    return AlertDialog(
      title: Text(category == null ? 'Nova categoria' : 'Editar categoria'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                SizedBox(
                  width: 76,
                  child: TextFormField(
                    controller: _iconController,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(labelText: 'Ícone'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Obrigatório'
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _nameController,
                    autofocus: category == null,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(labelText: 'Nome'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Informe um nome'
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _budgetController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Orçamento',
                prefixText: '¥ ',
                helperText: 'Não alocado: ${yen(_maximum)}',
              ),
              validator: _validateBudget,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(category == null ? 'Criar' : 'Salvar'),
        ),
      ],
    );
  }

  String? _validateBudget(String? value) {
    final parsed = _amount(value);
    if (value == null || value.trim().isEmpty) return 'Informe o orçamento';
    if (parsed > _maximum) return 'Máximo disponível: ${yen(_maximum)}';
    final category = widget.category;
    if (category != null && parsed < widget.controller.spentIn(category.id)) {
      return 'Não pode ser menor que o total já gasto';
    }
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await widget.controller.saveCategory(
        id: widget.category?.id,
        name: _nameController.text,
        icon: _iconController.text,
        budgetAmount: _amount(_budgetController.text),
      );
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) _showError(context, error);
    }
  }
}

int _amount(String? value) =>
    int.tryParse((value ?? '').replaceAll(RegExp(r'\D'), '')) ?? 0;

void _showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(error.toString().replaceFirst('Invalid argument(s): ', '')),
    ),
  );
}
