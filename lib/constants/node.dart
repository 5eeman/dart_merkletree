import 'dart:typed_data';

import '../types/node.dart';

const NodeType NODE_TYPE_MIDDLE = 0;
// Leaf node.ts with a key and a value
const NodeType NODE_TYPE_LEAF = 1;
// empty node.ts
const NodeType NODE_TYPE_EMPTY = 2;

const NODE_VALUE_BYTE_ARR_LENGTH = 65;

final EMPTY_NODE_VALUE = Uint8List(NODE_VALUE_BYTE_ARR_LENGTH);

const EMPTY_NODE_STRING = 'empty';
