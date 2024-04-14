import 'dart:async';

import '../errors/db.dart';
import '../errors/merkletree.dart';
import '../hash/hash.dart' show Hash, ZERO_HASH, circomSiblingsFromSiblings;
import '../../types/types.dart'
    show IHash, Node, ITreeStorage, NodeAux, Siblings;
import '../../constants/constants.dart'
    show NODE_TYPE_EMPTY, NODE_TYPE_LEAF, NODE_TYPE_MIDDLE;
import '../node/node.dart' show NodeEmpty, NodeLeaf, NodeMiddle;
import '../utils/utils.dart' show bytesEqual, getPath, checkBigIntInField;
import 'circom.dart';
import 'proof.dart' show Proof;
import '../entry/entry.dart' show Entry, checkEntryInField;

class Merkletree {
  ITreeStorage _db;
  IHash? _root;
  bool _writable;
  int _maxLevel;

  Merkletree(ITreeStorage _db, bool _writable, int _maxLevels)
      : _db = _db,
        _writable = _writable,
        _maxLevel = _maxLevels;

  Future<IHash> root() async {
    final root = _root;
    if (root == null) {
      final newRoot = await _db.getRoot();
      _root = newRoot;
      return newRoot;
    }
    return root;
  }

  int get maxLevels {
    return _maxLevel;
  }

  Future<void> add(BigInt k, BigInt v) async {
    if (!_writable) {
      throw ErrNotWritable;
    }

    _root = await root();
    final kHash = Hash.fromBigInt(k);
    final vHash = Hash.fromBigInt(v);

    final newNodeLeaf = NodeLeaf(kHash, vHash);
    final path = getPath(maxLevels, kHash.value);

    final newRootKey = await addLeaf(newNodeLeaf, _root!, 0, path);
    _root = newRootKey;
    await _db.setRoot(_root!);
  }

  Future<IHash> updateNode(Node n) async {
    if (!_writable) {
      throw ErrNotWritable;
    }

    if (n.type == NODE_TYPE_EMPTY) {
      return await n.getKey();
    }

    final k = await n.getKey();

    await _db.put(k.value, n);
    return k;
  }

  Future<IHash> addNode(Node n) async {
    if (!_writable) {
      throw ErrNotWritable;
    }
    if (n.type == NODE_TYPE_EMPTY) {
      return await n.getKey();
    }

    final k = await n.getKey();
    // if (typeof this._db.get(k.value) !== 'undefined') {
    //   throw ErrNodeKeyAlreadyExists;
    // }

    await _db.put(k.value, n);
    return k;
  }

  Future<void> addEntry(Entry e) async {
    if (!_writable) {
      throw ErrNotWritable;
    }

    if (!checkEntryInField(e)) {
      throw 'elements not inside the finite field over r';
    }
    _root = await _db.getRoot();
    final hIndex = await e.hIndex();
    final hValue = await e.hValue();

    final newNodeLeaf = NodeLeaf(hIndex, hValue);
    final path = getPath(maxLevels, hIndex.value);

    final newRootKey = await addLeaf(newNodeLeaf, _root!, 0, path);
    _root = newRootKey;
    await _db.setRoot(_root!);
  }

  Future<IHash> pushLeaf(
    Node newLeaf,
    Node oldLeaf,
    int lvl,
    List<bool> pathNewLeaf,
    List<bool> pathOldLeaf,
  ) async {
    if (lvl > _maxLevel - 2) {
      throw ErrReachedMaxLevel;
    }

    NodeMiddle newNodeMiddle;

    if (pathNewLeaf[lvl] == pathOldLeaf[lvl]) {
      final nextKey =
          await pushLeaf(newLeaf, oldLeaf, lvl + 1, pathNewLeaf, pathOldLeaf);
      if (pathNewLeaf[lvl]) {
        newNodeMiddle = NodeMiddle(const Hash.zero(), nextKey);
      } else {
        newNodeMiddle = NodeMiddle(nextKey, const Hash.zero());
      }

      return await addNode(newNodeMiddle);
    }

    final oldLeafKey = await oldLeaf.getKey();
    final newLeafKey = await newLeaf.getKey();

    if (pathNewLeaf[lvl]) {
      newNodeMiddle = NodeMiddle(oldLeafKey, newLeafKey);
    } else {
      newNodeMiddle = NodeMiddle(newLeafKey, oldLeafKey);
    }

    await addNode(newLeaf);
    return await addNode(newNodeMiddle);
  }

