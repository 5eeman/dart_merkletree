import 'dart:convert';
import "dart:typed_data";

import 'package:poseidon/poseidon.dart';
import 'package:convert/convert.dart' as convert;

import '../../constants/constants.dart';
import "../../types/types.dart";

import '../utils/utils.dart'
    show
        bytesEqual,
        swapEndianness,
        bytes2Hex,
        bytes2BinaryString,
        checkBigIntInField,
        bigIntToUINT8Array;

final _zeroHash = Uint8List(HASH_BYTES_LENGTH);

class Hash implements IHash {
  // little endian
  final Bytes? _bytes;

  const Hash.zero() : _bytes = null;

  const Hash._(this._bytes);

  factory Hash(Bytes? bytes) {
    if (bytes != null && bytes.isNotEmpty) {
      if (bytes.length != HASH_BYTES_LENGTH) {
        throw Exception(
            'Expected $HASH_BYTES_LENGTH bytes, found ${bytes.length} bytes');
      }
      return Hash._(bytes);
    } else {
      return const Hash.zero();
    }
  }

  // returns a new copy, in little endian
  @override
  Bytes get value {
    return _bytes ?? _zeroHash;
  }

  //
  // // bytes should be in big-endian
  // @override
  // set value(Bytes bytes) {
  //   if (bytes.length != HASH_BYTES_LENGTH) {
  //     throw Exception('Expected 32 bytes, found ${bytes.length} bytes');
  //   }
  //   _bytes = swapEndianness(bytes);
  // }

  @override
  String string() {
    return bigint().toRadixString(10);
  }

  @override
  String hex() {
    return bytes2Hex(_bytes ?? _zeroHash);
  }

  @override
  bool equals(IHash hash) {
    return bytesEqual(value, hash.value);
  }

  @override
  BigInt bigint() {
    final bytes = swapEndianness(value);
    final binaryString = bytes2BinaryString(bytes);
    return BigInt.parse(binaryString.replaceAll('0b', ''), radix: 2);
  }

  factory Hash.fromString(String s) {
    try {
      return Hash.fromBigInt(BigInt.parse(s));
    } catch (e) {
      final deserializedHash = jsonDecode(s);
      final rawBytes = (deserializedHash["bytes"] as Map).values;
      final bytesList = rawBytes.map((e) => e as int).toList();
      final bytes = Uint8List.fromList(bytesList.toList());
      return Hash(bytes);
    }
  }

  factory Hash.fromBigInt(BigInt i) {
    if (!checkBigIntInField(i)) {
      throw Exception(
          'NewBigIntFromHashBytes: Value not inside the Finite Field');
    }

    final bytes = bigIntToUINT8Array(i);

    return Hash(swapEndianness(bytes));
  }

  factory Hash.fromHex(String? h) {
    if (h == null) {
      return ZERO_HASH;
    }

    final bytes = convert.hex.decode(h);

    return Hash(Uint8List.fromList(bytes));
  }
}

const ZERO_HASH = Hash.zero();

/**
 * @deprecated The method should not be used and will be removed in the next major version,
 * please use Hash.fromBigInt instead
 */
Hash newHashFromBigInt(BigInt bigNum) {
  return Hash.fromBigInt(bigNum);
}

/**
 * @deprecated The method should not be used and will be removed in the next major version,
 * please use Hash.fromBigInt instead
 */
Hash newHashFromHex(String h) {
  return Hash.fromHex(h);
}

/**
 * @deprecated The method should not be used and will be removed in the next major version,
 * please use Hash.fromBigString instead
 */
Hash newHashFromString(String decimalString) {
  return Hash.fromString(decimalString);
}

Hash hashElems(List<BigInt> e) {
  final hashBigInt = poseidon(e);
  return Hash.fromBigInt(hashBigInt);
}

Hash hashElemsKey(BigInt k, List<BigInt> e) {
  final hashBigInt = poseidon([...e, k]);
  return Hash.fromBigInt(hashBigInt);
}

Siblings circomSiblingsFromSiblings(Siblings siblings, int levels) {
  for (var i = siblings.length; i < levels; i += 1) {
    siblings.add(ZERO_HASH);
  }
  return siblings;
}

BigInt poseidon(List<BigInt> inputs) {
  // TODO(moria): Check implementation matches with @iden3/js-crypto
  switch (inputs.length) {
    case 1:
      return poseidon1(inputs);
    case 2:
      return poseidon2(inputs);
    case 3:
      return poseidon3(inputs);
    case 4:
      return poseidon4(inputs);
    case 5:
      return poseidon5(inputs);
    case 6:
      return poseidon6(inputs);
    case 7:
      return poseidon7(inputs);
    case 8:
      return poseidon8(inputs);
    case 9:
      return poseidon9(inputs);
    case 10:
      return poseidon10(inputs);
    case 11:
      return poseidon11(inputs);
    case 12:
      return poseidon12(inputs);
    case 13:
      return poseidon13(inputs);
    case 14:
      return poseidon14(inputs);
    case 15:
      return poseidon15(inputs);
    case 16:
      return poseidon16(inputs);
    default:
      throw Exception('Invalid number of inputs');
  }
}
