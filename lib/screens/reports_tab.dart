import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ledger_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/pdf_report_service.dart';
import 'dealer_detail_screen.dart';

class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key});

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  DateFilterPreset _preset = DateFilterPreset.thisMonth;
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

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LedgerProvider>();
    final range =
        provider.resolvePreset(_preset, customRange: _customRange);

    final totalDebit = provider.totalDebitInRange(range.start, range.end);
    final totalCredit = provider.totalCreditInRange(range.start, range.end);
    final net = totalDebit - totalCredit;

    final dealerBreakdown = provider
        .getDealerSummaries(startDate: range.start, endDate: range.end)
        .where((s) => s.entryCount > 0)
        .toList()
      ..sort((a, b) => b.totalDebit.compareTo(a.totalDebit));

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Date Range Selector
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
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
                ],
              ),
            ),

            // Period Totals (Responsive: wraps on narrow mobile screens)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final cardWidth = constraints.maxWidth < 520
                      ? (constraints.maxWidth - 10) / 2
                      : (constraints.maxWidth - 20) / 3;
                  return Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      SizedBox(
                        width: cardWidth,
                        child: _ReportMetricCard(
                          label: 'Total Debit (Bills)',
                          value: AppFormatters.formatRs(totalDebit),
                          color: AppColors.debit,
                          bgColor: AppColors.debitBg,
                        ),
                      ),
                      SizedBox(
                        width: cardWidth,
                        child: _ReportMetricCard(
                          label: 'Total Credit (Wasooli)',
                          value: AppFormatters.formatRs(totalCredit),
                          color: AppColors.credit,
                          bgColor: AppColors.creditBg,
                        ),
                      ),
                      SizedBox(
                        width: constraints.maxWidth < 520
                            ? constraints.maxWidth
                            : cardWidth,
                        child: _ReportMetricCard(
                          label: 'Net Difference',
                          value: AppFormatters.formatRs(net),
                          color: AppColors.navy,
                          bgColor: AppColors.navy.withValues(alpha: 0.08),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Dealer-wise Breakdown (${dealerBreakdown.length} active dealers)',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                  ),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.red,
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () => PdfReportService.openAllDealersBalancePdf(
                      context,
                      provider.getDealerSummaries(),
                    ),
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 16),
                    label: const Text('All Dealers PDF'),
                  ),
                ],
              ),
            ),

            Expanded(
              child: dealerBreakdown.isEmpty
                  ? const Center(
                      child: Text(
                        'No activity in this date range',
                        style: TextStyle(color: AppColors.textMuted),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
                      itemCount: dealerBreakdown.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (ctx, i) {
                        final item = dealerBreakdown[i];
                        return Card(
                          child: ListTile(
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => DealerDetailScreen(
                                    dealerId: item.dealer.id,
                                  ),
                                ),
                              );
                            },
                            title: Text(
                              '${item.dealer.code} • ${item.dealer.name}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: Text(
                              '${item.entryCount} entries  •  Dr: ${AppFormatters.formatNumber(item.totalDebit)}  •  Cr: ${AppFormatters.formatNumber(item.totalCredit)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                            trailing: Text(
                              AppFormatters.formatRs(item.balance),
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: item.balance > 0
                                    ? AppColors.debit
                                    : AppColors.credit,
                              ),
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

class _ReportMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final Color bgColor;

  const _ReportMetricCard({
    required this.label,
    required this.value,
    required this.color,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w600),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
