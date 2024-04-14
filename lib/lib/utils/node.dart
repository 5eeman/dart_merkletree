import 'dart:typed_data';

// LeafKey computes the key of a leaf node given the hIndex and hValue of the
// entry of the leaf.
import '../../types/hash.dart';
import '../hash/hash.dart' show Hash, hashElemsKey;

import '../../constants/constants.dart' show NODE_VALUE_BYTE_ARR_LENGTH;
import '../../types/types.dart' show NodeType, Bytes;
import 'bigint.dart' show bigIntToUINT8Array;

Future<Hash> leafKey(IHash k, IHash v) async {
  return hashElemsKey(BigInt.one, [k.bigint(), v.bigint()]);
}

Bytes nodeValue(NodeType type, IHash a, IHash b) {
  final bytes = Uint8List(NODE_VALUE_BYTE_ARR_LENGTH);
  final kBytes = bigIntToUINT8Array(a.bigint());
  final vBytes = bigIntToUINT8Array(b.bigint());
  bytes[0] = type;

  for (var idx = 1; idx < 33; idx += 1) {
    bytes[idx] = kBytes[idx - 1];
  }

  for (var idx = 33; idx <= NODE_VALUE_BYTE_ARR_LENGTH; idx += 1) {
    bytes[idx] = vBytes[idx - 33];
  }

  return bytes;
}
