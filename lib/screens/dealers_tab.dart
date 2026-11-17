import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/dealer.dart';
import '../models/ledger_entry.dart';
import '../providers/ledger_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/confirm_delete_dialog.dart';
import '../widgets/dealer_form_dialog.dart';
import '../widgets/entry_form_dialog.dart';
import 'dealer_detail_screen.dart';

enum _DealerFilter { all, withBalance, settled }

enum _DealerSort { byCode, balanceHighToLow, nameAZ }

class DealersTab extends StatefulWidget {
  const DealersTab({super.key});

  @override
  State<DealersTab> createState() => _DealersTabState();
}

class _DealersTabState extends State<DealersTab> {
  final _searchController = TextEditingController();
  String _query = '';
  _DealerFilter _filter = _DealerFilter.all;
  _DealerSort _sort = _DealerSort.byCode;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _deleteDealer(Dealer dealer) async {
    final ok = await showConfirmDeleteDialog(
      context,
      title: 'Delete Dealer',
      message:
          'Delete "${dealer.name}" (${dealer.code}) and all of their khata entries?',
    );
    if (!ok || !mounted) return;
    await context.read<LedgerProvider>().deleteDealer(dealer.id);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LedgerProvider>();
    final allSummaries = provider.getDealerSummaries();

    final q = _query.trim().toLowerCase();
    final filtered = allSummaries.where((s) {
      if (q.isNotEmpty) {
        final matchName = s.dealer.name.toLowerCase().contains(q);
        final matchCode = s.dealer.code.toLowerCase().contains(q);
        if (!matchName && !matchCode) return false;
      }
      if (_filter == _DealerFilter.withBalance && s.balance <= 0) {
        return false;
      }
      if (_filter == _DealerFilter.settled && s.balance != 0) {
        return false;
      }
      return true;
    }).toList();

    filtered.sort((a, b) {
      switch (_sort) {
        case _DealerSort.byCode:
          return a.dealer.code.compareTo(b.dealer.code);
        case _DealerSort.balanceHighToLow:
          return b.balance.compareTo(a.balance);
        case _DealerSort.nameAZ:
          return a.dealer.name.compareTo(b.dealer.name);
      }
    });

    final now = DateTime.now();
    final todayStart = AppFormatters.startOfDay(now);
    final todayEnd = AppFormatters.endOfDay(now);
    final todayDebit = provider.totalDebitInRange(todayStart, todayEnd);
    final todayCredit = provider.totalCreditInRange(todayStart, todayEnd);
    final media = MediaQuery.of(context);
    final screenWidth = media.size.width;
    final isKeyboardOpen = media.viewInsets.bottom > 100;
    final isCompact = screenWidth < 460;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1150),
        child: Scrollbar(
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            slivers: [
              // Hide heavy summary banner when mobile keyboard is open so search results have full space
              if (!isKeyboardOpen)
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.navy, AppColors.navyDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Total Baqaya (All Dealers)',
                                    style: TextStyle(
                                        color: Colors.white70, fontSize: 12),
                                  ),
                                  const SizedBox(height: 4),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      AppFormatters.formatRs(
                                          provider.totalReceivable),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${provider.dealers.length} Dealers',
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Today Debit: ${AppFormatters.formatRs(todayDebit)}',
                                  style: const TextStyle(
                                    color: Color(0xFFFFCDD2),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Today Credit: ${AppFormatters.formatRs(todayCredit)}',
                                  style: const TextStyle(
                                    color: Color(0xFFC8E6C9),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (isCompact) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                  ),
                                  onPressed: () => showEntryFormDialog(
                                    context,
                                    initialType: EntryType.debit,
                                  ),
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('New Debit'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.credit,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 10),
                                  ),
                                  onPressed: () => showEntryFormDialog(
                                    context,
                                    initialType: EntryType.credit,
                                  ),
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('New Credit'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

              // Search + Add Dealer row
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          textInputAction: TextInputAction.search,
                          decoration: InputDecoration(
                            hintText: isCompact
                                ? 'Search Name or Code...'
                                : 'Search dealer by Name or Code (e.g. 100-0035)...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _query.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _query = '');
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (v) => setState(() => _query = v),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.navy,
                          padding: EdgeInsets.symmetric(
                              horizontal: isCompact ? 12 : 16, vertical: 14),
                        ),
                        onPressed: () => showDealerFormDialog(context),
                        icon: const Icon(Icons.person_add_alt_1, size: 18),
                        label: Text(isCompact ? 'Add' : 'Add Dealer'),
                      ),
                    ],
                  ),
                ),
              ),

              // Filter + Sort Row
              SliverToBoxAdapter(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('All'),
                        selected: _filter == _DealerFilter.all,
                        onSelected: (_) =>
                            setState(() => _filter = _DealerFilter.all),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('With Balance'),
                        selected: _filter == _DealerFilter.withBalance,
                        onSelected: (_) =>
                            setState(() => _filter = _DealerFilter.withBalance),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('Zero Balance'),
                        selected: _filter == _DealerFilter.settled,
                        onSelected: (_) =>
                            setState(() => _filter = _DealerFilter.settled),
                      ),
                      const SizedBox(width: 16),
                      DropdownButton<_DealerSort>(
                        value: _sort,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(
                            value: _DealerSort.byCode,
                            child: Text('Sort: Code'),
                          ),
                          DropdownMenuItem(
                            value: _DealerSort.balanceHighToLow,
                            child: Text('Sort: Balance High-Low'),
                          ),
                          DropdownMenuItem(
                            value: _DealerSort.nameAZ,
                            child: Text('Sort: Name A-Z'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) setState(() => _sort = v);
                        },
                      ),
                    ],
                  ),
                ),
              ),

              // Dealers List
              if (provider.isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.store_mall_directory_outlined,
                              size: 48, color: AppColors.textMuted),
                          const SizedBox(height: 8),
                          const Text('No dealers found'),
                          if (provider.dealers.isEmpty) ...[
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: () =>
                                  provider.seedDefaultDealersIfEmpty(),
                              child: const Text(
                                  'Load 73 Moazan Traders Dealers'),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                )
              else if (screenWidth < 860)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                  sliver: SliverList.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (ctx, i) => _DealerCard(
                      item: filtered[i],
                      onDelete: () => _deleteDealer(filtered[i].dealer),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                  sliver: SliverList.separated(
                    itemCount: (filtered.length / 2).ceil(),
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (ctx, rowIdx) {
                      final firstIdx = rowIdx * 2;
                      final secondIdx = firstIdx + 1;
                      return IntrinsicHeight(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _DealerCard(
                                item: filtered[firstIdx],
                                onDelete: () =>
                                    _deleteDealer(filtered[firstIdx].dealer),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: secondIdx < filtered.length
                                  ? _DealerCard(
                                      item: filtered[secondIdx],
                                      onDelete: () => _deleteDealer(
                                          filtered[secondIdx].dealer),
                                    )
                                  : const SizedBox(),
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
}

class _DealerCard extends StatelessWidget {
  final DealerSummary item;
  final VoidCallback onDelete;

  const _DealerCard({
    required this.item,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dealer = item.dealer;
    final balance = item.balance;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          FocusScope.of(context).unfocus();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DealerDetailScreen(dealerId: dealer.id),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.navy.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      dealer.code,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: AppColors.navy,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          dealer.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Dr: ${AppFormatters.formatNumber(item.totalDebit)}  •  Cr: ${AppFormatters.formatNumber(item.totalCredit)}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        AppFormatters.formatRs(balance),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: balance > 0
                              ? AppColors.debit
                              : balance < 0
                                  ? AppColors.credit
                                  : AppColors.textMuted,
                        ),
                      ),
                      Text(
                        balance > 0
                            ? 'Baqaya'
                            : balance < 0
                                ? 'Advance'
                                : 'Clear',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.debit,
                        side: BorderSide(
                            color: AppColors.debit.withValues(alpha: 0.35)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        showEntryFormDialog(
                          context,
                          initialDealer: dealer,
                          initialType: EntryType.debit,
                        );
                      },
                      icon: const Icon(Icons.add, size: 15),
                      label:
                          const Text('Debit', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.credit,
                        side: BorderSide(
                            color: AppColors.credit.withValues(alpha: 0.35)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 6),
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        showEntryFormDialog(
                          context,
                          initialDealer: dealer,
                          initialType: EntryType.credit,
                        );
                      },
                      icon: const Icon(Icons.add, size: 15),
                      label:
                          const Text('Credit', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Edit Dealer',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    onPressed: () => showDealerFormDialog(
                      context,
                      existingDealer: dealer,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Delete Dealer',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: AppColors.red),
                    onPressed: onDelete,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
