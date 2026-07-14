import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'db_migration.dart';

class SqliteService {
  static final SqliteService _instance = SqliteService._internal();
  Database? _database;

  factory SqliteService() {
    return _instance;
  }

  SqliteService._internal();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'coleta_erp.db');

    return openDatabase(
      path,
      version: dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    for (String migration in getMigrations()) {
      await db.execute(migration);
    }
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < newVersion) {
      for (String migration in getMigrations()) {
        try {
          await db.execute(migration);
        } catch (e) {
          print('Migration error (table may exist): $e');
        }
      }
    }
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
