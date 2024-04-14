import 'bytes.dart';

abstract interface class IHash {
  Bytes get value;

  String string();

  String hex();

  bool equals(IHash hash);

  BigInt bigint();
}
