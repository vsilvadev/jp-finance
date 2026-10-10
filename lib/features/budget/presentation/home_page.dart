import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/app.dart';
import '../../../app/app_controller.dart';
import '../../../core/database/database.dart' as db;
import '../../../core/formatters/money.dart';
import '../../../core/platform/file_download.dart';
import '../../categories/presentation/category_form.dart';
import '../../expenses/presentation/expense_form.dart';
import '../../conversion/presentation/converter_tab.dart';
import '../../reports/data/json_backup.dart';
import '../../reports/data/pdf_report.dart';
import 'add_money_dialog.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedTab = 0;
  bool _hasOpenedConverter = false;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '🇯🇵 Japão',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          if (_selectedTab == 2)
            IconButton(
              tooltip: 'Apagar todos os dados',
              onPressed: () => _confirmDeleteAllData(context, controller),
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: controller.loading && _selectedTab != 1
          ? const Center(child: CircularProgressIndicator())
          : IndexedStack(
              index: _selectedTab,
              children: [
                _HomeTab(controller: controller),
                if (_hasOpenedConverter)
                  const ConverterTab()
                else
                  const SizedBox.shrink(),
                _YouTab(
                  controller: controller,
                  onShowExports: () => _showExportOptions(context, controller),
                ),
              ],
            ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedTab,
        onDestinationSelected: (index) => setState(() {
          _selectedTab = index;
          if (index == 1) _hasOpenedConverter = true;
        }),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Início',
          ),
          NavigationDestination(
            icon: Icon(Icons.currency_exchange_outlined),
            selectedIcon: Icon(Icons.currency_exchange),
            label: 'Conversão',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Você',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showExpenseForm(context, controller),
        icon: const Icon(Icons.add),
        label: const Text('Novo gasto'),
      ),
    );
  }
}

Future<void> _confirmDeleteAllData(
  BuildContext context,
  AppController controller,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.delete_forever_outlined),
      title: const Text('Apagar todos os dados?'),
      content: const Text(
        'Isso apagará todas as entradas de dinheiro, categorias e gastos salvos '
        'neste dispositivo. Essa ação não pode ser desfeita. Exporte um backup '
        'antes se quiser guardar uma cópia.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Apagar tudo'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    await controller.deleteAllData();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Todos os dados foram apagados.')),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível apagar os dados: $error')),
      );
    }
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
      children: [
        _BudgetSummary(controller: controller),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Text(
                'Categorias',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            TextButton.icon(
              onPressed: () => showCategoryForm(context, controller),
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Nova'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (controller.categories.isEmpty)
          _EmptyCategories(
            onCreate: () => showCategoryForm(context, controller),
          )
        else
          ...controller.categories.map(
            (category) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CategoryCard(category: category, controller: controller),
            ),
          ),
      ],
    ),
  );
}

class _YouTab extends StatelessWidget {
  const _YouTab({required this.controller, required this.onShowExports});
  final AppController controller;
  final VoidCallback onShowExports;

