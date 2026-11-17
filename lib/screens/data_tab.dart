import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ledger_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/web_download_stub.dart'
    if (dart.library.js_interop) '../utils/web_download_web.dart';
import '../widgets/confirm_delete_dialog.dart';

class DataTab extends StatefulWidget {
  const DataTab({super.key});

  @override
  State<DataTab> createState() => _DataTabState();
}

class _DataTabState extends State<DataTab> {
  bool _busy = false;

  Future<void> _exportJson() async {
    final provider = context.read<LedgerProvider>();
    final jsonText = provider.exportBackupJson();
    final stamp = AppFormatters.formatShortDate(DateTime.now())
        .replaceAll('/', '-');
    await downloadTextFile(
      context,
      filename: 'moazan_traders_backup_$stamp.json',
      content: jsonText,
      mimeType: 'application/json',
    );
  }

  Future<void> _exportCsv() async {
    final provider = context.read<LedgerProvider>();
    final csvText = provider.exportDealersCsv();
    final stamp = AppFormatters.formatShortDate(DateTime.now())
        .replaceAll('/', '-');
    await downloadTextFile(
      context,
      filename: 'moazan_traders_balances_$stamp.csv',
      content: csvText,
      mimeType: 'text/csv',
    );
  }

  Future<void> _showImportDialog() async {
    final controller = TextEditingController();
    bool replaceExisting = false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Import Backup (JSON)'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Paste your exported JSON backup below to restore dealers and khata entries:',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: controller,
                    maxLines: 7,
                    decoration: const InputDecoration(
                      hintText: '{ "dealers": [...], "entries": [...] }',
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 10),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: replaceExisting,
                    onChanged: (v) =>
                        setDialogState(() => replaceExisting = v ?? false),
                    title: const Text(
                      'Replace existing data',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'If unchecked, new dealers & entries are merged into current data.',
                      style: TextStyle(fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.navy),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Import Data'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;
    final raw = controller.text.trim();
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please paste valid JSON backup text')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final result = await context.read<LedgerProvider>().importBackupJson(
            raw,
            replaceExisting: replaceExisting,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Imported ${result.dealersImported} dealers & ${result.entriesImported} entries!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Import failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteByDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: DateTimeRange(
        start: now.subtract(const Duration(days: 30)),
        end: now,
      ),
    );
    if (picked == null || !mounted) return;

    final start = AppFormatters.startOfDay(picked.start);
    final end = AppFormatters.endOfDay(picked.end);

    final ok = await showConfirmDeleteDialog(
      context,
      title: 'Delete Entries in Range',
      message:
          'Delete all Debit & Credit entries from ${AppFormatters.formatDate(start)} to ${AppFormatters.formatDate(end)}? Dealers will be kept.',
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      final count = await context
          .read<LedgerProvider>()
          .deleteEntriesInRange(start, end);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted $count entries in selected range.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAllEntries() async {
    final ok = await showConfirmDeleteDialog(
      context,
      title: 'Delete All Entries',
      message:
          'This will permanently delete ALL Debit & Credit entries across all dealers (dealers list will be kept). Export a JSON backup first!',
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      await context.read<LedgerProvider>().deleteAllEntries();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All entries deleted.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAllData() async {
    final ok = await showConfirmDeleteDialog(
      context,
      title: 'Reset All Data',
      message:
          'This will permanently delete ALL dealers and ALL khata entries. Are you sure?',
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    try {
      await context.read<LedgerProvider>().deleteAllData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All dealers & entries deleted.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LedgerProvider>();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Overview card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.navy,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.storage_rounded,
                          color: Colors.white, size: 32),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Data Backup & Management',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${provider.dealers.length} Dealers  •  ${provider.entries.length} Khata Entries',
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Export Section
                const Text(
                  'Export Data',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFFE8EEF7),
                          child: Icon(Icons.download_outlined,
                              color: AppColors.navy),
                        ),
                        title: const Text('Export Full Backup (JSON)',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: const Text(
                            'Downloads all dealers + entries for safe backup or restore'),
                        trailing: FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: AppColors.navy),
                          onPressed: _busy ? null : _exportJson,
                          child: const Text('Export'),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.creditBg,
                          child: Icon(Icons.table_chart_outlined,
                              color: AppColors.credit),
                        ),
                        title: const Text('Export Dealer Balances (CSV / Excel)',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: const Text(
                            'All dealers with Total Debit, Credit & Balance'),
                        trailing: FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: AppColors.credit),
                          onPressed: _busy ? null : _exportCsv,
                          child: const Text('CSV'),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),

                // Import Section
                const Text(
                  'Import Data',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE8EEF7),
                      child:
                          Icon(Icons.upload_outlined, color: AppColors.navy),
                    ),
                    title: const Text('Import Backup (JSON)',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: const Text(
                        'Restore or merge dealers & entries from a JSON backup'),
                    trailing: FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.navy),
                      onPressed: _busy ? null : _showImportDialog,
                      child: const Text('Import'),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Bulk Delete Section
                const Text(
                  'Delete Data (Bulk Cleanup)',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: AppColors.red),
                ),
                const SizedBox(height: 8),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.debitBg,
                          child: Icon(Icons.date_range_outlined,
                              color: AppColors.red),
                        ),
                        title: const Text('Delete Entries by Date Range',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: const Text(
                            'Remove entries between two dates (dealers stay safe)'),
                        trailing: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.red,
                              side: const BorderSide(color: AppColors.red)),
                          onPressed: _busy ? null : _deleteByDateRange,
                          child: const Text('Select'),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.debitBg,
                          child: Icon(Icons.delete_sweep_outlined,
                              color: AppColors.red),
                        ),
                        title: const Text('Delete All Entries (Keep Dealers)',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: const Text(
                            'Clears all Debit & Credit entries; keeps all dealers'),
                        trailing: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.red,
                              side: const BorderSide(color: AppColors.red)),
                          onPressed: _busy ? null : _deleteAllEntries,
                          child: const Text('Clear'),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.debitBg,
                          child: Icon(Icons.delete_forever_outlined,
                              color: AppColors.red),
                        ),
                        title: const Text('Reset All Data (Dealers + Entries)',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: const Text(
                            'Permanently deletes everything in the database'),
                        trailing: FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: AppColors.red),
                          onPressed: _busy ? null : _deleteAllData,
                          child: const Text('Reset'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (_busy)
              Container(
                color: Colors.black26,
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
