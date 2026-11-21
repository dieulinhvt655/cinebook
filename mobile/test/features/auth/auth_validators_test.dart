import 'package:cinebook/features/auth/presentation/auth_validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('email', () {
    test('required, format and length (BR-01.2, BR-01.6)', () {
      expect(AuthValidators.email(''), 'Vui lòng nhập email');
      expect(AuthValidators.email('   '), 'Vui lòng nhập email');
      expect(
        AuthValidators.email('demo@cinebook'),
        'Email không đúng định dạng',
      );
      expect(
        AuthValidators.email('${'a' * 250}@x.vn'),
        'Email tối đa 254 ký tự',
      );
      expect(AuthValidators.email(' Demo@CineBook.dev '), isNull);
    });
  });

  test('login password only has to be present (old accounts keep working)', () {
    expect(AuthValidators.loginPassword(''), 'Vui lòng nhập mật khẩu');
    expect(AuthValidators.loginPassword('Demo@1234'), isNull);
  });

  group('new password (BR-02)', () {
    test('at least 15 characters, counted as characters not bytes', () {
      expect(
        AuthValidators.newPassword('Demo@1234'),
        'Mật khẩu phải có ít nhất 15 ký tự',
      );
      expect(
        AuthValidators.newPassword('ăn cơm chưa bạ'),
        'Mật khẩu phải có ít nhất 15 ký tự',
      );
      expect(AuthValidators.newPassword('mưa rơi trên phố'), isNull);
    });

    test('spaces allowed, no composition rules, never trimmed', () {
      expect(AuthValidators.newPassword('ngựa vằn ăn cỏ ven sông'), isNull);
      expect(AuthValidators.newPassword('onlylowercaseletters'), isNull);
      expect(AuthValidators.newPassword('   short pass   '), isNull);
    });

    test('at most 64 characters and 72 UTF-8 bytes', () {
      expect(
        AuthValidators.newPassword('a1b2c3d4e5' * 7),
        'Mật khẩu quá dài (tối đa 64 ký tự)',
      );
      expect(
        AuthValidators.newPassword('ằẳẵặẫậầẩấềểễệếởỡợờớừửữựứỳỷỹỵý'),
        'Mật khẩu quá dài (tối đa 64 ký tự)',
      );
    });

    test('confirmation must match exactly', () {
      expect(
        AuthValidators.confirmPassword('', 'x'),
        'Vui lòng nhập lại mật khẩu',
      );
      expect(
        AuthValidators.confirmPassword('abc ', 'abc'),
        'Mật khẩu nhập lại không khớp',
      );
      expect(AuthValidators.confirmPassword('abc', 'abc'), isNull);
    });
  });

  test('full name required, phone optional but Vietnamese format', () {
    expect(AuthValidators.fullName(' '), 'Vui lòng nhập họ tên');
    expect(AuthValidators.fullName('Nguyễn Văn A'), isNull);
    expect(AuthValidators.phone(''), isNull);
    expect(AuthValidators.phone('0912345678'), isNull);
    expect(AuthValidators.phone('+84912345678'), isNull);
    expect(AuthValidators.phone('12345'), 'Số điện thoại không hợp lệ');
  });
}
