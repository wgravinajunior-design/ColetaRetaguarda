import 'package:sqflite/sqflite.dart';
import 'sqlite_service.dart';

abstract class BaseDao<T> {
  String get tableName;

  Database get database => SqliteService().database as Database;

  T fromMap(Map<String, dynamic> map);
  Map<String, dynamic> toMap(T obj);

  Future<int> insert(T obj) async {
    final db = await database;
    return db.insert(
      tableName,
      toMap(obj),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<T>> getAll() async {
    final db = await database;
    final maps = await db.query(tableName);
    return List.generate(maps.length, (i) => fromMap(maps[i]));
  }

  Future<T?> getById(int id) async {
    final db = await database;
    final maps = await db.query(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return fromMap(maps.first);
    }
    return null;
  }

  Future<int> update(T obj) async {
    final db = await database;
    final map = toMap(obj);
    final id = map['id'];
    return db.update(
      tableName,
      map,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> delete(int id) async {
    final db = await database;
    return db.delete(
      tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> count() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM $tableName');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
