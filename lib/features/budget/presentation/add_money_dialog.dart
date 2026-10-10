import 'package:flutter/material.dart';

import '../../../app/app_controller.dart';

Future<void> showAddMoneyDialog(
  BuildContext context,
  AppController controller,
) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _AddMoneyDialog(controller: controller),
  );
}

class _AddMoneyDialog extends StatefulWidget {
  const _AddMoneyDialog({required this.controller});

  final AppController controller;

  @override
  State<_AddMoneyDialog> createState() => _AddMoneyDialogState();
}

class _AddMoneyDialogState extends State<_AddMoneyDialog> {
  final _amountController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Adicionar dinheiro'),
    content: Form(
      key: _formKey,
      child: TextFormField(
        controller: _amountController,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(
          labelText: 'Valor em ienes',
          prefixText: '¥ ',
        ),
        validator: (value) =>
            _amount(value) > 0 ? null : 'Informe um valor maior que zero.',
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(onPressed: _submit, child: const Text('Adicionar')),
    ],
  );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    try {
      await widget.controller.addMoney(_amount(_amountController.text));
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
