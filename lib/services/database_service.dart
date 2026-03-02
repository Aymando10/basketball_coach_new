// services/database_service.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class ShotRecord {
  final int? id;
  final double elbowAngle;
  final double kneeAngle;

  final int totalScore;
  final int elbowScore;
  final int kneeScore;
  final int wristScore;
  final int speedScore;

  final int releaseTimeMs;
  final String timestamp;

  ShotRecord({
    this.id,
    required this.elbowAngle,
    required this.kneeAngle,
    required this.totalScore,
    required this.elbowScore,
    required this.kneeScore,
    required this.wristScore,
    required this.speedScore,
    required this.releaseTimeMs,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'elbowAngle': elbowAngle,
      'kneeAngle': kneeAngle,
      'totalScore': totalScore,
      'elbowScore': elbowScore,
      'kneeScore': kneeScore,
      'wristScore': wristScore,
      'speedScore': speedScore,
      'releaseTimeMs': releaseTimeMs,
      'timestamp': timestamp,
    };
  }

  factory ShotRecord.fromMap(Map<String, dynamic> map) {
    return ShotRecord(
      id: map['id'],
      elbowAngle: map['elbowAngle'],
      kneeAngle: map['kneeAngle'],
      totalScore: map['totalScore'],
      elbowScore: map['elbowScore'],
      kneeScore: map['kneeScore'],
      wristScore: map['wristScore'],
      speedScore: map['speedScore'],
      releaseTimeMs: map['releaseTimeMs'],
      timestamp: map['timestamp'],
    );
  }
}

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
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE shots (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            elbowAngle REAL,
            kneeAngle REAL,
            totalScore INTEGER,
            elbowScore INTEGER,
            kneeScore INTEGER,
            wristScore INTEGER,
            speedScore INTEGER,
            releaseTimeMs INTEGER,
            timestamp TEXT
          )
        ''');
      },
    );
  }

  Future<void> insertShot(ShotRecord shot) async {
    final db = await database;
    await db.insert('shots', shot.toMap());
  }

  Future<List<ShotRecord>> getShots() async {
    final db = await database;
    final maps = await db.query('shots', orderBy: 'id DESC');

    return maps.map((e) => ShotRecord.fromMap(e)).toList();
  }
}