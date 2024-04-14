// import { UseStore, createStore, clear } from 'idb-keyval';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dart_merkletree/dart_merkletree.dart';
import 'package:dart_merkletree/lib/errors/merkletree.dart';

import 'package:flutter_test/flutter_test.dart';

// import 'mock-local-storage';
// import 'fake-indexeddb/auto';

enum TreeStorageType {
  localStorageDB('localStorage'),
  inMemoryDB('memoryStorage'),
  indexedDB('indexedDB');

  final String name;

  const TreeStorageType(this.name);
}

final List<TreeStorageType> storages = [
  TreeStorageType.inMemoryDB,
  // TreeStorageType.LocalStorageDB,
  // TreeStorageType.IndexedDB,
];

void main() {
  for (var index = 0; index < storages.length; index++) {
    group('full test of the SMT library: ${storages[index].toString()}', () {
      // final UseStore store = createStore(
      //     '${IndexedDBStorage.storageName}-db',
      //     IndexedDBStorage.storageName
      // );

      setUp(() async {
        // localStorage.clear();
        // await clear(store);
      });

      getTreeStorage({String prefix = ''}) {
        /*if (storages[index] == TreeStorageType.LocalStorageDB) {
          return LocalStorageDB(str2Bytes(prefix));
        } else if (storages[index] == TreeStorageType.IndexedDB) {
          return IndexedDBStorage(str2Bytes(prefix));
        } else */
        if (storages[index] == TreeStorageType.inMemoryDB) {
          return InMemoryDB(str2Bytes(prefix));
        }
        throw Exception('error: unknown storage type');
      }

      test(
          'checks that the implementation of the db.Storage interface behaves as expected',
          () async {
        final sto = getTreeStorage();

        final bytes = Uint8List(HASH_BYTES_LENGTH);
        bytes[0] = 1;
        final v = Hash(bytes);

        final node = NodeMiddle(v, v);
        final k = await node.getKey();
        await sto.put(k.value, node);
        final val = await sto.get(k.value);

        expect(val, isNotNull);
        expect((val as NodeMiddle).childL.hex(), equals(v.hex()));
        expect((val).childR.hex(), equals(v.hex()));
      });

      test('test new merkle tree', () async {
        final sto = getTreeStorage();
        final mt = Merkletree(sto, true, 10);
        expect((await mt.root()).string(), equals('0'));

        await mt.add(BigInt.one, BigInt.parse('2'));
        expect(
            (await mt.root()).bigint().toRadixString(10),
            equals(
                '13578938674299138072471463694055224830892726234048532520316387704878000008795'));

        await mt.add(BigInt.parse('33'), BigInt.parse('44'));
        expect(
            (await mt.root()).bigint().toRadixString(10),
            equals(
                '5412393676474193513566895793055462193090331607895808993925969873307089394741'));

        await mt.add(BigInt.parse('1234'), BigInt.parse('9876'));
        expect(
          (await mt.root()).bigint().toRadixString(10),
          equals(
              '14204494359367183802864593755198662203838502594566452929175967972147978322084'),
        );

        expect((await sto.getRoot()).bigint().toString(),
            equals((await mt.root()).bigint().toString()));

        final (proof, value) = await mt.generateProof(BigInt.parse('33'), null);
        expect(value.toString(), equals('44'));

        expect(
            await verifyProof(
                await mt.root(), proof, BigInt.parse('33'), BigInt.parse('44')),
            equals(true));

        expect(
            await verifyProof(
                await mt.root(), proof, BigInt.parse('33'), BigInt.parse('45')),
            equals(false));
      });

      test('test tree with one node', () async {
        final sto = getTreeStorage();
        final mt = Merkletree(sto, true, 10);
        expect(
            bytesEqual((await mt.root()).value, ZERO_HASH.value), equals(true));

        await mt.add(BigInt.parse('100'), BigInt.parse('200'));
        expect(
            (await mt.root()).bigint().toRadixString(10),
            equals(
                '798876344175601936808542466911896801961231313012372360729165540443724338832'));
        final inputs = [BigInt.parse('100'), BigInt.parse('200'), BigInt.one];
        final res = poseidon(inputs);
        expect((await mt.root()).bigint().toString(), equals(res.toString()));
      });

      test('test add and different order', () async {
        final sto1 = getTreeStorage(prefix: 'tree1');
        final sto2 = getTreeStorage(prefix: 'tree2');
        final mt1 = Merkletree(sto1, true, 140);
        final mt2 = Merkletree(sto2, true, 140);

        for (var i = 0; i < 16; i += 1) {
          final k = BigInt.from(i);
          final v = BigInt.parse('0');
          await mt1.add(k, v);
        }

        for (var i = 15; i >= 0; i -= 1) {
          final k = BigInt.from(i);
          final v = BigInt.zero;
          await mt2.add(k, v);
        }

        expect(
          (await mt1.root()).string(),
          equals((await mt2.root()).string()),
        );
        expect(
          (await mt1.root()).hex(),
          equals(
              '3b89100bec24da9275c87bc188740389e1d5accfc7d88ba5688d7fa96a00d82f'),
        );
      });

      test('test add repeated index', () async {
        final sto = getTreeStorage();
        final mt = Merkletree(sto, true, 140);

        final k = BigInt.parse('3');
        final v = BigInt.parse('12');
        await mt.add(k, v);

        try {
          await mt.add(k, v);
        } catch (err) {
          expect(err, ErrEntryIndexAlreadyExists);
        }
      });

      test('test get', () async {
        final sto = getTreeStorage();
        final mt = Merkletree(sto, true, 140);

        for (var i = 0; i < 16; i += 1) {
          final k = BigInt.from(i);
          final v = BigInt.from(i * 2);

          await mt.add(k, v);
        }
        final (k1, v1, _) = await mt.get(BigInt.parse('10'));
        expect(k1.toRadixString(10), equals('10'));
        expect(v1.toRadixString(10), equals('20'));

        final (k2, v2, _) = await mt.get(BigInt.parse('15'));
        expect(k2.toRadixString(10), equals('15'));
        expect(v2.toRadixString(10), equals('30'));

        try {
          await mt.get(BigInt.parse('16'));
        } catch (err) {
          expect(err, equals(ErrKeyNotFound));
        }
      });

      test('test update', () async {
        final sto = getTreeStorage();
        final mt = Merkletree(sto, true, 140);

        for (var i = 0; i < 16; i += 1) {
          final k = BigInt.from(i);
          final v = BigInt.from(i * 2);
          await mt.add(k, v);
        }

        var (_, v1, _) = await mt.get(BigInt.parse('10'));

        expect(v1.toRadixString(10), equals('20'));

        await mt.update(BigInt.parse('10'), BigInt.parse('1024'));

        (_, v1, _) = await mt.get(BigInt.parse('10'));

        expect((v1).toRadixString(10), equals('1024'));

        try {
          await mt.update(BigInt.parse('10'), BigInt.parse('1024'));
        } catch (err) {
          expect(err, equals(ErrKeyNotFound));
        }

        final dbRoot = await sto.getRoot();
        expect(dbRoot.string(), equals((await mt.root()).string()));
      });

      test('test update 2', () async {
        final sto1 = getTreeStorage(prefix: 'tree1');
        final sto2 = getTreeStorage(prefix: 'tree2');
        final mt1 = Merkletree(sto1, true, 140);
        final mt2 = Merkletree(sto2, true, 140);

        await mt1.add(BigInt.one, BigInt.parse('2'));
        await mt1.add(BigInt.parse('2'), BigInt.parse('229'));
        await mt1.add(BigInt.parse('9876'), BigInt.parse('6789'));

        await mt2.add(BigInt.one, BigInt.parse('11'));
        await mt2.add(BigInt.parse('2'), BigInt.parse('22'));
        await mt2.add(BigInt.parse('9876'), BigInt.parse('10'));

        await mt1.update(BigInt.one, BigInt.parse('11'));
        await mt1.update(BigInt.parse('2'), BigInt.parse('22'));
        await mt2.update(BigInt.parse('9876'), BigInt.parse('6789'));

        expect(
            (await mt1.root()).string(), equals((await mt2.root()).string()));
      });

      test('test generate and verify proof 128', () async {
        final sto = getTreeStorage();
        final mt = Merkletree(sto, true, 140);

        for (var i = 0; i < 128; i += 1) {
          final k = BigInt.from(i);
          final v = BigInt.parse('0');

          await mt.add(k, v);
        }

        final (proof, value) = await mt.generateProof(BigInt.parse('42'), null);
        expect(value.toString(), equals('0'));
        final verRes = await verifyProof(
            await mt.root(), proof, BigInt.parse('42'), BigInt.parse('0'));
        expect(verRes, equals(true));
      });

      test('test tree limit', () async {
        final sto = getTreeStorage();
        final mt = Merkletree(sto, true, 5);

        for (var i = 0; i < 16; i += 1) {
          await mt.add(BigInt.from(i), BigInt.from(i));
        }

        try {
          await mt.add(BigInt.parse('16'), BigInt.parse('16'));
        } catch (err) {
          expect(err, equals(ErrReachedMaxLevel));
        }
      });

      test('test sibligns from proof', () async {
        final sto = getTreeStorage();
        final mt = Merkletree(sto, true, 140);

        for (var i = 0; i < 64; i += 1) {
          final k = BigInt.from(i);
          final v = BigInt.parse('0');
          await mt.add(k, v);
        }

        final (proof, _) = await mt.generateProof(BigInt.parse('4'), null);
        final siblings = siblignsFroomProof(proof);

        expect(siblings.length, equals(6));

        expect(
            siblings[0].hex(),
            equals(
                'd6e368bda90c5ee3e910222c1fc1c0d9e23f2d350dbc47f4a92de30f1be3c60b'));
        expect(
            siblings[1].hex(),
            equals(
                '9dbd03b1bcd580e0f3e6668d80d55288f04464126feb1624ec8ee30be8df9c16'));
        expect(
            siblings[2].hex(),
            equals(
                'de866af9545dcd1c5bb7811e7f27814918e037eb9fead40919e8f19525896e27'));
        expect(
            siblings[3].hex(),
            equals(
                '5f4182212a84741d1174ba7c42e369f2e3ad8ade7d04eea2d0f98e3ed8b7a317'));
        expect(
            siblings[4].hex(),
            equals(
                '77639098d513f7aef9730fdb1d1200401af5fe9da91b61772f4dd142ac89a122'));
        expect(
            siblings[5].hex(),
            equals(
                '943ee501f4ba2137c79b54af745dfc5f105f539fcc449cd2a356eb5c030e3c07'));
      });

      test('test and verify proof cases', () async {
        final sto = getTreeStorage();
        final mt = Merkletree(sto, true, 140);

        for (var i = 0; i < 8; i += 1) {
          await mt.add(BigInt.from(i), BigInt.parse('0'));
        }

        // existence proof
        var (proof, _) = await mt.generateProof(BigInt.parse('4'), null);
        expect(proof.existence, equals(true));
        expect(
          await verifyProof(
            await mt.root(),
            proof,
            BigInt.parse('4'),
            BigInt.parse('0'),
          ),
          equals(true),
        );
        expect(bytes2Hex(proof.bytes),
            '0003000000000000000000000000000000000000000000000000000000000007529cbedbda2bdd25fd6455551e55245fa6dc11a9d0c27dc0cd38fca44c17e40344ad686a18ba78b502c0b6f285c5c8393bde2f7a3e2abe586515e4d84533e3037b062539bde2d80749746986cf8f0001fd2cdbf9a89fcbf981a769daef49df06');

        for (var i = 8; i < 32; i += 1) {
          final (proof, _) = await mt.generateProof(BigInt.from(i), null);
          expect(proof.existence, equals(false));
        }

        // non-existence proof, empty aux
        proof = (await mt.generateProof(BigInt.parse('12'), null)).$1;
        expect(proof.existence, equals(false));
        expect(
          await verifyProof(
            await mt.root(),
            proof,
            BigInt.parse('12'),
            BigInt.parse('0'),
          ),
          equals(true),
        );
        expect(
          bytes2Hex(proof.bytes),
          '0303000000000000000000000000000000000000000000000000000000000007529cbedbda2bdd25fd6455551e55245fa6dc11a9d0c27dc0cd38fca44c17e40344ad686a18ba78b502c0b6f285c5c8393bde2f7a3e2abe586515e4d84533e3037b062539bde2d80749746986cf8f0001fd2cdbf9a89fcbf981a769daef49df0604000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000',
        );

        await mt.graphViz(ZERO_HASH, print);

        // non-existence proof, node aux
        proof = (await mt.generateProof(BigInt.parse('10'), null)).$1;
        expect(proof.existence, equals(false));
        expect(proof.nodeAux, isNotNull);
        expect(
          await verifyProof(
            await mt.root(),
            proof,
            BigInt.parse('10'),
            BigInt.parse('0'),
          ),
          equals(true),
        );
        expect(
          bytes2Hex(proof.bytes),
          '0303000000000000000000000000000000000000000000000000000000000007529cbedbda2bdd25fd6455551e55245fa6dc11a9d0c27dc0cd38fca44c17e40344ad686a18ba78b502c0b6f285c5c8393bde2f7a3e2abe586515e4d84533e3037b062539bde2d80749746986cf8f0001fd2cdbf9a89fcbf981a769daef49df0604000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000',
        );
      });

      test('test and verify proof false', () async {
        final sto = getTreeStorage();
        final mt = Merkletree(sto, true, 140);

        for (var i = 0; i < 8; i += 1) {
          await mt.add(BigInt.from(i), BigInt.parse('0'));
        }
        // Invalid existence proof (node used for verification doesn't
        // correspond to node in the proof)
        var (proof, _) = await mt.generateProof(BigInt.parse('4'), null);
        expect(proof.existence, equals(true));
        expect(
            await verifyProof(
                await mt.root(), proof, BigInt.parse('5'), BigInt.parse('5')),
            equals(false));

        // Invalid non-existence proof (Non-existence proof, diff. node aux)
        proof = (await mt.generateProof(BigInt.parse('4'), null)).$1;
        expect(proof.existence, equals(true));
        proof.existence = false;
        proof.nodeAux = NodeAux(
            key: Hash.fromBigInt(BigInt.parse('4')),
            value: Hash.fromBigInt(BigInt.parse('4')));

        expect(
            await verifyProof(
                await mt.root(), proof, BigInt.parse('4'), BigInt.parse('0')),
            equals(false));
      });

      test('test delete', () async {
        final sto = getTreeStorage();
        final mt = Merkletree(sto, true, 10);
        expect((await mt.root()).string(), equals('0'));

        await mt.add(BigInt.one, BigInt.parse('2'));
        expect(
            (await mt.root()).string(),
            equals(
                '13578938674299138072471463694055224830892726234048532520316387704878000008795'));

        await mt.add(BigInt.parse('33'), BigInt.parse('44'));
        expect(
            (await mt.root()).string(),
            equals(
                '5412393676474193513566895793055462193090331607895808993925969873307089394741'));

        await mt.add(BigInt.parse('1234'), BigInt.parse('9876'));
        expect(
            (await mt.root()).string(),
            equals(
                '14204494359367183802864593755198662203838502594566452929175967972147978322084'));

        await mt.delete(BigInt.parse('33'));
        expect(
            (await mt.root()).string(),
            equals(
                '15550352095346187559699212771793131433118240951738528922418613687814377955591'));

        await mt.delete(BigInt.parse('1234'));
        await mt.delete(BigInt.one);

        expect((await mt.root()).string(), equals('0'));
        expect(
            (await mt.root()).string(), equals((await sto.getRoot()).string()));
      });

      test('test delete 2', () async {
        final sto1 = getTreeStorage(prefix: 'tree1');
        final sto2 = getTreeStorage(prefix: 'tree2');
        final mt1 = Merkletree(sto1, true, 140);
        final mt2 = Merkletree(sto2, true, 140);

        for (var i = 0; i < 8; i += 1) {
          final k = BigInt.from(i);
          final v = BigInt.parse('0');
          await mt1.add(k, v);
        }

        final expectedRootStr = (await mt1.root()).string();

        final k = BigInt.parse('8');
        final v = BigInt.parse('0');

        await mt1.add(k, v);
        await mt1.delete(k);

        expect(expectedRootStr, equals((await mt1.root()).string()));

        for (var i = 0; i < 8; i += 1) {
          final k = BigInt.from(i);
          final v = BigInt.parse('0');
          await mt2.add(k, v);
        }

        expect(
            (await mt1.root()).string(), equals((await mt2.root()).string()));
      });

      test('test delete 3', () async {
        final sto1 = getTreeStorage(prefix: 'tree1');
        final sto2 = getTreeStorage(prefix: 'tree2');
        final mt1 = Merkletree(sto1, true, 140);
        final mt2 = Merkletree(sto2, true, 140);

        await mt1.add(BigInt.one, BigInt.one);
        await mt1.add(BigInt.parse('2'), BigInt.parse('2'));

        expect(
            (await mt1.root()).string(),
            equals(
                '19060075022714027595905950662613111880864833370144986660188929919683258088314'));

        await mt1.delete(BigInt.one);

        expect(
            (await mt1.root()).string(),
            equals(
                '849831128489032619062850458217693666094013083866167024127442191257793527951'));

        await mt2.add(BigInt.parse('2'), BigInt.parse('2'));
        expect(
            (await mt1.root()).string(), equals((await mt2.root()).string()));
      });

      test('test delete 4', () async {
        final sto1 = getTreeStorage(prefix: 'tree1');
        final sto2 = getTreeStorage(prefix: 'tree2');
        final mt1 = Merkletree(sto1, true, 140);
        final mt2 = Merkletree(sto2, true, 140);

        await mt1.add(BigInt.one, BigInt.one);
        await mt1.add(BigInt.parse('2'), BigInt.parse('2'));
        await mt1.add(BigInt.parse('3'), BigInt.parse('3'));

        expect(
            (await mt1.root()).string(),
            equals(
                '14109632483797541575275728657193822866549917334388996328141438956557066918117'));

        await mt1.delete(BigInt.one);

        expect(
            (await mt1.root()).string(),
            equals(
                '159935162486187606489815340465698714590556679404589449576549073038844694972'));

        await mt2.add(BigInt.parse('2'), BigInt.parse('2'));
        await mt2.add(BigInt.parse('3'), BigInt.parse('3'));
        expect(
            (await mt1.root()).string(), equals((await mt2.root()).string()));
      });

      test('test delete 5', () async {
        final sto1 = getTreeStorage(prefix: 'tree1');
        final sto2 = getTreeStorage(prefix: 'tree2');
        final mt1 = Merkletree(sto1, true, 140);
        final mt2 = Merkletree(sto2, true, 140);

        await mt1.add(BigInt.one, BigInt.parse('2'));
        await mt1.add(BigInt.parse('33'), BigInt.parse('44'));

        expect(
            (await mt1.root()).string(),
            equals(
                '5412393676474193513566895793055462193090331607895808993925969873307089394741'));

        await mt1.delete(BigInt.one);

        expect(
            (await mt1.root()).string(),
            equals(
                '18869260084287237667925661423624848342947598951870765316380602291081195309822'));

        await mt2.add(BigInt.parse('33'), BigInt.parse('44'));
        expect(
            (await mt1.root()).string(), equals((await mt2.root()).string()));
      });

      test('test delete not existing keys', () async {
        final sto = getTreeStorage();
        final mt = Merkletree(sto, true, 10);

        await mt.add(BigInt.one, BigInt.parse('2'));
        await mt.add(BigInt.parse('33'), BigInt.parse('44'));

        await mt.delete(BigInt.parse('33'));

        try {
          await mt.delete(BigInt.parse('33'));
        } catch (err) {
          expect(err, equals(ErrKeyNotFound));
        }

        await mt.delete(BigInt.one);
        expect((await mt.root()).string(), equals('0'));

        try {
          await mt.delete(BigInt.parse('33'));
        } catch (err) {
          expect(err, equals(ErrKeyNotFound));
        }
      });

      test('test dump leafs and import leafs', () async {
        final sto1 = getTreeStorage(prefix: 'tree1');
        final sto2 = getTreeStorage(prefix: 'tree2');
        final mt1 = Merkletree(sto1, true, 140);
        final mt2 = Merkletree(sto2, true, 140);

        for (var i = 0; i < 10; i += 1) {
          var k = MAX_NUM_IN_FIELD - BigInt.from(i);
          final v = BigInt.parse('0');
          await mt1.add(k, v);

          k = BigInt.from(i);
          await mt1.add(k, v);
        }
      });

      test('test add and get circom proof', () async {
        final sto = getTreeStorage();
        final mt = Merkletree(sto, true, 10);

        expect((await mt.root()).string(), equals('0'));

        var cp = await mt.addAndGetCircomProof(BigInt.one, BigInt.parse('2'));

        expect(cp.oldRoot.string(), equals('0'));
        expect(
            cp.newRoot.string(),
            equals(
                '13578938674299138072471463694055224830892726234048532520316387704878000008795'));
        expect(cp.oldKey.string(), equals('0'));
        expect(cp.oldValue.string(), equals('0'));
        expect(cp.newKey.string(), equals('1'));
        expect(cp.newValue.string(), equals('2'));
        expect(cp.isOld0, equals(true));
        for (var s in cp.siblings) {
          expect(s.string(), equals('0'));
        }
        expect(mt.maxLevels, equals(cp.siblings.length));

        cp = await mt.addAndGetCircomProof(
            BigInt.parse('33'), BigInt.parse('44'));

        expect(
            cp.oldRoot.string(),
            equals(
                '13578938674299138072471463694055224830892726234048532520316387704878000008795'));
        expect(
            cp.newRoot.string(),
            equals(
                '5412393676474193513566895793055462193090331607895808993925969873307089394741'));
        expect(cp.oldKey.string(), equals('1'));
        expect(cp.oldValue.string(), equals('2'));
        expect(cp.newKey.string(), equals('33'));
        expect(cp.newValue.string(), equals('44'));
        expect(cp.isOld0, equals(false));
        for (var s in cp.siblings) {
          expect(s.string(), equals('0'));
        }
        expect(mt.maxLevels, equals(cp.siblings.length));

        cp = await mt.addAndGetCircomProof(
            BigInt.parse('55'), BigInt.parse('66'));

        expect(
            cp.oldRoot.string(),
            equals(
                '5412393676474193513566895793055462193090331607895808993925969873307089394741'));
        expect(
            cp.newRoot.string(),
            equals(
                '5094364082618099436543535513148866130251600642297988457797401489780171282025'));
        expect(cp.oldKey.string(), equals('0'));
        expect(cp.oldValue.string(), equals('0'));
        expect(cp.newKey.string(), equals('55'));
        expect(cp.newValue.string(), equals('66'));
        expect(cp.isOld0, equals(true));

        for (final (idx, s) in cp.siblings.indexed) {
          expect(
            s.string(),
            equals(
              idx == 1
                  ? '21312042436525850949775663177240566532157857119003189090405819719191539342280'
                  : '0',
            ),
          );
        }
        expect(mt.maxLevels, equals(cp.siblings.length));
      });

      test('test update circom processor proof', () async {
        final sto = getTreeStorage();
        final mt = Merkletree(sto, true, 10);

        for (var i = 0; i < 16; i += 1) {
          final k = BigInt.from(i);
          final v = BigInt.from(i * 2);
          await mt.add(k, v);
        }

        final (_, value, _) = await mt.get(BigInt.parse('10'));
        expect(value.toRadixString(10), equals('20'));

        final cp = await mt.update(BigInt.parse('10'), BigInt.parse('1024'));
        expect(
            cp.oldRoot.string(),
            equals(
                '3901088098157312895771168508102875327412498476307103941861116446804059788045'));
        expect(
            cp.newRoot.string(),
            equals(
                '18587862578201383535363956627488622136678432340275446723812600963773389007517'));
        expect(cp.oldKey.string(), equals('10'));
        expect(cp.oldValue.string(), equals('20'));
        expect(cp.newKey.string(), equals('10'));
        expect(cp.newValue.string(), equals('1024'));
        expect(cp.isOld0, equals(false));
        expect(
            cp.siblings[0].string(),
            equals(
                '3493055760199345983787399479799897884337329583575225430469748865784580035592'));
        expect(
            cp.siblings[1].string(),
            equals(
                '20201609720365205433999360001442791710365537253733030676534981802168302054263'));
        expect(
            cp.siblings[2].string(),
            equals(
                '18790542149740435554763618183910097219145811410462734411095932062387939731734'));
        expect(
            cp.siblings[3].string(),
            equals(
                '15930030482599007570177067416534114035267479078907080052418814162004846408322'));
        cp.siblings.sublist(4).forEach((s) {
          expect(s.string(), equals('0'));
        });
      });

      test('expect tree.walk does not produce infinite loop', () async {
        f(node) async {}

        var tree = Merkletree(InMemoryDB(str2Bytes('')), true, 40);

        for (var i = 0; i < 5; i++) {
          await tree.add(BigInt.from(i), BigInt.from(i));
        }

        await tree.walk(await tree.root(), (node) => f(node));
      });

      test('proof stringify', () async {
        var tree = Merkletree(InMemoryDB(str2Bytes('')), true, 40);

        for (var i = 0; i < 5; i++) {
          await tree.add(BigInt.from(i), BigInt.from(i));
        }

        final (proof, _) = await tree.generateProof(BigInt.from(9), null);

        final proofModel = jsonEncode(proof.toJson());

        final proofFromJSON = Proof.fromJson(jsonDecode(proofModel));

        expect(
          jsonEncode(proof.allSiblings().map((e) => e.string()).toList()),
          equals(jsonEncode(
              proofFromJSON.allSiblings().map((e) => e.string()).toList())),
        );
        expect(proof.existence, equals(proofFromJSON.existence));
        expect(proof.existence, equals(false));
        expect(
          jsonEncode(proof.nodeAux?.toJson()),
          equals(jsonEncode(proofFromJSON.nodeAux?.toJson())),
        );
      });

      test('should deserialize Old Hash properly', () async {
        final hash = Hash(bigIntToUINT8Array(BigInt.parse(
            '5158240518874928563648144881543092238925265313977134167935552944620041388700')));

        const oldSerializedHash =
            '{"bytes":{"0":11,"1":103,"2":117,"3":238,"4":151,"5":230,"6":106,"7":85,"8":195,"9":138,"10":136,"11":160,"12":178,"13":153,"14":109,"15":13,"16":220,"17":95,"18":34,"19":180,"20":1,"21":227,"22":55,"23":246,"24":102,"25":115,"26":95,"27":214,"28":80,"29":163,"30":194,"31":156}}';
        // deserialize
        final deserializedHash = jsonDecode(oldSerializedHash);

        final rawBytes = (deserializedHash["bytes"] as Map).values;
        final bytesList = rawBytes.map((e) => e as int).toList();
        final bytes = Uint8List.fromList(bytesList);
        final hash2 = Hash(bytes);
        final hashFromOldStr = Hash.fromString(oldSerializedHash);

        expect(
          jsonEncode(hash.string()),
          equals(jsonEncode(hashFromOldStr.string())),
        );

        expect(jsonEncode(hash.value.toList()),
            equals(jsonEncode(bytes.toList())));
        expect(hash.string(), equals(hash2.string()));

        // deep equals
        for (final (idx, val) in hash.value.indexed) {
          expect(val, equals(hash2.value[idx]));
        }

        expect(hash.hex(), equals(Hash.fromHex(hash2.hex()).hex()));
      });

      test('test smt verifier', () async {
        final sto = getTreeStorage();
        final mt = Merkletree(sto, true, 4);

        await mt.add(BigInt.one, BigInt.parse('11'));
        var cvp = await mt.generateSCVerifierProof(BigInt.one, ZERO_HASH);

        expect(
            cvp.root.string(),
            equals(
                '6525056641794203554583616941316772618766382307684970171204065038799368146416'));
        expect(cvp.siblings.length, equals(0));
        expect(cvp.oldKey.string(), equals('0'));
        expect(cvp.oldValue.string(), equals('0'));
        expect(cvp.isOld0, equals(false));
        expect(cvp.key.string(), equals('1'));
        expect(cvp.value.string(), equals('11'));
        expect(cvp.fnc, equals(0));

        await mt.add(BigInt.parse('2'), BigInt.parse('22'));
        await mt.add(BigInt.parse('3'), BigInt.parse('33'));
        await mt.add(BigInt.parse('4'), BigInt.parse('44'));

        cvp =
            await mt.generateCircomVerifierProof(BigInt.parse('2'), ZERO_HASH);

        expect(
          cvp.root.string(),
          equals(
              '13558168455220559042747853958949063046226645447188878859760119761585093422436'),
        );
        expect(cvp.siblings.length, equals(4));
        expect(
          cvp.siblings[0].string(),
          equals(
              '11620130507635441932056895853942898236773847390796721536119314875877874016518'),
        );
        expect(
          cvp.siblings[1].string(),
          equals(
              '5158240518874928563648144881543092238925265313977134167935552944620041388700'),
        );
        cvp.siblings.sublist(3).forEach((s) {
          expect(s.string(), equals('0'));
        });
        expect(cvp.oldKey.string(), equals('0'));
        expect(cvp.oldValue.string(), equals('0'));
        expect(cvp.isOld0, equals(false));
        expect(cvp.key.string(), equals('2'));
        expect(cvp.value.string(), equals('22'));
        expect(cvp.fnc, equals(0));
      });

      test('test str2Bytes', () async {
        final bytes = str2Bytes('test');

        expect(bytes.length, equals(8));
        expect(bytes[0], equals(116));
        expect(bytes[1], equals(101));
        expect(bytes[2], equals(115));
        expect(bytes[3], equals(116));
        expect(bytes[4], equals(0));
        expect(bytes[5], equals(0));
        expect(bytes[6], equals(0));
        expect(bytes[7], equals(0));
      });
    });
  }
}
