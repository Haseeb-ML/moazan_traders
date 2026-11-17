import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/ledger_entry.dart';
import '../providers/ledger_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/entry_form_dialog.dart';

class RecentEntriesTab extends StatefulWidget {
  const RecentEntriesTab({super.key});

  @override
  State<RecentEntriesTab> createState() => _RecentEntriesTabState();
}

class _RecentEntriesTabState extends State<RecentEntriesTab> {
  DateFilterPreset _preset = DateFilterPreset.today;
  DateTimeRange? _customRange;
  EntryType? _typeFilter;
  String _query = '';

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: _customRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 7)),
            end: now,
          ),
    );
    if (picked != null) {
      setState(() {
        _customRange = picked;
        _preset = DateFilterPreset.custom;
      });
    }
  }

  Future<void> _deleteEntry(LedgerEntry entry) async {
    final ok = await showConfirmDeleteDialog(
      context,
      title: 'Delete Entry',
      message:
          'Delete ${entry.type == EntryType.debit ? "Debit" : "Credit"} of ${AppFormatters.formatRs(entry.amount)} for ${entry.dealerName}?',
    );
    if (!ok || !mounted) return;
    await context.read<LedgerProvider>().deleteEntry(entry.id);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LedgerProvider>();
    final range =
        provider.resolvePreset(_preset, customRange: _customRange);

    final filtered = provider.filterEntries(
      startDate: range.start,
      endDate: range.end,
      query: _query,
      type: _typeFilter,
    );

    final debitTotal = filtered
        .where((e) => e.type == EntryType.debit)
        .fold(0.0, (s, e) => s + e.amount);
    final creditTotal = filtered
        .where((e) => e.type == EntryType.credit)
        .fold(0.0, (s, e) => s + e.amount);

    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 100;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Column(
          children: [
            // Cross-check Header (collapses when keyboard is open on mobile)
            if (!isKeyboardOpen)
              Container(
              margin: const EdgeInsets.fromLTRB(16, 14, 16, 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Entries Cross-Check',
                          style: TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${filtered.length} entries (${_preset.label})',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Debit: ${AppFormatters.formatRs(debitTotal)}',
                        style: const TextStyle(
                          color: AppColors.debit,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        'Credit: ${AppFormatters.formatRs(creditTotal)}',
                        style: const TextStyle(
                          color: AppColors.credit,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Search + Type filter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                decoration: const InputDecoration(
                  hintText:
                      'Search by dealer name, code, bill no, or note...',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),

            // Date & Type Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  for (final preset in DateFilterPreset.values) ...[
                    ChoiceChip(
                      label: Text(
                        preset == DateFilterPreset.custom &&
                                _customRange != null
                            ? '${AppFormatters.formatShortDate(_customRange!.start)} - ${AppFormatters.formatShortDate(_customRange!.end)}'
                            : preset.label,
                      ),
                      selected: _preset == preset,
                      onSelected: (_) {
                        if (preset == DateFilterPreset.custom) {
                          _pickCustomRange();
                        } else {
                          setState(() => _preset = preset);
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Debit Only'),
                    selected: _typeFilter == EntryType.debit,
                    onSelected: (sel) => setState(
                        () => _typeFilter = sel ? EntryType.debit : null),
                  ),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Credit Only'),
                    selected: _typeFilter == EntryType.credit,
                    onSelected: (sel) => setState(
                        () => _typeFilter = sel ? EntryType.credit : null),
                  ),
                ],
              ),
            ),

            // Entries List
            Expanded(
              child: filtered.isEmpty
                  ? const Center(
                      child: Text(
                        'No entries found for this filter',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    )
                  : ListView.separated(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (ctx, i) {
                        final entry = filtered[i];
                        final isDebit = entry.type == EntryType.debit;

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 7, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isDebit
                                            ? AppColors.debitBg
                                            : AppColors.creditBg,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        isDebit ? 'DEBIT' : 'CREDIT',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
                                          color: isDebit
                                              ? AppColors.debit
                                              : AppColors.credit,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${entry.dealerCode} • ${entry.dealerName}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      AppFormatters.formatRs(entry.amount),
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: isDebit
                                            ? AppColors.debit
                                            : AppColors.credit,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(Icons.calendar_today_outlined,
                                        size: 13, color: AppColors.textMuted),
                                    const SizedBox(width: 4),
                                    Text(
                                      AppFormatters.formatDate(entry.date),
                                      style: const TextStyle(
                                          fontSize: 12,
                                          color: AppColors.textMuted),
                                    ),
                                    if (entry.billNo.isNotEmpty ||
                                        entry.note.isNotEmpty) ...[
                                      const Text(' • ',
                                          style: TextStyle(
                                              color: AppColors.textMuted)),
                                      Expanded(
                                        child: Text(
                                          [
                                            if (entry.billNo.isNotEmpty)
                                              'Bill #${entry.billNo}',
                                            if (entry.note.isNotEmpty)
                                              entry.note,
                                          ].join(' • '),
                                          style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textMuted),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ] else
                                      const Spacer(),
                                    IconButton(
                                      tooltip: 'Edit Entry',
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(Icons.edit_outlined,
                                          size: 18, color: AppColors.navy),
                                      onPressed: () => showEntryFormDialog(
                                        context,
                                        existingEntry: entry,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Delete Entry',
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(Icons.delete_outline,
                                          size: 18, color: AppColors.red),
                                      onPressed: () => _deleteEntry(entry),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
