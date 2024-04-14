import '../../types/types.dart' show IHash, Bytes, Node, NodeType;
import '../hash/hash.dart' show Hash, ZERO_HASH, hashElems;
import '../../constants/constants.dart'
    show
        EMPTY_NODE_STRING,
        EMPTY_NODE_VALUE,
        NODE_TYPE_EMPTY,
        NODE_TYPE_LEAF,
        NODE_TYPE_MIDDLE;
import '../utils/node.dart' show leafKey, nodeValue;

class NodeLeaf implements Node {
  @override
  NodeType type;
  List<Hash> entry;

  // cache used to avoid recalculating key
  Hash _key;

  NodeLeaf(Hash k, Hash v)
      : type = NODE_TYPE_LEAF,
        entry = [k, v],
        _key = ZERO_HASH;

  @override
  Future<Hash> getKey() async {
    if (_key == ZERO_HASH) {
      _key = await leafKey(entry[0], entry[1]);
      return _key;
    }
    return _key;
  }

  @override
  Bytes get value {
    return nodeValue(type, entry[0], entry[1]);
  }

  @override
  String get string {
    return 'Leaf I:${entry[0]} D:${entry[1]}';
  }
}

class NodeMiddle implements Node {
  @override
  final NodeType type;
  final IHash childL;

  final IHash childR;

  final IHash _key;

  NodeMiddle(IHash cL, IHash cR)
      : type = NODE_TYPE_MIDDLE,
        childL = cL,
        childR = cR,
        _key = ZERO_HASH;

  @override
  Future<IHash> getKey() async {
    if (_key == ZERO_HASH) {
      return hashElems([childL.bigint(), childR.bigint()]);
    }
    return _key;
  }

  @override
  Bytes get value {
    return nodeValue(type, childL, childR);
  }

  @override
  String get string {
    return 'Middle L:$childL R:$childR';
  }
}

class NodeEmpty implements Node {
  @override
  final NodeType type;

  NodeEmpty() : type = NODE_TYPE_EMPTY;

  @override
  Future<IHash> getKey() async {
    return ZERO_HASH;
  }

  @override
  Bytes get value {
    return EMPTY_NODE_VALUE;
  }

  @override
  String get string {
    return EMPTY_NODE_STRING;
  }
}