  @override
  Widget build(BuildContext context) {
    final recentExpenses = controller.expenses.take(5).toList();
    final categoryNames = {
      for (final category in controller.categories)
        category.id: '${category.icon} ${category.name}',
    };
    return SafeArea(
      top: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
        children: [
          Text('Você', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Compras recentes',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (recentExpenses.isNotEmpty)
                Text(
                  '${recentExpenses.length} de 5',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (recentExpenses.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('Seus gastos recentes aparecerão aqui.'),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (var index = 0; index < recentExpenses.length; index++)
                    ListTile(
                      leading: const Icon(Icons.shopping_bag_outlined),
                      title: Text(recentExpenses[index].name),
                      subtitle: Text(
                        '${categoryNames[recentExpenses[index].categoryId] ?? 'Categoria'}'
                        ' · ${shortDate(recentExpenses[index].createdAt)}',
                      ),
                      trailing: Text(
                        yen(recentExpenses[index].amount),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      shape: index == recentExpenses.length - 1
                          ? null
                          : const Border(
                              bottom: BorderSide(color: Color(0xFFECE9E3)),
                            ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 28),
          Text(
            'Backup e relatórios',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              leading: const Icon(Icons.file_download_outlined),
              title: const Text('Exportar ou importar dados'),
              subtitle: const Text('Backup JSON e relatórios PDF'),
              trailing: const Icon(Icons.chevron_right),
              onTap: onShowExports,
            ),
          ),
        ],
      ),
    );
  }
}

class _BudgetSummary extends StatelessWidget {
  const _BudgetSummary({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Card(
      color: const Color(0xFF292A2D),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'DINHEIRO TOTAL COLOCADO',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Adicionar dinheiro',
                  onPressed: () => showAddMoneyDialog(context, controller),
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            Text(
              yen(controller.totalPlaced),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 27,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 16),
            const Text(
              'DINHEIRO DISPONÍVEL',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              yen(controller.totalAvailable),
              style: TextStyle(
                color: colors.tertiaryContainer,
                fontSize: 25,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Gasto ${yen(controller.totalSpent)}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
                Text(
                  'Não alocado ${yen(controller.unallocated)}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category, required this.controller});
  final db.Category category;
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final spent = controller.spentIn(category.id);
    final progress = category.budgetAmount == 0
        ? 0.0
        : (spent / category.budgetAmount).clamp(0.0, 1.0);
    final percent = category.budgetAmount == 0
        ? 0
        : spent * 100 ~/ category.budgetAmount;
    final recent = controller.expensesIn(category.id).take(3).toList();
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(16, 7, 12, 7),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        title: InkWell(
          onTap: () => context.push('/category/${category.id}'),
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                Text(category.icon, style: const TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    category.name,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  '$percent%',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6, right: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${yen(spent)} / ${yen(category.budgetAmount)}  ·  '
                '-${yen(controller.availableIn(category))} sobrando',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 9),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(value: progress, minHeight: 6),
              ),
            ],
          ),
        ),
        children: [
          const SizedBox(height: 10),
          if (recent.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Nenhum gasto ainda'),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _dayLabel(recent.first.createdAt),
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: Colors.black54),
                ),
              ),
            ),
            ...recent.map(
              (expense) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        expense.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      yen(expense.amount),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => context.push('/category/${category.id}'),
              child: const Text('Ver todos os gastos'),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyCategories extends StatelessWidget {
  const _EmptyCategories({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          const Icon(Icons.category_outlined, size: 34),
          const SizedBox(height: 8),
          const Text('Organize seu orçamento em categorias.'),
          const SizedBox(height: 12),
          FilledButton.tonal(
            onPressed: onCreate,
            child: const Text('Criar categoria'),
          ),
        ],
      ),
    ),
  );
}

Future<void> _showExportOptions(
  BuildContext context,
  AppController controller,
) async {
  final choice = await showModalBottomSheet<Object?>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          const ListTile(
            title: Text(
              'Backup e relatórios',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.backup_outlined),
            title: const Text('Backup completo (JSON)'),
            subtitle: const Text('Cópia dos dados desta viagem'),
            onTap: () => Navigator.pop(context, 'backup'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.restore_outlined),
            title: const Text('Importar backup (JSON)'),
            subtitle: const Text('Restaurar dados de um arquivo'),
            onTap: () => Navigator.pop(context, 'restore'),
          ),
          const Divider(height: 1),
          const ListTile(title: Text('Relatório PDF')),
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: const Text('Relatório completo'),
            onTap: () => Navigator.pop(context, 'all'),
          ),
          ...controller.categories.map(
            (category) => ListTile(
              leading: Text(
                category.icon,
                style: const TextStyle(fontSize: 22),
              ),
              title: Text(category.name),
              subtitle: const Text('Relatório da categoria'),
              onTap: () => Navigator.pop(context, category),
            ),
          ),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) {
    return;
  }
  if (choice == 'restore') {
    await _importBackup(context, controller);
    return;
  }
  if (choice == 'backup') {
    try {
      await _shareExport(
        context,
        filename: 'backup_japao.json',
        bytes: buildJsonBackup(controller),
        mimeType: 'application/json',
        title: 'Backup da viagem ao Japão',
      );
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível exportar: $error')),
        );
      }
    }
    return;
  }
  final category = choice is db.Category ? choice : null;
  try {
    final bytes = await buildTripReport(controller, onlyCategory: category);
    if (!context.mounted) return;
    final reportName = category == null
        ? 'relatorio_japao.pdf'
        : 'relatorio_${category.name}.pdf';
    await _shareExport(
      context,
      filename: reportName,
      bytes: bytes,
      mimeType: 'application/pdf',
      title: category == null
          ? 'Relatório da viagem ao Japão'
          : 'Relatório ${category.name}',
    );
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível exportar: $error')),
      );
    }
  }
}

Future<void> _importBackup(
  BuildContext context,
  AppController controller,
) async {
  final file = await openFile(
    acceptedTypeGroups: const [
      XTypeGroup(label: 'Backup JSON', extensions: ['json']),
    ],
  );
  if (file == null || !context.mounted) return;

  late final JsonBackupData backup;
  try {
    backup = JsonBackupData.parse(await file.readAsBytes());
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível ler o backup: ${_errorMessage(error)}',
          ),
        ),
      );
    }
    return;
  }
  if (!context.mounted) return;

  final hasCurrentData =
      controller.moneyEntries.isNotEmpty ||
      controller.categories.isNotEmpty ||
      controller.expenses.isNotEmpty;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(
        hasCurrentData ? 'Substituir dados atuais?' : 'Importar backup?',
      ),
      content: Text(
        '${backup.moneyEntries.length} entradas de dinheiro, '
        '${backup.categories.length} categorias e '
        '${backup.expenses.length} gastos serão restaurados.'
        '${hasCurrentData ? '\n\nOs dados atuais serão substituídos. Se quiser guardá-los, cancele e exporte um backup antes.' : ''}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Restaurar'),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    await restoreJsonBackup(controller, backup);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup restaurado com sucesso.')),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Não foi possível restaurar o backup: ${_errorMessage(error)}',
          ),
        ),
      );
    }
  }
}

String _errorMessage(Object error) =>
    error is FormatException ? error.message : error.toString();

Future<void> _shareExport(
  BuildContext context, {
  required String filename,
  required Uint8List bytes,
  required String mimeType,
  required String title,
}) async {
  final savedPath = await saveToDownloads(filename, bytes);
  if (savedPath != null) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Arquivo salvo em $savedPath')));
    }
    return;
  }
  if (!context.mounted) return;

  final renderObject = context.findRenderObject();
  final sharePositionOrigin = renderObject is RenderBox
      ? renderObject.localToGlobal(Offset.zero) & renderObject.size
      : null;
  await SharePlus.instance.share(
    ShareParams(
      title: title,
      files: [XFile.fromData(bytes, mimeType: mimeType)],
      fileNameOverrides: [filename],
      sharePositionOrigin: sharePositionOrigin,
    ),
  );
}

String _dayLabel(DateTime date) {
  final now = DateTime.now();
  if (date.year == now.year && date.month == now.month && date.day == now.day) {
    return 'Hoje';
  }
  return shortDate(date);
}
