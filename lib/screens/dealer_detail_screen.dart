import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/dealer.dart';
import '../models/ledger_entry.dart';
import '../providers/ledger_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/pdf_report_service.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/dealer_form_dialog.dart';
import '../widgets/entry_form_dialog.dart';

class DealerDetailScreen extends StatefulWidget {
  final String dealerId;

  const DealerDetailScreen({super.key, required this.dealerId});

  @override
  State<DealerDetailScreen> createState() => _DealerDetailScreenState();
}

class _DealerDetailScreenState extends State<DealerDetailScreen> {
  DateFilterPreset _preset = DateFilterPreset.allTime;
  DateTimeRange? _customRange;

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: _customRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 30)),
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

  Future<void> _deleteDealer(Dealer dealer) async {
    final ok = await showConfirmDeleteDialog(
      context,
      title: 'Delete Dealer',
      message:
          'Delete "${dealer.name}" (${dealer.code}) and all of their khata entries? This cannot be undone.',
    );
    if (!ok || !mounted) return;
    await context.read<LedgerProvider>().deleteDealer(dealer.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LedgerProvider>();
    final dealerExists = provider.dealers.any((d) => d.id == widget.dealerId);
    if (!dealerExists) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dealer Ledger')),
        body: const Center(child: Text('Dealer not found')),
      );
    }

    final summary = provider.summaryForDealer(widget.dealerId);
    final dealer = summary.dealer;
    final range =
        provider.resolvePreset(_preset, customRange: _customRange);
    final filteredEntries = provider.entriesForDealer(
      widget.dealerId,
      startDate: range.start,
      endDate: range.end,
    );

    // Compute running balance chronologically (oldest -> newest), then show newest first.
    final chronological = List<LedgerEntry>.from(filteredEntries)
      ..sort((a, b) {
        final cmp = a.date.compareTo(b.date);
        return cmp != 0 ? cmp : a.createdAt.compareTo(b.createdAt);
      });
    final runningBalances = <String, double>{};
    double running = 0;
    for (final e in chronological) {
      running += e.type == EntryType.debit ? e.amount : -e.amount;
      runningBalances[e.id] = running;
    }

    final displayEntries = List<LedgerEntry>.from(chronological);

    final periodDebit = filteredEntries
        .where((e) => e.type == EntryType.debit)
        .fold(0.0, (s, e) => s + e.amount);
    final periodCredit = filteredEntries
        .where((e) => e.type == EntryType.credit)
        .fold(0.0, (s, e) => s + e.amount);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dealer.name,
              style: const TextStyle(fontSize: 15, height: 1.15),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              'Code: ${dealer.code}',
              style: const TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Edit Dealer',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () =>
                showDealerFormDialog(context, existingDealer: dealer),
          ),
          IconButton(
            tooltip: 'Delete Dealer',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _deleteDealer(dealer),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Column(
            children: [
              // Compact Top Summary & Quick Action Bar (leaves room for 15+ table rows)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                color: AppColors.navy,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryPill(
                            label: 'Balance',
                            value: AppFormatters.formatRs(summary.balance),
                            color: Colors.white,
                            bgColor: Colors.white.withValues(alpha: 0.14),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _SummaryPill(
                            label: _preset == DateFilterPreset.allTime
                                ? 'Debit'
                                : '${_compactPresetLabel(_preset)} Dr',
                            value: AppFormatters.formatRs(periodDebit),
                            color: const Color(0xFFFFCDD2),
                            bgColor: Colors.white.withValues(alpha: 0.10),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: _SummaryPill(
                            label: _preset == DateFilterPreset.allTime
                                ? 'Credit'
                                : '${_compactPresetLabel(_preset)} Cr',
                            value: AppFormatters.formatRs(periodCredit),
                            color: const Color(0xFFC8E6C9),
                            bgColor: Colors.white.withValues(alpha: 0.10),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 34,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.red,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                textStyle: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                              onPressed: () => showEntryFormDialog(
                                context,
                                initialDealer: dealer,
                                initialType: EntryType.debit,
                              ),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add Debit'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SizedBox(
                            height: 34,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.credit,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                textStyle: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.w700),
                              ),
                              onPressed: () => showEntryFormDialog(
                                context,
                                initialDealer: dealer,
                                initialType: EntryType.credit,
                              ),
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Add Credit'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Compact Date Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Row(
                  children: [
                    for (final preset in DateFilterPreset.values) ...[
                      ChoiceChip(
                        visualDensity: const VisualDensity(
                            horizontal: -2, vertical: -3),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        labelPadding:
                            const EdgeInsets.symmetric(horizontal: 6),
                        label: Text(
                          preset == DateFilterPreset.custom &&
                                  _customRange != null
                              ? '${AppFormatters.formatShortDate(_customRange!.start)} - ${AppFormatters.formatShortDate(_customRange!.end)}'
                              : _compactPresetLabel(preset),
                          style: const TextStyle(fontSize: 11),
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
                      const SizedBox(width: 6),
                    ],
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.red,
                        visualDensity: const VisualDensity(
                            horizontal: -2, vertical: -3),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        minimumSize: const Size(0, 28),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: displayEntries.isEmpty
                          ? null
                          : () => PdfReportService.openDealerKhataPdf(
                                context,
                                dealer: dealer,
                                entries: displayEntries,
                                runningBalances: runningBalances,
                                totalDebit: periodDebit,
                                totalCredit: periodCredit,
                                periodLabel: _preset ==
                                            DateFilterPreset.custom &&
                                        _customRange != null
                                    ? '${AppFormatters.formatShortDate(_customRange!.start)} - ${AppFormatters.formatShortDate(_customRange!.end)}'
                                    : _preset.label,
                              ),
                      icon: const Icon(Icons.picture_as_pdf_outlined,
                          size: 14),
                      label: const Text('PDF',
                          style: TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),

              // Khata Register Table (Mobile + Web, matching physical Khata register)
              Expanded(
                child: displayEntries.isEmpty
                    ? const Center(
                        child: Text(
                          'No entries in this period',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final isCompact = constraints.maxWidth < 560;
                          final hMargin = isCompact ? 8.0 : 16.0;
                          final cellPadH = isCompact ? 6.0 : 10.0;
                          final cellPadV = isCompact ? 3.5 : 5.0;

                          final colWidths = <int, TableColumnWidth>{
                            0: const FlexColumnWidth(3.4),
                            1: const FlexColumnWidth(2.0),
                            2: const FlexColumnWidth(2.0),
                            3: const FlexColumnWidth(2.2),
                            4: FixedColumnWidth(isCompact ? 34 : 44),
                          };

                          return Padding(
                            padding: EdgeInsets.fromLTRB(
                                hMargin, 0, hMargin, 16),
                            child: Column(
                              children: [
                                // Fixed Register Table Header
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(10)),
                                  child: Table(
                                    columnWidths: colWidths,
                                    border: TableBorder(
                                      verticalInside: BorderSide(
                                          color: Colors.white
                                              .withValues(alpha: 0.18)),
                                    ),
                                    children: [
                                      TableRow(
                                        decoration: const BoxDecoration(
                                            color: AppColors.navy),
                                        children: [
                                          Padding(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: cellPadH,
                                                vertical: 10),
                                            child: Text(
                                              isCompact
                                                  ? 'Date / Details'
                                                  : 'Date • Details',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 11,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: cellPadH,
                                                vertical: 10),
                                            child: const Text(
                                              'Debit',
                                              textAlign: TextAlign.right,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 11,
                                                color: Color(0xFFFFCDD2),
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: cellPadH,
                                                vertical: 10),
                                            child: const Text(
                                              'Credit',
                                              textAlign: TextAlign.right,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 11,
                                                color: Color(0xFFC8E6C9),
                                              ),
                                            ),
                                          ),
                                          Padding(
                                            padding: EdgeInsets.symmetric(
                                                horizontal: cellPadH,
                                                vertical: 10),
                                            child: const Text(
                                              'Balance',
                                              textAlign: TextAlign.right,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 11,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ),
                                          const Padding(
                                            padding: EdgeInsets.symmetric(
                                                vertical: 8),
                                            child: Text(
                                              'Edit',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 10,
                                                color: Colors.white70,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                // Scrollable Register Table Body (pixel-aligned columns)
                                Expanded(
                                  child: Scrollbar(
                                    child: SingleChildScrollView(
                                      padding:
                                          const EdgeInsets.only(bottom: 16),
                                      child: Table(
                                        columnWidths: colWidths,
                                        defaultVerticalAlignment:
                                            TableCellVerticalAlignment.middle,
                                        border: TableBorder.all(
                                            color: AppColors.border),
                                        children: [
                                          for (int i = 0;
                                              i < displayEntries.length;
                                              i++)
                                            _buildRegisterRow(
                                              context,
                                              entry: displayEntries[i],
                                              balAfter: runningBalances[
                                                      displayEntries[i].id] ??
                                                  0,
                                              isEven: i.isEven,
                                              isCompact: isCompact,
                                              cellPadH: cellPadH,
                                              cellPadV: cellPadV,
                                            ),
                                          _buildTotalRow(
                                            totalDebit: periodDebit,
                                            totalCredit: periodCredit,
                                            netBalance:
                                                periodDebit - periodCredit,
                                            isCompact: isCompact,
                                            cellPadH: cellPadH,
                                            cellPadV: cellPadV,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  TableRow _buildRegisterRow(
    BuildContext context, {
    required LedgerEntry entry,
    required double balAfter,
    required bool isEven,
    required bool isCompact,
    required double cellPadH,
    required double cellPadV,
  }) {
    final isDebit = entry.type == EntryType.debit;
    final dateStr = AppFormatters.formatShortDate(entry.date);
    final desc = [
      if (entry.billNo.isNotEmpty) 'Bill #${entry.billNo}',
      if (entry.note.isNotEmpty) entry.note,
      if (entry.billNo.isEmpty && entry.note.isEmpty)
        (isDebit ? 'Debit' : 'Credit'),
    ].join(' • ');

    return TableRow(
      decoration: BoxDecoration(
        color: isEven ? Colors.white : const Color(0xFFF8FAFC),
      ),
      children: [
        Padding(
          padding:
              EdgeInsets.symmetric(horizontal: cellPadH, vertical: cellPadV),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                dateStr,
                style: const TextStyle(
                  fontSize: 10.5,
                  height: 1.1,
                  fontWeight: FontWeight.w700,
                  color: AppColors.navy,
                ),
              ),
              Text(
                desc,
                style: const TextStyle(
                  fontSize: 10,
                  height: 1.15,
                  color: AppColors.textMuted,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        Padding(
          padding:
              EdgeInsets.symmetric(horizontal: cellPadH, vertical: cellPadV),
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                isDebit ? AppFormatters.formatNumber(entry.amount) : '-',
                style: TextStyle(
                  fontSize: isCompact ? 11.5 : 12.5,
                  fontWeight: FontWeight.w700,
                  color: isDebit ? AppColors.debit : AppColors.textMuted,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding:
              EdgeInsets.symmetric(horizontal: cellPadH, vertical: cellPadV),
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                !isDebit ? AppFormatters.formatNumber(entry.amount) : '-',
                style: TextStyle(
                  fontSize: isCompact ? 11.5 : 12.5,
                  fontWeight: FontWeight.w700,
                  color: !isDebit ? AppColors.credit : AppColors.textMuted,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding:
              EdgeInsets.symmetric(horizontal: cellPadH, vertical: cellPadV),
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                AppFormatters.formatNumber(balAfter),
                style: TextStyle(
                  fontSize: isCompact ? 11.5 : 12.5,
                  fontWeight: FontWeight.w800,
                  color: balAfter > 0 ? AppColors.navy : AppColors.credit,
                ),
              ),
            ),
          ),
        ),
        Center(
          child: Tooltip(
            message: 'Edit Entry',
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () => showEntryFormDialog(context, existingEntry: entry),
              child: Padding(
                padding: EdgeInsets.all(isCompact ? 3 : 5),
                child: Icon(
                  Icons.edit_outlined,
                  size: isCompact ? 15 : 17,
                  color: AppColors.navy,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  TableRow _buildTotalRow({
    required double totalDebit,
    required double totalCredit,
    required double netBalance,
    required bool isCompact,
    required double cellPadH,
    required double cellPadV,
  }) {
    return TableRow(
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.08),
      ),
      children: [
        Padding(
          padding:
              EdgeInsets.symmetric(horizontal: cellPadH, vertical: cellPadV),
          child: Text(
            'Total',
            style: TextStyle(
              fontSize: isCompact ? 12 : 13,
              fontWeight: FontWeight.w800,
              color: AppColors.navy,
            ),
          ),
        ),
        Padding(
          padding:
              EdgeInsets.symmetric(horizontal: cellPadH, vertical: cellPadV),
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                AppFormatters.formatNumber(totalDebit),
                style: TextStyle(
                  fontSize: isCompact ? 12 : 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.debit,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding:
              EdgeInsets.symmetric(horizontal: cellPadH, vertical: cellPadV),
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                AppFormatters.formatNumber(totalCredit),
                style: TextStyle(
                  fontSize: isCompact ? 12 : 13,
                  fontWeight: FontWeight.w800,
                  color: AppColors.credit,
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding:
              EdgeInsets.symmetric(horizontal: cellPadH, vertical: cellPadV),
          child: Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                AppFormatters.formatNumber(netBalance),
                style: TextStyle(
                  fontSize: isCompact ? 12 : 13,
                  fontWeight: FontWeight.w900,
                  color: netBalance > 0 ? AppColors.navy : AppColors.credit,
                ),
              ),
            ),
          ),
        ),
        const SizedBox.shrink(),
      ],
    );
  }

  String _compactPresetLabel(DateFilterPreset preset) {
    switch (preset) {
      case DateFilterPreset.today:
        return 'Today';
      case DateFilterPreset.thisWeek:
        return 'Week';
      case DateFilterPreset.thisMonth:
        return 'Month';
      case DateFilterPreset.allTime:
        return 'All';
      case DateFilterPreset.custom:
        return 'Range';
    }
  }
}

class _SummaryPill extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color bgColor;

  const _SummaryPill({
    required this.label,
    required this.value,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 10),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
