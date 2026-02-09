import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final path = join(await getDatabasesPath(), 'bioshot.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE shots (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            elbowAngle REAL,
            kneeAngle REAL,
            timestamp TEXT
          )
        ''');
      },
    );
  }

  Future<void> insertShot(double elbow, double knee) async {
    final db = await database;

    await db.insert(
      'shots',
      {
        'elbowAngle': elbow,
        'kneeAngle': knee,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }
}