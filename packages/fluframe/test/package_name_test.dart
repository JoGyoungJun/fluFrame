import 'package:fluframe/src/package_name.dart';
import 'package:test/test.dart';

void main() {
  group('isValidPackageName', () {
    test('accepts lower_snake_case names', () {
      expect(isValidPackageName('my_app'), isTrue);
      expect(isValidPackageName('app2'), isTrue);
      expect(isValidPackageName('_private'), isTrue);
    });

    test('rejects invalid names', () {
      expect(isValidPackageName('MyApp'), isFalse);
      expect(isValidPackageName('1app'), isFalse);
      expect(isValidPackageName('my-app'), isFalse);
      expect(isValidPackageName('my app'), isFalse);
      expect(isValidPackageName(''), isFalse);
    });

    test('rejects Dart reserved words', () {
      expect(isValidPackageName('class'), isFalse);
      expect(isValidPackageName('switch'), isFalse);
      expect(isValidPackageName('void'), isFalse);
    });
  });

  group('humanizePackageName', () {
    test('title-cases underscore-separated parts', () {
      expect(humanizePackageName('my_cool_app'), 'My Cool App');
      expect(humanizePackageName('app'), 'App');
      expect(humanizePackageName('_private'), 'Private');
    });
  });
}