  Future<IHash> addLeaf(
      NodeLeaf newLeaf, IHash key, int lvl, List<bool> path) async {
    if (lvl > _maxLevel - 1) {
      throw ErrReachedMaxLevel;
    }

    final n = await getNode(key);
    if (n == null) {
      throw ErrNotFound;
    }

    switch (n.type) {
      case NODE_TYPE_EMPTY:
        return addNode(newLeaf);
      case NODE_TYPE_LEAF:
        final nKey = (n as NodeLeaf).entry[0];
        final newLeafKey = newLeaf.entry[0];

        if (bytesEqual(nKey.value, newLeafKey.value)) {
          throw ErrEntryIndexAlreadyExists;
        }

        final pathOldLeaf = getPath(maxLevels, nKey.value);
        return pushLeaf(newLeaf, n, lvl, path, pathOldLeaf);
      case NODE_TYPE_MIDDLE:
        NodeMiddle newNodeMiddle;

        if (path[lvl]) {
          final nextKey =
              await addLeaf(newLeaf, (n as NodeMiddle).childR, lvl + 1, path);
          newNodeMiddle = NodeMiddle((n).childL, nextKey);
        } else {
          final nextKey =
              await addLeaf(newLeaf, (n as NodeMiddle).childL, lvl + 1, path);
          newNodeMiddle = NodeMiddle(nextKey, (n).childR);
        }

        return addNode(newNodeMiddle);
      default:
        throw ErrInvalidNodeFound;
    }
  }

  Future<(BigInt key, BigInt value, Siblings siblings)> get(BigInt k) async {
    final kHash = Hash.fromBigInt(k);
    final path = getPath(maxLevels, kHash.value);

    var nextKey = await root();
    final Siblings siblings = [];

    for (var i = 0; i < maxLevels; i++) {
      final n = await getNode(nextKey);
      if (n == null) {
        throw ErrKeyNotFound;
      }

      switch (n.type) {
        case NODE_TYPE_EMPTY:
          return (BigInt.zero, BigInt.zero, siblings);
        case NODE_TYPE_LEAF:
          // if (bytesEqual(kHash.value, (n as NodeLeaf).entry[0].value)) {
          //   return {
          //     key: (n as NodeLeaf).entry[0].BigInt(),
          //     value: (n as NodeLeaf).entry[1].BigInt(),
          //     siblings,
          //   };
          // }
          return (
            (n as NodeLeaf).entry[0].bigint(),
            (n).entry[1].bigint(),
            siblings
          );
        case NODE_TYPE_MIDDLE:
          if (path[i]) {
            nextKey = (n as NodeMiddle).childR;
            siblings.add((n).childL);
          } else {
            nextKey = (n as NodeMiddle).childL;
            siblings.add((n).childR);
          }
          break;
        default:
          throw ErrInvalidNodeFound;
      }
    }

    throw ErrReachedMaxLevel;
  }

