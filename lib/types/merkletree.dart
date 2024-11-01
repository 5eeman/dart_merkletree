import 'hash.dart';

typedef Path = List<bool>;
typedef Siblings = List<IHash>;

class NodeAux {
  final IHash key;
  final IHash value;

  NodeAux({
    required this.key,
    required this.value,
  });

  Map<String, dynamic> toJson() {
    return {
      'key': key.toString(),
      'value': value.toString(),
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NodeAux &&
          runtimeType == other.runtimeType &&
          key == other.key &&
          value == other.value;

  @override
  int get hashCode => key.hashCode ^ value.hashCode;
}

// CircomProcessorProof defines the ProcessorProof compatible with circom. Is
// the data of the proof between the transition from one state to another.
interface class ICircomProcessorProof {
  late IHash oldRoot;
  late IHash newRoot;
  late Siblings siblings;
  late IHash oldKey;
  late IHash oldValue;
  late IHash newKey;
  late IHash newValue;
  late bool isOld0;

  // 0: NOP, 1: Update, 2: Insert, 3: Delete
  late int fnc;
}

// CircomVerifierProof defines the VerifierProof compatible with circom. Is the
// data of the proof that a certain leaf exists in the MerkleTree.
interface class ICircomVerifierProof {
  late IHash root;
  late Siblings siblings;
  late IHash oldKey;
  late IHash oldValue;
  late bool isOld0;
  late IHash key;
  late IHash value;

  // 0: inclusion, 1: non inclusion
  late int fnc;
}
