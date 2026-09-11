import 'package:uuid/uuid.dart';

final Uuid _uuid = const Uuid();

class IdGenerator {
  const IdGenerator._();

  static String installation() => 'install_${_uuid.v7()}';

  static String character() => 'char_${_uuid.v7()}';

  static String message() => 'msg_${_uuid.v7()}';

  static String summary() => 'sum_${_uuid.v7()}';

  static String generic(String prefix) => '${prefix}_${_uuid.v7()}';
}