  Future<CircomProcessorProof> update(BigInt k, BigInt v) async {
    if (!_writable) {
      throw ErrNotWritable;
    }

    if (!checkBigIntInField(k)) {
      throw 'key not inside the finite field';
    }
    if (!checkBigIntInField(v)) {
      throw 'key not inside the finite field';
    }

    final kHash = Hash.fromBigInt(k);
    final vHash = Hash.fromBigInt(v);

    final path = getPath(maxLevels, kHash.value);

    final cp = CircomProcessorProof();

    cp.fnc = 1;
    cp.oldRoot = await root();
    cp.oldKey = kHash;
    cp.newKey = kHash;
    cp.newValue = vHash;

    var nextKey = await root();
    final Siblings siblings = [];

    for (var i = 0; i < maxLevels; i += 1) {
      final n = await getNode(nextKey);
      if (n == null) {
        throw ErrNotFound;
      }

      switch (n.type) {
        case NODE_TYPE_EMPTY:
          throw ErrKeyNotFound;
        case NODE_TYPE_LEAF:
          if (bytesEqual(kHash.value, (n as NodeLeaf).entry[0].value)) {
            cp.oldValue = (n).entry[1];
            cp.siblings = circomSiblingsFromSiblings([...siblings], maxLevels);
            final newNodeLeaf = NodeLeaf(kHash, vHash);
            await updateNode(newNodeLeaf);

            final newRootKey =
                await recalculatePathUntilRoot(path, newNodeLeaf, siblings);

            _root = newRootKey;
            await _db.setRoot(newRootKey);
            cp.newRoot = newRootKey;
            return cp;
          }
          break;
        case NODE_TYPE_MIDDLE:
          if (path[i]) {
            nextKey = (n as NodeMiddle).childR;
            siblings.add((n).childL);
          } else {
            nextKey = (n as NodeMiddle).childL;
            siblings.add((n).childR);
          }
          break;
        default:
          throw ErrInvalidNodeFound;
      }
    }

    throw ErrKeyNotFound;
  }

  Future<Node?> getNode(IHash k) async {
    if (bytesEqual(k.value, ZERO_HASH.value)) {
      return NodeEmpty();
    }
    return await _db.get(k.value);
  }

  Future<IHash> recalculatePathUntilRoot(
    List<bool> path,
    Node node,
    Siblings siblings,
  ) async {
    for (var i = siblings.length - 1; i >= 0; i -= 1) {
      final nodeKey = await node.getKey();
      if (path[i]) {
        node = NodeMiddle(siblings[i], nodeKey);
      } else {
        node = NodeMiddle(nodeKey, siblings[i]);
      }
      await addNode(node);
    }

    final nodeKey = await node.getKey();
    return nodeKey;
  }

  // Delete removes the specified Key from the MerkleTree and updates the path
  // from the deleted key to the Root with the new values.  This method removes
  // the key from the MerkleTree, but does not remove the old nodes from the
  // key-value database; this means that if the tree is accessed by an old Root
  // where the key was not deleted yet, the key will still exist. If is desired
  // to remove the key-values from the database that are not under the current
  // Root, an option could be to dump all the leaves (using mt.DumpLeafs) and
  // import them in a new MerkleTree in a new database (using
  // mt.ImportDumpedLeafs), but this will loose all the Root history of the
  // MerkleTree
  Future<void> delete(BigInt k) async {
    if (!_writable) {
      throw ErrNotWritable;
    }

    final kHash = Hash.fromBigInt(k);
    final path = getPath(maxLevels, kHash.value);

    var nextKey = _root;
    final Siblings siblings = [];

    for (var i = 0; i < _maxLevel; i += 1) {
      final n = await getNode(nextKey!);
      if (n == null) {
        throw ErrNotFound;
      }
      switch (n.type) {
        case NODE_TYPE_EMPTY:
          throw ErrKeyNotFound;
        case NODE_TYPE_LEAF:
          if (bytesEqual(kHash.value, (n as NodeLeaf).entry[0].value)) {
            await rmAndUpload(path, kHash, siblings);
            return;
          }
          throw ErrKeyNotFound;
        case NODE_TYPE_MIDDLE:
          if (path[i]) {
            nextKey = (n as NodeMiddle).childR;
            siblings.add((n).childL);
          } else {
            nextKey = (n as NodeMiddle).childL;
            siblings.add((n).childR);
          }
          break;
        default:
          throw ErrInvalidNodeFound;
      }
    }

    throw ErrKeyNotFound;
  }

