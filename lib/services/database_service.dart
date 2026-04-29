import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/recording.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'sonohaler_lab.db');

    return await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE recordings (
            id            INTEGER PRIMARY KEY AUTOINCREMENT,
            file_id       TEXT    NOT NULL,
            inhaler_type  TEXT    NOT NULL DEFAULT 'None',
            flow_rate     INTEGER NOT NULL,
            actuations    TEXT    NOT NULL DEFAULT 'No',
            is_inhalation INTEGER NOT NULL DEFAULT 0,
            environment   TEXT    NOT NULL,
            dose_mg       INTEGER NOT NULL,
            distance_cm   INTEGER NOT NULL,
            duration_sec  INTEGER NOT NULL,
            timestamp     TEXT    NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // Add the three new columns introduced in schema v2.
          // SQLite ALTER TABLE only supports ADD COLUMN, so each column
          // must be added individually with a DEFAULT so existing rows are
          // valid immediately.
          await db.execute(
              "ALTER TABLE recordings ADD COLUMN inhaler_type TEXT NOT NULL DEFAULT 'None'");
          await db.execute(
              "ALTER TABLE recordings ADD COLUMN actuations TEXT NOT NULL DEFAULT 'No'");
          await db.execute(
              "ALTER TABLE recordings ADD COLUMN is_inhalation INTEGER NOT NULL DEFAULT 0");
        }
      },
    );
  }

  Future<int> insertRecording(Recording recording) async {
    final db = await database;
    return await db.insert(
      'recordings',
      recording.toMap()..remove('id'),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Recording>> getAllRecordings() async {
    final db = await database;
    final maps = await db.query('recordings', orderBy: 'timestamp DESC');
    return maps.map((map) => Recording.fromMap(map)).toList();
  }

  Future<int> deleteRecording(int id) async {
    final db = await database;
    return await db.delete('recordings', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
