import '../../constants/constants.dart' show FIELD_SIZE;

bool checkBigIntInField(BigInt bigNum) {
  return bigNum < FIELD_SIZE;
}