  Future<void> rmAndUpload(
      List<bool> path, Hash kHash, Siblings siblings) async {
    if (siblings.isEmpty) {
      _root = ZERO_HASH;
      await _db.setRoot(_root!);
      return;
    }

    final toUpload = siblings[siblings.length - 1];
    if (siblings.length < 2) {
      _root = siblings[0];
      await _db.setRoot(_root!);
    }

    for (var i = siblings.length - 2; i >= 0; i -= 1) {
      if (!bytesEqual(siblings[i].value, ZERO_HASH.value)) {
        Node newNode;
        if (path[i]) {
          newNode = NodeMiddle(siblings[i], toUpload);
        } else {
          newNode = NodeMiddle(toUpload, siblings[i]);
        }
        await addNode(newNode);

        final newRootKey = await recalculatePathUntilRoot(
            path, newNode, siblings.sublist(0, i));

        _root = newRootKey;
        await _db.setRoot(_root!);
        break;
      }

      if (i == 0) {
        _root = toUpload;
        await _db.setRoot(_root!);
        break;
      }
    }
  }

  Future<void> recWalk(IHash key, Future<void> Function(Node) f) async {
    final n = await getNode(key);
    if (n == null) {
      throw ErrNotFound;
    }

    switch (n.type) {
      case NODE_TYPE_EMPTY:
        await f(n);
        break;
      case NODE_TYPE_LEAF:
        await f(n);
        break;
      case NODE_TYPE_MIDDLE:
        await f(n);
        await recWalk((n as NodeMiddle).childL, f);
        await recWalk((n).childR, f);
        break;
      default:
        throw ErrInvalidNodeFound;
    }
  }

  Future<void> walk(IHash rootKey, Future<void> Function(Node) f) async {
    if (bytesEqual(rootKey.value, ZERO_HASH.value)) {
      rootKey = await root();
    }
    await recWalk(rootKey, f);
  }

  Future<CircomVerifierProof> generateCircomVerifierProof(
      BigInt k, IHash rootKey) async {
    final cp = await generateSCVerifierProof(k, rootKey);
    cp.siblings = circomSiblingsFromSiblings(cp.siblings, maxLevels);
    return cp;
  }

  Future<CircomVerifierProof> generateSCVerifierProof(
      BigInt k, IHash rootKey) async {
    if (bytesEqual(rootKey.value, ZERO_HASH.value)) {
      rootKey = await root();
    }

    final (proof, value) = await generateProof(k, rootKey);
    final cp = CircomVerifierProof();
    cp.root = rootKey;
    cp.siblings = proof.allSiblings();
    final proofAuxNode = proof.nodeAux;
    if (proofAuxNode != null) {
      cp.oldKey = proofAuxNode.key;
      cp.oldValue = proofAuxNode.value;
    } else {
      cp.oldKey = ZERO_HASH;
      cp.oldValue = ZERO_HASH;
    }
    cp.key = Hash.fromBigInt(k);
    cp.value = Hash.fromBigInt(value);

    if (proof.existence) {
      cp.fnc = 0;
    } else {
      cp.fnc = 1;
    }

    return cp;
  }

