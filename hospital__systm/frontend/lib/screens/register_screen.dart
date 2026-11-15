import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../core/validators.dart';
import '../services/auth_service.dart';
import '../widgets/common.dart';

/// Hasta kaydı: ad, soyad, TC (zorunlu, 11 rakam), e-posta, telefon, şifre.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _nationalId = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _passwordAgain = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_firstName, _lastName, _nationalId, _email, _phone, _password, _passwordAgain]) {
      c.dispose();
    }
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
      await session.register(
        PatientRegistration(
          firstName: _firstName.text,
          lastName: _lastName.text,
          nationalId: _nationalId.text,
          email: _email.text,
          phone: _phone.text,
          password: _password.text,
        ),
      );
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
      appBar: AppBar(title: const Text('Hasta Kaydı')),
      body: FormCard(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ErrorBanner(_error!),
              LabeledField(controller: _firstName, label: 'Ad', validator: (v) => Validators.requiredText(v, 'Ad')),
              LabeledField(
                controller: _lastName,
                label: 'Soyad',
                validator: (v) => Validators.requiredText(v, 'Soyad'),
              ),
              LabeledField(
                controller: _nationalId,
                label: 'TC Kimlik No',
                keyboardType: TextInputType.number,
                maxLength: 11,
                validator: Validators.nationalId,
              ),
              LabeledField(
                controller: _email,
                label: 'E-posta',
                keyboardType: TextInputType.emailAddress,
                validator: Validators.email,
              ),
              LabeledField(
                controller: _phone,
                label: 'Telefon',
                keyboardType: TextInputType.phone,
                validator: Validators.phone,
              ),
              PasswordField(controller: _password, label: 'Şifre', validator: Validators.password),
              const SizedBox(height: 12),
              PasswordField(
                controller: _passwordAgain,
                label: 'Şifre (tekrar)',
                validator: (v) => v == _password.text ? null : 'Şifreler eşleşmiyor.',
              ),
              const SizedBox(height: 24),
              SubmitButton(label: 'Kayıt Ol', loading: _loading, onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}
