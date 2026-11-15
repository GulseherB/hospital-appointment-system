import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../core/validators.dart';
import '../models/role.dart';
import '../widgets/common.dart';

/// Giriş seçenekleri. Hepsi aynı `/auth/login` uç noktasını kullanır;
/// gelen rol seçenekle uyuşmazsa oturum açılmaz.
enum LoginKind {
  patient('Hasta Girişi', {UserRole.patient}),
  doctor('Doktor Girişi', {UserRole.doctor}),
  // Süper admin ayrı bir seçenek olarak gösterilmez; yönetici girişini kullanır.
  admin('Yönetici Girişi', {UserRole.institutionAdmin, UserRole.superAdmin});

  const LoginKind(this.title, this.allowedRoles);

  final String title;
  final Set<UserRole> allowedRoles;
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.kind});

  final LoginKind kind;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
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
    try {
      await session.login(_email.text, _password.text, widget.kind.allowedRoles);
      // Oturum açıldı: kök ekran kullanıcıyı paneline yönlendirir.
      navigator.popUntil((route) => route.isFirst);
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.kind.title)),
      body: FormCard(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ErrorBanner(_error!),
              LabeledField(
                controller: _email,
                label: 'E-posta',
                keyboardType: TextInputType.emailAddress,
                validator: Validators.email,
              ),
              PasswordField(
                controller: _password,
                label: 'Şifre',
                validator: (v) => Validators.requiredText(v, 'Şifre'),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),
              SubmitButton(label: 'Giriş Yap', loading: _loading, onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}
