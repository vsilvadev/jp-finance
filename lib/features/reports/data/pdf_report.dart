import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../app/app_controller.dart';
import '../../../core/database/database.dart';

Future<Uint8List> buildTripReport(
  AppController controller, {
  Category? onlyCategory,
}) async {
  final pdf = pw.Document();
  final categories = onlyCategory == null
      ? controller.categories
      : [onlyCategory];
  final relevantExpenses =
      controller.expenses
          .where(
            (expense) =>
                categories.any((category) => category.id == expense.categoryId),
          )
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(38),
      theme: pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
      ),
      build: (context) => [
        pw.Text(
          'JAPÃO',
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          onlyCategory == null
              ? 'Relatório da viagem'
              : 'Relatório de ${onlyCategory.name}',
          style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 22),
        if (onlyCategory == null) ...[
          _summaryLine('Dinheiro total colocado', controller.totalPlaced),
          _summaryLine('Total gasto', controller.totalSpent),
          _summaryLine(
            'Dinheiro disponível',
            controller.totalAvailable,
            emphasize: true,
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Categorias',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
        ] else ...[
          _summaryLine('Orçamento', onlyCategory.budgetAmount),
          _summaryLine('Total gasto', controller.spentIn(onlyCategory.id)),
          _summaryLine(
            'Disponível',
            controller.availableIn(onlyCategory),
            emphasize: true,
          ),
          _summaryLine(
            'Percentual gasto',
            onlyCategory.budgetAmount == 0
                ? 0
                : (controller.spentIn(onlyCategory.id) *
                      100 ~/
                      onlyCategory.budgetAmount),
            suffix: '%',
          ),
          pw.SizedBox(height: 20),
        ],
        if (onlyCategory == null)
          ...categories.map((category) {
            final spent = controller.spentIn(category.id);
            final percent = category.budgetAmount == 0
                ? 0
                : spent * 100 ~/ category.budgetAmount;
            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 9),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey300),
                ),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    category.name,
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Orçamento ${_yen(category.budgetAmount)}   |   Gasto ${_yen(spent)}   |   '
                    'Disponível ${_yen(controller.availableIn(category))}   |   $percent%',
                  ),
                ],
              ),
            );
          }),
        pw.SizedBox(height: 22),
        pw.Text(
          'Gastos detalhados',
          style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        if (relevantExpenses.isEmpty)
          pw.Text(
            'Nenhum gasto registrado.',
            style: const pw.TextStyle(color: PdfColors.grey700),
          )
        else
          ...relevantExpenses.map((expense) {
            final category = categories.firstWhere(
              (item) => item.id == expense.categoryId,
            );
            return pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 7),
              decoration: const pw.BoxDecoration(
                border: pw.Border(
                  bottom: pw.BorderSide(color: PdfColors.grey200),
                ),
              ),
              child: pw.Row(
                children: [
                  pw.SizedBox(
                    width: 45,
                    child: pw.Text(_date(expense.createdAt)),
                  ),
                  pw.Expanded(
                    child: pw.Text('${expense.name}  -  ${category.name}'),
                  ),
                  pw.Text(
                    _yen(expense.amount),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            );
          }),
      ],
    ),
  );
  return pdf.save();
}

pw.Widget _summaryLine(
  String label,
  int amount, {
  bool emphasize = false,
  String suffix = '',
}) => pw.Padding(
  padding: const pw.EdgeInsets.symmetric(vertical: 5),
  child: pw.Row(
    children: [
      pw.Expanded(child: pw.Text(label)),
      pw.Text(
        '${suffix == '%' ? amount : _yen(amount)}$suffix',
        style: pw.TextStyle(
          fontWeight: emphasize ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    ],
  ),
);

String _yen(int value) {
  final text = value.toString();
  final out = StringBuffer();
  for (var i = 0; i < text.length; i++) {
    if (i > 0 && (text.length - i) % 3 == 0) out.write('.');
    out.write(text[i]);
  }
  return '¥$out';
}

String _date(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
