import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/dealer.dart';
import '../providers/ledger_provider.dart';
import '../theme/app_theme.dart';

/// Dialog for creating a new dealer or editing an existing dealer.
Future<Dealer?> showDealerFormDialog(
  BuildContext context, {
  Dealer? existingDealer,
}) {
  return showDialog<Dealer>(
    context: context,
    builder: (ctx) => _DealerFormDialog(existingDealer: existingDealer),
  );
}

class _DealerFormDialog extends StatefulWidget {
  final Dealer? existingDealer;

  const _DealerFormDialog({this.existingDealer});

  @override
  State<_DealerFormDialog> createState() => _DealerFormDialogState();
}

class _DealerFormDialogState extends State<_DealerFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _codeController;
  late final TextEditingController _nameController;
  bool _saving = false;

  bool get _isEditing => widget.existingDealer != null;

  @override
  void initState() {
    super.initState();
    final provider = context.read<LedgerProvider>();
    _codeController = TextEditingController(
      text: widget.existingDealer?.code ?? provider.suggestNextDealerCode(),
    );
    _nameController = TextEditingController(
      text: widget.existingDealer?.name ?? '',
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final provider = context.read<LedgerProvider>();
      final code = _codeController.text.trim();
      final name = _nameController.text.trim();

      if (_isEditing) {
        final updated = widget.existingDealer!.copyWith(
          code: code,
          name: name,
        );
        await provider.updateDealer(updated);
        if (mounted) Navigator.of(context).pop(updated);
      } else {
        final created = await provider.addDealer(code: code, name: name);
        if (mounted) Navigator.of(context).pop(created);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Edit Dealer' : 'Add New Dealer'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _codeController,
                decoration: const InputDecoration(
                  labelText: 'Dealer Code',
                  hintText: 'e.g. 100-0150',
                  prefixIcon: Icon(Icons.tag),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Dealer code is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Dealer Name',
                  hintText: 'e.g. HANEEF BAKERS',
                  prefixIcon: Icon(Icons.store_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Dealer name is required';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.navy),
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : Text(_isEditing ? 'Save Changes' : 'Create Dealer'),
        ),
      ],
    );
  }
}
