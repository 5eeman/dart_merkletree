import 'dart:typed_data';

import 'elem_bytes.dart' show ElemBytes;
import '../../constants/constants.dart'
    show DATA_LEN, DATA_LEN_BYTES, ELEM_BYTES_LEN;
import '../utils/utils.dart' show bytesEqual;
import '../../types/types.dart' show Bytes;

class Data {
  late List<ElemBytes> _value;

  Data() : _value = List.filled(DATA_LEN, ElemBytes());

  List<ElemBytes> get value {
    return _value;
  }

  set value(List<ElemBytes> v) {
    if (v.length != DATA_LEN) {
      throw 'expected bytes length to be $DATA_LEN, got ${v.length}';
    }
    _value = v;
  }

  Bytes bytes() {
    final b = Uint8List(DATA_LEN * ELEM_BYTES_LEN);

    for (var outerIdx = 0; outerIdx < DATA_LEN; outerIdx += 1) {
      final element = value[outerIdx].value;

      for (final (innerIndex, val) in element.indexed) {
        b[outerIdx * ELEM_BYTES_LEN + innerIndex] = val;
      }
    }
    return b;
  }

  bool equal(Data d2) {
    return (bytesEqual(value[0].value, d2.value[0].value) &&
        bytesEqual(value[1].value, d2.value[1].value) &&
        bytesEqual(value[2].value, d2.value[2].value) &&
        bytesEqual(value[3].value, d2.value[3].value));
  }
}

Data newDataFromBytes(Bytes bytes) {
  if (bytes.length != DATA_LEN_BYTES) {
    throw Exception(
        'expected _bytes length to be $DATA_LEN_BYTES, got ${bytes.length}');
  }
  final d = Data();
  final arr = List.filled(DATA_LEN_BYTES, ElemBytes());

  for (var i = 0; i < DATA_LEN; i += 1) {
    final tmp = ElemBytes();
    tmp.value = bytes.sublist(i * ELEM_BYTES_LEN, (i + 1) * DATA_LEN_BYTES);
    arr[i] = tmp;
  }

  d.value = arr;
  return d;
}
