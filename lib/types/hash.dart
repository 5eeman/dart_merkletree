import 'bytes.dart';

abstract interface class IHash {
  Bytes get value;

  String hex();

  BigInt bigint();
}
