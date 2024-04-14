import '../../types/merkletree.dart'
    show ICircomProcessorProof, ICircomVerifierProof, Siblings;
import '../../types/hash.dart' show IHash;
import '../hash/hash.dart' show ZERO_HASH;

class CircomVerifierProof implements ICircomVerifierProof {
  IHash root;
  Siblings siblings;
  IHash oldKey;
  IHash oldValue;
  bool isOld0;
  IHash key;
  IHash value;

  // 0: inclusion, 1: non inclusion
  int fnc;

  CircomVerifierProof({
    this.root = ZERO_HASH,
    this.siblings = const [],
    this.oldKey = ZERO_HASH,
    this.oldValue = ZERO_HASH,
    this.isOld0 = false,
    this.key = ZERO_HASH,
    this.value = ZERO_HASH,
    this.fnc = 0,
  });
}

class CircomProcessorProof implements ICircomProcessorProof {
  IHash oldRoot;
  IHash newRoot;
  Siblings siblings;
  IHash oldKey;
  IHash oldValue;
  IHash newKey;
  IHash newValue;
  bool isOld0;

  // 0: NOP, 1: Update, 2: Insert, 3: Delete
  int fnc;

  CircomProcessorProof({
    this.oldRoot = ZERO_HASH,
    this.newRoot = ZERO_HASH,
    this.siblings = const [],
    this.oldKey = ZERO_HASH,
    this.oldValue = ZERO_HASH,
    this.newKey = ZERO_HASH,
    this.newValue = ZERO_HASH,
    this.isOld0 = false,
    this.fnc = 0,
  });
}
