// in Memory Database implementation

import 'dart:typed_data';

import '../../types/types.dart' show IHash, Bytes, Node, ITreeStorage;
import '../hash/hash.dart' show ZERO_HASH;

class InMemoryDB implements ITreeStorage {
  Bytes prefix;
  final Map<String, Node> _kvMap;
  IHash _currentRoot;

  InMemoryDB(this.prefix)
      : _kvMap = {},
        _currentRoot = ZERO_HASH;

  @override
  Future<Node?> get(Bytes k) async {
    final kBytes = Uint8List.fromList([...prefix, ...k]);
    final val = _kvMap.containsKey(kBytes.toString())
        ? _kvMap[kBytes.toString()]
        : null;
    return val;
  }

  @override
  Future<void> put(Bytes k, Node n) async {
    final kBytes = Uint8List.fromList([...prefix, ...k]);
    _kvMap[kBytes.toString()] = n;
  }

  @override
  Future<IHash> getRoot() async {
    return _currentRoot;
  }

  @override
  Future<void> setRoot(IHash r) async {
    _currentRoot = r;
  }
}
