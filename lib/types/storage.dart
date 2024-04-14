import "hash.dart";
import "node.dart";
import "bytes.dart";

abstract interface class ITreeStorage {
  Future<Node?> get(Bytes k);

  Future<void> put(Bytes k, Node n);

  Future<IHash> getRoot();

  Future<void> setRoot(IHash r);
}

typedef KV = (Bytes k, Bytes v);

typedef KVMap = Map<Bytes, KV>;
