import "bytes.dart";
import 'hash.dart';

typedef NodeType = int;

abstract interface class Node {
  NodeType get type;

  Future<IHash> getKey();

  Bytes get value;

  String get string;
}
