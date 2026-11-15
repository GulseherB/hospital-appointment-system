import 'package:flutter_test/flutter_test.dart';
import 'package:hospital_app/models/role.dart';
import 'package:hospital_app/models/user.dart';

Map<String, dynamic> _json(String role, {int? institutionId}) => {
  'id': 7,
  'role': role,
  'first_name': 'Ayşe',
  'last_name': 'Demir',
  'email': 'Ayse@Demo.Local',
  'institution_id': ?institutionId,
};

void main() {
  group('User.fromJson doğru alt sınıfı üretir (kalıtım)', () {
    test('rol değerleri', () {
      expect(User.fromJson(_json('patient')), isA<Patient>());
      expect(User.fromJson(_json('doctor')), isA<Doctor>());
      expect(User.fromJson(_json('institution_admin', institutionId: 3)), isA<InstitutionAdmin>());
      expect(User.fromJson(_json('super_admin')), isA<SuperAdmin>());
    });

    test('personel sınıfları Staff türündedir, hasta değildir', () {
      expect(User.fromJson(_json('doctor')), isA<Staff>());
      expect(User.fromJson(_json('super_admin')), isA<Staff>());
      expect(User.fromJson(_json('patient')), isNot(isA<Staff>()));
    });

    test('e-posta küçük harfe çevrilir, yönetici kurum id taşır', () {
      final admin = User.fromJson(_json('institution_admin', institutionId: 3)) as InstitutionAdmin;
      expect(admin.email, 'ayse@demo.local');
      expect(admin.institutionId, 3);
    });

    test('bilinmeyen rol hata verir', () {
      expect(() => User.fromJson(_json('nurse')), throwsFormatException);
    });
  });

  group('Çok biçimlilik: menuItems ve permissions', () {
    final users = <User>[
      Patient(id: 1, firstName: 'Ali', lastName: 'Örnek', email: 'a@b.co'),
      Doctor(id: 2, firstName: 'Ayşe', lastName: 'Demir', email: 'd@b.co'),
      InstitutionAdmin(id: 3, firstName: 'Deniz', lastName: 'Yılmaz', email: 'y@b.co', institutionId: 1),
      SuperAdmin(id: 4, firstName: 'Süper', lastName: 'Admin', email: 's@b.co'),
    ];

    test('her rolün menüsü farklı ve boş değil', () {
      final menus = users.map((u) => u.menuItems().map((m) => m.route).join(',')).toSet();
      expect(menus.length, users.length);
      for (final u in users) {
        expect(u.menuItems(), isNotEmpty);
      }
    });

    test('herkes şifresini değiştirebilir; yetkiler role özeldir', () {
      for (final u in users) {
        expect(u.can(Permission.changeOwnPassword), isTrue);
      }
      expect(users[0].can(Permission.bookAppointment), isTrue);
      expect(users[1].can(Permission.bookAppointment), isFalse);
      expect(users[1].can(Permission.decideAppointments), isTrue);
      expect(users[2].can(Permission.manageDoctors), isTrue);
      expect(users[2].can(Permission.reviewApplications), isFalse);
      expect(users[3].can(Permission.reviewApplications), isTrue);
    });

    test('doktorun görünen adında ünvan vardır', () {
      expect(users[1].displayName, 'Dr. Ayşe Demir');
      expect(users[0].displayName, 'Ali Örnek');
    });
  });

  group('Kapsülleme: kurucu doğrulaması', () {
    test('geçersiz TC reddedilir', () {
      expect(
        () => Patient(id: 1, firstName: 'A', lastName: 'B', email: 'a@b.co', nationalId: '123'),
        throwsArgumentError,
      );
      expect(
        Patient(id: 1, firstName: 'A', lastName: 'B', email: 'a@b.co', nationalId: '10000000000').nationalId,
        '10000000000',
      );
    });

    test('boş ad ve geçersiz e-posta reddedilir', () {
      expect(() => Patient(id: 1, firstName: ' ', lastName: 'B', email: 'a@b.co'), throwsArgumentError);
      expect(() => Patient(id: 1, firstName: 'A', lastName: 'B', email: 'gecersiz'), throwsArgumentError);
      expect(() => Patient(id: 0, firstName: 'A', lastName: 'B', email: 'a@b.co'), throwsArgumentError);
    });
  });
}
