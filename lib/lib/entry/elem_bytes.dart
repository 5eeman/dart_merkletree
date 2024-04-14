import "dart:typed_data";

import '../../constants/constants.dart' show ELEM_BYTES_LEN;
import '../utils/utils.dart' show bytes2Hex, newBigIntFromBytes, swapEndianness;
import '../../types/types.dart' show Bytes;

class ElemBytes {
  // Little Endian
  Bytes _bytes;

  ElemBytes() : _bytes = Uint8List(ELEM_BYTES_LEN);

  Bytes get value {
    return _bytes;
  }

  set value(Bytes b) {
    _bytes = b;
  }

  BigInt bigInt() {
    return newBigIntFromBytes(swapEndianness(_bytes));
  }

  String string() {
    final hexStr = bytes2Hex(_bytes.sublist(0, 4));
    return '$hexStr...';
  }
}
