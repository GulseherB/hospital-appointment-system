import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../core/error/api_exception.dart';
import '../../core/widgets/section_card.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  String? _message;

  @override
  void dispose() {
    for (final controller in [_name, _email, _phone, _password]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      await AppScope.of(context).authRepository.register(
        fullName: _name.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        phone: _phone.text.trim(),
      );
      if (mounted) {
        setState(
          () => _message = 'Kayıt başarılı. Giriş ekranına dönebilirsiniz.',
        );
      }
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _message = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Kayıt başarısız. Beklenmeyen bir hata oluştu.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hasta kaydı')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: SectionCard(
              title: 'Yeni hasta hesabı',
              icon: Icons.person_add_outlined,
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _field(_name, 'Ad soyad', minLength: 2),
                    _field(_email, 'E-posta', email: true),
                    _field(_phone, 'Telefon'),
                    _field(_password, 'Şifre', minLength: 8, obscure: true),
                    if (_message != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(_message!),
                      ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _loading ? null : _register,
                        child: _loading
                            ? const CircularProgressIndicator()
                            : const Text('Kayıt ol'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    bool email = false,
    bool obscure = false,
    int minLength = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        decoration: InputDecoration(labelText: label),
        keyboardType: email ? TextInputType.emailAddress : null,
        obscureText: obscure,
        validator: (value) {
          if (value == null || value.trim().length < minLength) {
            return '$label geçerli değil';
          }
          if (email && !value.contains('@')) {
            return 'Geçerli bir e-posta girin';
          }
          return null;
        },
      ),
    );
  }
}
