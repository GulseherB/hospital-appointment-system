import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../core/validators.dart';
import '../widgets/common.dart';

/// Şifre değiştirme. [forced] true ise geçici şifreyle giriş yapılmıştır:
/// geri dönüş yoktur, değiştirmeden başka ekrana geçilemez.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, this.forced = false});

  final bool forced;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _again = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _again.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final session = AppScope.of(context).session;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await session.changePassword(_current.text, _new.text);
      if (!widget.forced) {
        navigator.pop();
        messenger.showSnackBar(const SnackBar(content: Text('Şifreniz değiştirildi.')));
      }
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = AppScope.of(context).session;
    return PopScope(
      canPop: !widget.forced,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Şifre Değiştir'),
          automaticallyImplyLeading: !widget.forced,
          actions: [if (widget.forced) TextButton(onPressed: session.logout, child: const Text('Çıkış Yap'))],
        ),
        body: FormCard(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.forced)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: Text('Geçici bir şifreyle giriş yaptınız. Devam etmek için yeni bir şifre belirleyin.'),
                  ),
                if (_error != null) ErrorBanner(_error!),
                PasswordField(
                  controller: _current,
                  label: widget.forced ? 'Geçici şifre' : 'Mevcut şifre',
                  validator: (v) => Validators.requiredText(v, 'Mevcut şifre'),
                ),
                const SizedBox(height: 12),
                PasswordField(
                  controller: _new,
                  label: 'Yeni şifre',
                  validator: (v) {
                    final error = Validators.password(v);
                    if (error != null) return error;
                    return v == _current.text ? 'Yeni şifre mevcut şifreyle aynı olamaz.' : null;
                  },
                ),
                const SizedBox(height: 12),
                PasswordField(
                  controller: _again,
                  label: 'Yeni şifre (tekrar)',
                  validator: (v) => v == _new.text ? null : 'Şifreler eşleşmiyor.',
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 24),
                SubmitButton(label: 'Şifreyi Değiştir', loading: _loading, onPressed: _submit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
