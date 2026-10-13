import 'package:flutter_test/flutter_test.dart';
import 'package:liveprice/services/auth_service.dart';

void main() {
  group('AuthService.branchEmail', () {
    test('maps each branch ID to its mailbox', () {
      expect(AuthService.branchEmail('b1'), 'liveprice.branches+b1@gmail.com');
      expect(AuthService.branchEmail('b2'), 'liveprice.branches+b2@gmail.com');
      expect(AuthService.branchEmail('b3'), 'liveprice.branches+b3@gmail.com');
    });

    test('rejects unknown branch IDs', () {
      expect(() => AuthService.branchEmail('unknown'), throwsArgumentError);
    });
  });
}
