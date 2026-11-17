import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/dealer.dart';
import '../models/ledger_entry.dart';
import '../providers/ledger_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Dialog to Create or Edit a Debit (Bill) or Credit (Payment Received) entry.
Future<bool> showEntryFormDialog(
  BuildContext context, {
  Dealer? initialDealer,
  EntryType initialType = EntryType.debit,
  LedgerEntry? existingEntry,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => _EntryFormDialog(
      initialDealer: initialDealer,
      initialType: existingEntry?.type ?? initialType,
      existingEntry: existingEntry,
    ),
  );
  return result ?? false;
}

class _EntryFormDialog extends StatefulWidget {
  final Dealer? initialDealer;
  final EntryType initialType;
  final LedgerEntry? existingEntry;

  const _EntryFormDialog({
    this.initialDealer,
    required this.initialType,
    this.existingEntry,
  });

  @override
  State<_EntryFormDialog> createState() => _EntryFormDialogState();
}

class _EntryFormDialogState extends State<_EntryFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late EntryType _type;
  Dealer? _selectedDealer;
  late DateTime _selectedDate;
  late final TextEditingController _billNoController;
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  bool _saving = false;

  bool get _isEditing => widget.existingEntry != null;

  @override
  void initState() {
    super.initState();
    final provider = context.read<LedgerProvider>();
    _type = widget.initialType;
    _selectedDate = widget.existingEntry?.date ?? DateTime.now();
    _billNoController = TextEditingController(
      text: widget.existingEntry?.billNo ?? '',
    );
    _amountController = TextEditingController(
      text: widget.existingEntry != null
          ? widget.existingEntry!.amount.toStringAsFixed(
              widget.existingEntry!.amount.truncateToDouble() ==
                      widget.existingEntry!.amount
                  ? 0
                  : 2,
            )
          : '',
    );
    _noteController = TextEditingController(
      text: widget.existingEntry?.note ?? '',
    );

    if (widget.existingEntry != null) {
      final match = provider.dealers.where(
        (d) => d.id == widget.existingEntry!.dealerId,
      );
      _selectedDealer = match.isNotEmpty ? match.first : null;
    } else {
      _selectedDealer = widget.initialDealer;
    }
  }

  @override
  void dispose() {
    _billNoController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickDealer(List<Dealer> dealers) async {
    final chosen = await showDialog<Dealer>(
      context: context,
      builder: (ctx) => _DealerSearchDialog(dealers: dealers),
    );
    if (chosen != null) {
      setState(() => _selectedDealer = chosen);
    }
  }

  Future<void> _submit() async {
    if (_selectedDealer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a dealer')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountController.text.trim());
    setState(() => _saving = true);

    try {
      final provider = context.read<LedgerProvider>();
      if (_isEditing) {
        final updated = widget.existingEntry!.copyWith(
          dealerId: _selectedDealer!.id,
          dealerCode: _selectedDealer!.code,
          dealerName: _selectedDealer!.name,
          type: _type,
          amount: amount,
          date: _selectedDate,
          billNo: _billNoController.text.trim(),
          note: _noteController.text.trim(),
        );
        await provider.updateEntry(updated);
      } else {
        await provider.addEntry(
          dealer: _selectedDealer!,
          type: _type,
          amount: amount,
          date: _selectedDate,
          billNo: _billNoController.text.trim(),
          note: _noteController.text.trim(),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LedgerProvider>();
    final dealers = provider.dealers;
    final isDebit = _type == EntryType.debit;
    final enteredAmount = double.tryParse(_amountController.text.trim()) ?? 0;
    final currentBalance = _selectedDealer != null
        ? provider.summaryForDealer(_selectedDealer!.id).balance
        : 0.0;
    final baseBalance = _isEditing &&
            _selectedDealer?.id == widget.existingEntry!.dealerId
        ? currentBalance -
            (widget.existingEntry!.type == EntryType.debit
                ? widget.existingEntry!.amount
                : -widget.existingEntry!.amount)
        : currentBalance;
    final projectedBalance =
        baseBalance + (isDebit ? enteredAmount : -enteredAmount);

    return AlertDialog(
      title: Text(_isEditing ? 'Edit Khata Entry' : 'New Khata Entry'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Debit / Credit toggle
                SegmentedButton<EntryType>(
                  segments: const [
                    ButtonSegment(
                      value: EntryType.debit,
                      icon: Icon(Icons.arrow_upward, size: 18),
                      label: Text('Debit'),
                    ),
                    ButtonSegment(
                      value: EntryType.credit,
                      icon: Icon(Icons.arrow_downward, size: 18),
                      label: Text('Credit'),
                    ),
                  ],
                  selected: {_type},
                  onSelectionChanged: (set) {
                    setState(() => _type = set.first);
                  },
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return isDebit
                            ? AppColors.debitBg
                            : AppColors.creditBg;
                      }
                      return null;
                    }),
                    foregroundColor: WidgetStateProperty.resolveWith((states) {
                      if (states.contains(WidgetState.selected)) {
                        return isDebit ? AppColors.debit : AppColors.credit;
                      }
                      return null;
                    }),
                  ),
                ),
                const SizedBox(height: 16),

                // Dealer Picker (searchable by Name or Code)
                InkWell(
                  onTap: () => _pickDealer(dealers),
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Dealer (Name or Code)',
                      prefixIcon: Icon(Icons.store_outlined),
                      suffixIcon: Icon(Icons.search),
                    ),
                    child: _selectedDealer == null
                        ? const Text(
                            'Tap to select dealer...',
                            style: TextStyle(color: AppColors.textMuted),
                          )
                        : Text(
                            '${_selectedDealer!.code} • ${_selectedDealer!.name}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                  ),
                ),
                if (_selectedDealer != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Current: ${AppFormatters.formatRs(baseBalance)}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textMuted),
                        ),
                        Text(
                          'New Bal: ${AppFormatters.formatRs(projectedBalance)}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: projectedBalance > 0
                                ? AppColors.debit
                                : AppColors.credit,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),

                // Date Picker
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    child: Text(
                      AppFormatters.formatDate(_selectedDate),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Bill No.
                TextFormField(
                  controller: _billNoController,
                  decoration: InputDecoration(
                    labelText: isDebit
                        ? 'Bill No. (Optional)'
                        : 'Receipt / Bill No. (Optional)',
                    hintText: 'e.g. 29',
                    prefixIcon: const Icon(Icons.receipt_long_outlined),
                  ),
                ),
                const SizedBox(height: 14),

                // Amount
                TextFormField(
                  controller: _amountController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: isDebit
                        ? 'Debit Amount (Rs.)'
                        : 'Credit Amount (Rs.)',
                    hintText: '0',
                    prefixIcon: const Icon(Icons.payments_outlined),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Amount is required';
                    }
                    final parsed = double.tryParse(v.trim());
                    if (parsed == null || parsed <= 0) {
                      return 'Enter a valid amount greater than 0';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Optional short note
                TextFormField(
                  controller: _noteController,
                  decoration: const InputDecoration(
                    labelText: 'Note (Optional)',
                    hintText: 'e.g. Bill #124 / Cash',
                    prefixIcon: Icon(Icons.notes_outlined),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: isDebit ? AppColors.debit : AppColors.credit,
          ),
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(_isEditing ? 'Update Entry' : 'Save Entry'),
        ),
      ],
    );
  }
}

class _DealerSearchDialog extends StatefulWidget {
  final List<Dealer> dealers;

  const _DealerSearchDialog({required this.dealers});

  @override
  State<_DealerSearchDialog> createState() => _DealerSearchDialogState();
}

class _DealerSearchDialogState extends State<_DealerSearchDialog> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final filtered = widget.dealers.where((d) {
      if (q.isEmpty) return true;
      return d.name.toLowerCase().contains(q) ||
          d.code.toLowerCase().contains(q);
    }).toList();

    final maxH = (MediaQuery.of(context).size.height * 0.52).clamp(240.0, 440.0);

    return AlertDialog(
      title: const Text('Select Dealer'),
      content: SizedBox(
        width: 420,
        height: maxH,
        child: Column(
          children: [
            TextField(
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Search by name or code (e.g. 100-0035)...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: filtered.isEmpty
                  ? const Center(child: Text('No dealer found'))
                  : ListView.separated(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final dealer = filtered[i];
                        return ListTile(
                          dense: true,
                          leading: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.navy.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              dealer.code,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.navy,
                              ),
                            ),
                          ),
                          title: Text(
                            dealer.name,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          onTap: () => Navigator.of(ctx).pop(dealer),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