  Future<(Proof proof, BigInt value)> generateProof(
    BigInt k,
    IHash? rootKey,
  ) async {
    IHash siblingKey;

    final kHash = Hash.fromBigInt(k);
    final path = getPath(maxLevels, kHash.value);
    rootKey ??= await root();
    var nextKey = rootKey;

    var depth = 0;
    var existence = false;
    final Siblings siblings = [];
    NodeAux? nodeAux;

    for (depth = 0; depth < maxLevels; depth += 1) {
      final n = await getNode(nextKey);

      if (n == null) {
        throw ErrNotFound;
      }

      switch (n.type) {
        case NODE_TYPE_EMPTY:
          return (
            Proof(
              existence: existence,
              nodeAux: nodeAux,
              siblings: siblings,
            ),
            BigInt.zero,
          );
        case NODE_TYPE_LEAF:
          if (bytesEqual(kHash.value, (n as NodeLeaf).entry[0].value)) {
            existence = true;

            return (
              Proof(
                existence: existence,
                nodeAux: nodeAux,
                siblings: siblings,
              ),
              n.entry[1].bigint(),
            );
          }
          nodeAux = NodeAux(
            key: n.entry[0],
            value: n.entry[1],
          );
          return (
            Proof(
              existence: existence,
              nodeAux: nodeAux,
              siblings: siblings,
            ),
            n.entry[1].bigint(),
          );
        case NODE_TYPE_MIDDLE:
          n as NodeMiddle;
          if (path[depth]) {
            nextKey = n.childR;
            siblingKey = n.childL;
          } else {
            nextKey = n.childL;
            siblingKey = n.childR;
          }
          break;
        default:
          throw ErrInvalidNodeFound;
      }
      siblings.add(siblingKey);
    }
    throw ErrKeyNotFound;
  }

  Future<CircomProcessorProof> addAndGetCircomProof(BigInt k, BigInt v) async {
    final cp = CircomProcessorProof();
    cp.fnc = 2;
    cp.oldRoot = await root();
    var key = BigInt.zero;
    var value = BigInt.zero;
    Siblings siblings = [];
    try {
      final res = await get(k);
      key = res.$1;
      value = res.$2;
      siblings = res.$3;
    } catch (err) {
      if (err != ErrKeyNotFound) {
        rethrow;
      }
    }

    cp.oldKey = Hash.fromBigInt(key);
    cp.oldValue = Hash.fromBigInt(value);

    if (bytesEqual(cp.oldKey.value, ZERO_HASH.value)) {
      cp.isOld0 = true;
    }

    cp.siblings = circomSiblingsFromSiblings(siblings, maxLevels);
    await add(k, v);

    cp.newKey = Hash.fromBigInt(k);
    cp.newValue = Hash.fromBigInt(v);
    cp.newRoot = await root();

    return cp;
  }

  // NOTE: for now it only prints to console, will be updated in future
  Future<void> graphViz(IHash rootKey, void Function(String) output) async {
    var cnt = 0;

    await walk(rootKey, (n) async {
      final k = await n.getKey();
      List<String> lr;
      String emptyNodes;

      switch (n.type) {
        case NODE_TYPE_EMPTY:
          break;
        case NODE_TYPE_LEAF:
          output('"${k.string()}" [style=filled]');
          break;
        case NODE_TYPE_MIDDLE:
          lr = [(n as NodeMiddle).childL.string(), (n).childR.string()];
          emptyNodes = '';

          for (final (i, s) in lr.indexed) {
            if (s == '0') {
              lr[i] = 'empty$cnt';
              emptyNodes += '"${lr[i]}" [style=dashed,label=0];\n';
              cnt += 1;
            }
          }

          output('"${k.string()}" -> {"${lr[1]}"}');
          output(emptyNodes);
          break;
        default:
          break;
      }
    });

    output('}\n');
  }

  Future<void> printGraphViz(IHash rootKey, void Function(String) output) async {
    if (bytesEqual(rootKey.value, ZERO_HASH.value)) {
      rootKey = await root();
    }
    output(
        '--------\nGraphViz of the MerkleTree with RootKey ${rootKey.bigint().toRadixString(10)}\n');
    await graphViz(ZERO_HASH, output);
    output(
        'End of GraphViz of the MerkleTree with RootKey ${rootKey.bigint().toRadixString(10)}\n--------\n');
  }
}
