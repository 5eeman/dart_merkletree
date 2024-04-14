import 'dart:typed_data';

import '../../types/types.dart' show Bytes;
import '../../constants/constants.dart';
import 'crypto.dart';

bool bytesEqual(Bytes b1, Bytes b2) {
  for (final (idx, val) in b1.indexed) {
    if (val != b2[idx]) {
      return false;
    }
  }
  return true;
}

Bytes swapEndianness(Bytes bytes) {
  return Uint8List.fromList(bytes.reversed.toList());
}

String bytes2BinaryString(Bytes bytes) {
  return '0b${bytes.fold('', (acc, i) => acc + i.toRadixString(2).padLeft(8, '0'))}';
}

bool testBit(Bytes bitMap, int n) {
  return (bitMap[int.parse((n ~/ 8).toString())] & (1 << n % 8)) != 0;
}

bool testBitBigEndian(Bytes bitMap, int n) {
  return (bitMap[bitMap.length - int.parse('${n ~/ 8}') - 1] & (1 << n % 8)) !=
      0;
}

// SetBitBigEndian sets the bit n in the bitmap to 1, in Big Endian.
void setBitBigEndian(Bytes bitMap, int n) {
  bitMap[bitMap.length - int.parse('${n ~/ 8}') - 1] |= 1 << n % 8;
}

const hextable = '0123456789abcdef';

String bytes2Hex(Bytes u) {
  final arr = List<String>.filled(u.length * 2, '');
  var j = 0;
  for (var v in u) {
    arr[j] = hextable[int.parse((v >> 4).toRadixString(10))];
    arr[j + 1] = hextable[int.parse((v & 15).toRadixString(10))];
    j += 2;
  }

  return arr.join('');
}

// NOTE: `bytes` should be big endian
// bytes recieved from Hash.value getter are safe to use since their endianness is swapped, for the same reason the private Hash.bytes { stored in little endian } should never be used
BigInt newBigIntFromBytes(Bytes bytes) {
  if (bytes.length != HASH_BYTES_LENGTH) {
    throw Exception('Expected 32 bytes, found ${bytes.length} bytes');
  }

  final bigNum = BigInt.parse(bytes2BinaryString(bytes), radix: 2);
  if (!checkBigIntInField(bigNum)) {
    throw 'NewBigIntFromHashBytes: Value not inside the Finite Field';
  }

  return bigNum;
}

// TODO(moria): This works wrong in both JS and Dart
// It should handle cases of UTF-16
Bytes str2Bytes(String str) {
  final bytes = List.generate(str.length * 2, (idx) {
    return idx >= str.length ? 0 : str.codeUnitAt(idx);
  }).toList();

  return Uint8List.fromList(bytes);
}
