import 'package:flutter_test/flutter_test.dart';
import 'package:croqui_forense_mvp/core/utils/uuid_helper.dart';

void main() {
  test('test deterministicUuidV5 generates valid V5 UUID', () {
    final v5 = deterministicUuidV5('49cc9dd0-3e0b-4df3-99f8-3f7cee6e7e18', 'balistica');
    expect(v5, equals('e65ffe6d-c913-50ba-aa6d-e379c49befb3'));
    // Version is 5
    expect(v5[14], equals('5'));
    // Variant is RFC 4122 (8, 9, a, or b)
    expect(['8', '9', 'a', 'b'].contains(v5[19]), isTrue);
  });

  test('test deterministicUuidV4 remains intact for backwards compatibility', () {
    final v4 = deterministicUuidV4('49cc9dd0-3e0b-4df3-99f8-3f7cee6e7e18', 'balistica');
    expect(v4, equals('056ddd09-8128-4860-aada-606b950e4b9e'));
    expect(v4[14], equals('4'));
    expect(v4[19], equals('a'));
  });
}

