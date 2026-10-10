import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/formatters/money.dart';

class ConverterTab extends StatefulWidget {
  const ConverterTab({super.key});

  @override
  State<ConverterTab> createState() => _ConverterTabState();
}

class _ConverterTabState extends State<ConverterTab> {
  final _amountController = TextEditingController();
  final _rateController = TextEditingController();
  bool _yenToReal = true;
  bool _loadingRate = false;
  bool _manuallyEditedRate = false;
  DateTime? _rateDate;
  String? _rateError;

  Future<void> _fetchRate({bool replaceManualRate = false}) async {
    if (_loadingRate) return;
    setState(() {
      _loadingRate = true;
      _rateError = null;
    });
    try {
      final response = await http
          .get(Uri.parse('https://api.frankfurter.dev/v2/rate/jpy/brl'))
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        throw const FormatException('Resposta inválida da cotação.');
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic> ||
          decoded['rate'] is! num ||
          decoded['date'] is! String) {
        throw const FormatException('Formato inválido da cotação.');
      }
      final rate = (decoded['rate'] as num).toDouble();
      final date = DateTime.tryParse(decoded['date'] as String);
      if (rate <= 0 || date == null) {
        throw const FormatException('Cotação inválida.');
      }
      if (!mounted) return;
      setState(() {
        _rateDate = date;
        if (replaceManualRate || !_manuallyEditedRate) {
          _rateController.text = _formatRateInput(rate);
          _manuallyEditedRate = false;
        }
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _rateError =
              'Sem conexão com a cotação online. Você pode informar uma taxa manualmente.';
        });
      }
    } finally {
      if (mounted) setState(() => _loadingRate = false);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final amount = _yenToReal
        ? _parseYenAmount(_amountController.text)
        : _parseBrazilianNumber(_amountController.text);
    final rate = _parseBrazilianNumber(_rateController.text);
    final convertedAmount = amount == null || rate == null || rate <= 0
        ? null
        : _yenToReal
        ? amount * rate
        : amount / rate;

    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        children: [
          Text('Conversão', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'Converta ienes e reais com a cotação de referência do dia.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Center(
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment<bool>(
                  value: true,
                  label: Text('¥ → R\$', softWrap: false),
                ),
                ButtonSegment<bool>(
                  value: false,
                  label: Text('R\$ → ¥', softWrap: false),
                ),
              ],
              selected: {_yenToReal},
              onSelectionChanged: (selection) {
                setState(() => _yenToReal = selection.first);
              },
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _amountController,
            onChanged: (_) => setState(() {}),
            keyboardType: _yenToReal
                ? TextInputType.number
                : const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: _yenToReal
                  ? 'Valor em ienes (¥)'
                  : 'Valor em reais (R\$)',
              hintText: _yenToReal ? '1500' : '50,00',
              prefixIcon: const Icon(Icons.payments_outlined),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _rateController,
            onChanged: (_) => setState(() {
              _manuallyEditedRate = true;
              _rateError = null;
            }),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Cotação (R\$ por ¥1)',
              hintText: '0,035',
              prefixIcon: const Icon(Icons.currency_exchange),
              suffixIcon: _loadingRate
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      tooltip: 'Atualizar cotação online',
                      onPressed: () => _fetchRate(replaceManualRate: true),
                      icon: const Icon(Icons.refresh),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _rateError ??
                (_manuallyEditedRate
                    ? 'Usando taxa manual. Toque em atualizar para aplicar a cotação online.'
                    : _rateDate == null
                    ? 'Buscando taxa de referência; você também pode editar o valor.'
                    : 'Frankfurter · referência de ${_formatRateDate(_rateDate!)}. '
                          'A taxa do cartão ou da casa de câmbio pode variar.'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (_rateError != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _loadingRate ? null : () => _fetchRate(),
              icon: const Icon(Icons.refresh),
              label: const Text('Tentar novamente'),
            ),
          ],
          const SizedBox(height: 24),
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Resultado',
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    convertedAmount == null
                        ? 'Informe o valor e a cotação'
                        : _yenToReal
                        ? _formatReais(convertedAmount)
                        : yen(convertedAmount.round()),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _fetchRate();
  }
}

double? _parseBrazilianNumber(String input) {
  var value = input.trim().replaceAll(' ', '').replaceAll('¥', '');
  value = value.replaceAll('R\$', '');
  if (value.isEmpty) return null;

  if (value.contains(',')) {
    value = value.replaceAll('.', '').replaceAll(',', '.');
  }
  return double.tryParse(value);
}

double? _parseYenAmount(String input) {
  final value = input.trim().replaceAll(' ', '').replaceAll('¥', '');
  if (value.isEmpty) return null;
  return double.tryParse(value.replaceAll('.', ''));
}

String _formatReais(double amount) =>
    'R\$ ${amount.toStringAsFixed(2).replaceAll('.', ',')}';

String _formatRateInput(double rate) => rate
    .toStringAsFixed(6)
    .replaceFirst(RegExp(r'0+$'), '')
    .replaceFirst(RegExp(r'\.$'), '')
    .replaceAll('.', ',');

String _formatRateDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/'
    '${date.month.toString().padLeft(2, '0')}/${date.year}';
