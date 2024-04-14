import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../types/merkletree.dart' show NodeAux, Siblings;
import '../../constants/constants.dart'
    show ELEM_BYTES_LEN, NOT_EMPTIES_LEN, PROOF_FLAG_LEN;
import '../utils/utils.dart'
    show bytesEqual, getPath, setBitBigEndian, siblings2Bytes, testBitBigEndian;
import '../hash/hash.dart' show Hash, ZERO_HASH;
import '../node/node.dart' show NodeMiddle;
import '../utils/node.dart' show leafKey;
import '../errors/proof.dart' show ErrNodeAuxNonExistAgainstHIndex;
import '../../types/types.dart' show Bytes, IHash;

abstract class ProofJSON {
  bool get existence;

  List<String> get siblings;

  NodeAuxJSON? get nodeAux;
}

abstract class NodeAuxJSON {
  String get key;

  String get value;
}

class Proof {
  bool existence;
  int _depth;

  // notempties is a bitmap of non-empty siblings found in siblings
  late Bytes _notEmpties;
  late Siblings _siblings;
  NodeAux? nodeAux;

  Proof({
    required Siblings siblings,
    this.nodeAux,
    this.existence = false,
  }) : _depth = siblings.length {
    final (newSiblings, notEmpties) = reduceSiblings(siblings);
    _siblings = newSiblings;
    _notEmpties = notEmpties;
  }

  Bytes get bytes {
    var bytesLen =
        PROOF_FLAG_LEN + _notEmpties.length + ELEM_BYTES_LEN * _siblings.length;

    if (this.nodeAux != null) {
      bytesLen += 2 * ELEM_BYTES_LEN;
    }

    final bytes = Uint8List(bytesLen);

    if (!existence) {
      bytes[0] |= 1;
    }
    bytes[1] = _depth;
    var offset = PROOF_FLAG_LEN;
    bytes.setRange(offset, offset + _notEmpties.length, _notEmpties);

    offset += _notEmpties.length;
    final siblingBytes = siblings2Bytes(_siblings);
    bytes.setRange(offset, offset + siblingBytes.length, siblingBytes);

    final nodeAux = this.nodeAux;
    if (nodeAux != null) {
      bytes[0] |= 2;

      offset = bytes.length - 2 * ELEM_BYTES_LEN;
      bytes.setRange(
          offset, offset + nodeAux.key.value.length, nodeAux.key.value);

      offset = bytes.length - 1 * ELEM_BYTES_LEN;
      bytes.setRange(
          offset, offset + nodeAux.value.value.length, nodeAux.value.value);
    }
    return bytes;
  }

  Map<String, dynamic> toJson() {
    final nodeAux = this.nodeAux;
    return {
      "existence": existence,
      "siblings": allSiblings().map((s) => s.string()).toList(),
      "nodeAux": nodeAux != null
          ? {
              "key": nodeAux.key.string(),
              "value": nodeAux.value.string(),
            }
          : null,
    };
  }

  factory Proof.fromJson(Map<String, dynamic> obj) {
    NodeAux? nodeAux;
    final objNodeAux = obj["nodeAux"];
    if (objNodeAux != null) {
      nodeAux = NodeAux(
        key: Hash.fromString(objNodeAux["key"]),
        value: Hash.fromString(objNodeAux["value"]),
      );
    }
    final existence = obj["existence"];

    final Siblings siblings =
        (obj["siblings"] as List).map((s) => Hash.fromString(s)).toList();

    return Proof(
      siblings: siblings,
      nodeAux: nodeAux,
      existence: existence,
    );
  }

  Siblings allSiblings() {
    return Proof.buildAllSiblings(_depth, _notEmpties, _siblings);
  }

  static Siblings buildAllSiblings(
    int depth,
    Uint8List notEmpties,
    List<IHash> siblings,
  ) {
    var sibIdx = 0;
    final Siblings allSiblings = [];

    for (var i = 0; i < depth; i += 1) {
      if (testBitBigEndian(notEmpties, i)) {
        allSiblings.add(siblings[sibIdx]);
        sibIdx += 1;
      } else {
        allSiblings.add(ZERO_HASH);
      }
    }
    return allSiblings;
  }
}

/**
 * @deprecated The method should not be used and will be removed in the next major version,
 * please use proof.allSiblings instead
 */
Siblings siblignsFroomProof(Proof proof) {
  return proof.allSiblings();
}

Future<bool> verifyProof(
  IHash rootKey,
  Proof proof,
  BigInt k,
  BigInt v,
) async {
  try {
    final rFromProof = await rootFromProof(proof, k, v);
    return bytesEqual(rootKey.value, rFromProof.value);
  } catch (err) {
    if (err == ErrNodeAuxNonExistAgainstHIndex) {
      return false;
    }
    rethrow;
  }
}

Future<IHash> rootFromProof(Proof proof, BigInt k, BigInt v) async {
  final kHash = Hash.fromBigInt(k);
  final vHash = Hash.fromBigInt(v);
  IHash midKey;

  if (proof.existence) {
    midKey = await leafKey(kHash, vHash);
  } else {
    final proofNodeAux = proof.nodeAux;
    if (proofNodeAux == null) {
      midKey = ZERO_HASH;
    } else {
      if (bytesEqual(kHash.value, proofNodeAux.key.value)) {
        throw ErrNodeAuxNonExistAgainstHIndex;
      }
      midKey = await leafKey(proofNodeAux.key, proofNodeAux.value);
    }
  }

  final siblings = proof.allSiblings();

  final path = getPath(siblings.length, kHash.value);

  for (var i = siblings.length - 1; i >= 0; i -= 1) {
    if (path[i]) {
      midKey = await NodeMiddle(siblings[i], midKey).getKey();
    } else {
      midKey = await NodeMiddle(midKey, siblings[i]).getKey();
    }
  }

  return midKey;
}

(Siblings siblings, Uint8List notEmpties) reduceSiblings(Siblings? siblings) {
  final Siblings reducedSiblings = [];
  final notEmpties = Uint8List(NOT_EMPTIES_LEN);

  if (siblings == null) {
    return (reducedSiblings, notEmpties);
  }
  for (var i = 0; i < siblings.length; i++) {
    final sibling = siblings[i];
    // TODO(moria): Copy pasted from JS, check if this is correct and necessary
    if (sibling.string() != ZERO_HASH.string()) {
      setBitBigEndian(notEmpties, i);
      reducedSiblings.add(sibling);
    }
  }
  return (reducedSiblings, notEmpties);
}
