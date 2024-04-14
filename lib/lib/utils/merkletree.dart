import "dart:typed_data";

import '../../constants/constants.dart' show HASH_BYTES_LENGTH;
import '../../types/types.dart' show Bytes, Path, Siblings;
import 'bytes.dart';

// const siblingBytes = bs.slice(this.notEmpties.length + PROOF_FLAG_LEN);

Path getPath(int numLevels, Bytes k) {
  final path = List.filled(numLevels, false);

  for (var idx = 0; idx < numLevels; idx += 1) {
    path[idx] = testBit(k, idx);
  }
  return path;
}

Bytes siblings2Bytes(Siblings siblings) {
  final siblingBytes = Uint8List(HASH_BYTES_LENGTH * siblings.length);

  for (final (idx, val) in siblings.indexed) {
    final start = idx * HASH_BYTES_LENGTH;
    final end = (idx + 1) * HASH_BYTES_LENGTH;
    siblingBytes.setRange(start, end, val.value);
  }

  return siblingBytes;
}
