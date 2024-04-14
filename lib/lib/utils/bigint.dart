import "dart:typed_data";
import "../../types/types.dart";
import "../../constants/constants.dart";

List<int> bigint2Array(BigInt bigNum, {int radix = 10}) {
  return bigNum
      .toRadixString(radix)
      .split('')
      .map((n) => int.parse(n))
      .toList();
}

Bytes bigIntToUINT8Array(BigInt bigNum) {
  final n256 = BigInt.from(256);
  final bytes = Uint8List(HASH_BYTES_LENGTH);
  var i = 0;
  while (bigNum > BigInt.zero) {
    bytes[HASH_BYTES_LENGTH - 1 - i] = (bigNum % n256).toInt();
    bigNum = bigNum ~/ n256;
    i += 1;
  }
  return bytes;
}
