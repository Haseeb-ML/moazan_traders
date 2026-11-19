import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

Future<void> showChangeCredentialsDialog(
  BuildContext context,
  AuthService authService,
) async {
  final currentUser = await authService.getCurrentUsername();
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => _ChangeCredentialsDialog(
      authService: authService,
      initialUsername: currentUser,
    ),
  );
}

class _ChangeCredentialsDialog extends StatefulWidget {
  final AuthService authService;
  final String initialUsername;

  const _ChangeCredentialsDialog({
    required this.authService,
    required this.initialUsername,
  });

  @override
  State<_ChangeCredentialsDialog> createState() =>
      _ChangeCredentialsDialogState();
}

class _ChangeCredentialsDialogState extends State<_ChangeCredentialsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameCtrl;
  final _currentPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _usernameCtrl = TextEditingController(text: widget.initialUsername);
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _currentPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final ok = await widget.authService.changeCredentials(
        currentPassword: _currentPassCtrl.text,
        newUsername: _usernameCtrl.text,
        newPassword: _newPassCtrl.text,
      );
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Username & Password updated on Cloud!'),
            backgroundColor: AppColors.credit,
          ),
        );
      } else {
        setState(() => _error = 'Current password is incorrect');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Update failed: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change Username & Password'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _currentPassCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Current Password',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Enter current password' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _usernameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'New Username',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().length < 3)
                      ? 'Username min 3 characters'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _newPassCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.length < 4)
                      ? 'Password min 4 characters'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _confirmPassCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm New Password',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => v != _newPassCtrl.text
                      ? 'Passwords do not match'
                      : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _error!,
                    style: const TextStyle(color: AppColors.debit, fontSize: 13),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save Changes'),
        ),
      ],
    );
  }
}
