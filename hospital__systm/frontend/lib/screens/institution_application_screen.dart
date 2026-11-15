import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../core/validators.dart';
import '../models/institution.dart';
import '../services/institution_service.dart';
import '../widgets/common.dart';

/// Kurum başvurusu: kurum bilgileri + yönetici bilgileri. Süper admin onaylayınca yönetici giriş yapabilir.
class InstitutionApplicationScreen extends StatefulWidget {
  const InstitutionApplicationScreen({super.key});

  @override
  State<InstitutionApplicationScreen> createState() => _InstitutionApplicationScreenState();
}

class _InstitutionApplicationScreenState extends State<InstitutionApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _adminFirstName = TextEditingController();
  final _adminLastName = TextEditingController();
  final _adminEmail = TextEditingController();
  final _adminPhone = TextEditingController();
  final _password = TextEditingController();
  final _passwordAgain = TextEditingController();
  InstitutionType _type = InstitutionType.clinic;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _name,
      _address,
      _phone,
      _email,
      _adminFirstName,
      _adminLastName,
      _adminEmail,
      _adminPhone,
      _password,
      _passwordAgain,
    ]) {
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
    final service = InstitutionService(AppScope.of(context).api);
    final navigator = Navigator.of(context);
    try {
      await service.apply(
        ApplicationForm(
          institutionName: _name.text,
          institutionType: _type,
          institutionAddress: _address.text,
          institutionPhone: _phone.text,
          institutionEmail: _email.text,
          adminFirstName: _adminFirstName.text,
          adminLastName: _adminLastName.text,
          adminEmail: _adminEmail.text,
          adminPhone: _adminPhone.text,
          adminPassword: _password.text,
        ),
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Başvurunuz alındı'),
          content: const Text(
            'Başvurunuz süper admin tarafından incelenecek. Onaylandıktan sonra '
            '"Yönetici Girişi" ile bu e-posta ve şifreyle giriş yapabilirsiniz.',
          ),
          actions: [FilledButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Tamam'))],
        ),
      );
      navigator.pop();
    } catch (e) {
      if (mounted) setState(() => _error = errorText(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium;
    return Scaffold(
      appBar: AppBar(title: const Text('Kurum Başvurusu')),
      body: FormCard(
        maxWidth: 560,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_error != null) ErrorBanner(_error!),
              Text('Kurum bilgileri', style: titleStyle),
              const SizedBox(height: 12),
              LabeledField(
                controller: _name,
                label: 'Kurum adı',
                validator: (v) => Validators.requiredText(v, 'Kurum adı'),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: SegmentedButton<InstitutionType>(
                  segments: [for (final t in InstitutionType.values) ButtonSegment(value: t, label: Text(t.label))],
                  selected: {_type},
                  onSelectionChanged: (s) => setState(() => _type = s.first),
                ),
              ),
              LabeledField(controller: _address, label: 'Adres', validator: (v) => Validators.requiredText(v, 'Adres')),
              LabeledField(
                controller: _phone,
                label: 'Kurum telefonu',
                keyboardType: TextInputType.phone,
                validator: Validators.phone,
              ),
              LabeledField(
                controller: _email,
                label: 'Kurum e-postası',
                keyboardType: TextInputType.emailAddress,
                validator: Validators.email,
              ),
              const Divider(height: 32),
              Text('Yönetici bilgileri', style: titleStyle),
              const SizedBox(height: 12),
              LabeledField(
                controller: _adminFirstName,
                label: 'Ad',
                validator: (v) => Validators.requiredText(v, 'Ad'),
              ),
              LabeledField(
                controller: _adminLastName,
                label: 'Soyad',
                validator: (v) => Validators.requiredText(v, 'Soyad'),
              ),
              LabeledField(
                controller: _adminEmail,
                label: 'E-posta (giriş için)',
                keyboardType: TextInputType.emailAddress,
                validator: Validators.email,
              ),
              LabeledField(
                controller: _adminPhone,
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
              SubmitButton(label: 'Başvuruyu Gönder', loading: _loading, onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}
