import 'data.dart';
import '../hash/hash.dart' show Hash, ZERO_HASH, hashElems;
import '../utils/utils.dart' show checkBigIntInField;
import 'elem_bytes.dart';

class Entry {
  final Data _data;
  final Hash _hIndex;
  final Hash _hValue;

  Entry(Data? data)
      : _data = data ?? Data(),
        _hIndex = ZERO_HASH,
        _hValue = ZERO_HASH;

  Data get data {
    return _data;
  }

  List<ElemBytes> get index {
    return _data.value.sublist(0, 4);
  }

  List<ElemBytes> get value {
    return _data.value.sublist(4, 8);
  }

  Future<Hash> hIndex() async {
    if (_hIndex == ZERO_HASH) {
      return hashElems(elemBytesToBigInts(index));
    }
    return _hIndex;
  }

  Future<Hash> hValue() async {
    if (_hValue == ZERO_HASH) {
      return hashElems(elemBytesToBigInts(value));
    }
    return _hValue;
  }

  Future<(Hash hi, Hash hv)> hiHv() async {
    return (() async {
      final hi = await hIndex();
      final hv = await hValue();
      return (hi, hv);
    })();
  }

  List<ElemBytes> bytes() {
    return _data.value;
  }

  Entry clone() {
    return Entry(_data);
  }

  @override
  bool operator ==(Object other) {
    return other is Entry && _data == other.data;
  }

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() {
    return 'Entry{data: $data}';
  }
}

List<BigInt> elemBytesToBigInts(List<ElemBytes> es) {
  final bigInts = es.map((e) {
    return e.bigInt();
  }).toList();

  return bigInts;
}

bool checkEntryInField(Entry e) {
  final bigInts = elemBytesToBigInts(e.data.value);
  var flag = true;

  for (var b in bigInts) {
    if (!checkBigIntInField(b)) {
      flag = false;
    }
  }

  return flag;
}
