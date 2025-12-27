import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../config/constants.dart';
import '../models/user_progress.dart';

class DatabaseService {
  static Database? _database;
  static final DatabaseService instance = DatabaseService._internal();

  DatabaseService._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, AppConstants.databaseName);

    return await openDatabase(
      path,
      version: AppConstants.databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // User Progress Table
    await db.execute('''
      CREATE TABLE user_progress (
        imageId TEXT PRIMARY KEY,
        filledRegionIds TEXT NOT NULL,
        lastModified INTEGER NOT NULL,
        isCompleted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Settings Table
    await db.execute('''
      CREATE TABLE settings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Favorites Table
    await db.execute('''
      CREATE TABLE favorites (
        imageId TEXT PRIMARY KEY,
        addedAt INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database migrations here
  }

  // ========== Progress Methods ==========

  Future<void> saveProgress(UserProgress progress) async {
    final db = await database;
    await db.insert(
      'user_progress',
      progress.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<UserProgress?> getProgress(String imageId) async {
    final db = await database;
    final maps = await db.query(
      'user_progress',
      where: 'imageId = ?',
      whereArgs: [imageId],
    );

    if (maps.isEmpty) return null;
    return UserProgress.fromMap(maps.first);
  }

  Future<List<UserProgress>> getAllProgress() async {
    final db = await database;
    final maps = await db.query('user_progress');
    return maps.map((map) => UserProgress.fromMap(map)).toList();
  }

  Future<void> deleteProgress(String imageId) async {
    final db = await database;
    await db.delete(
      'user_progress',
      where: 'imageId = ?',
      whereArgs: [imageId],
    );
  }

  // ========== Favorites Methods ==========

  Future<void> addFavorite(String imageId) async {
    final db = await database;
    await db.insert(
      'favorites',
      {
        'imageId': imageId,
        'addedAt': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeFavorite(String imageId) async {
    final db = await database;
    await db.delete(
      'favorites',
      where: 'imageId = ?',
      whereArgs: [imageId],
    );
  }

  Future<bool> isFavorite(String imageId) async {
    final db = await database;
    final result = await db.query(
      'favorites',
      where: 'imageId = ?',
      whereArgs: [imageId],
    );
    return result.isNotEmpty;
  }

  Future<List<String>> getFavoriteIds() async {
    final db = await database;
    final maps = await db.query('favorites', orderBy: 'addedAt DESC');
    return maps.map((map) => map['imageId'] as String).toList();
  }

  // ========== Settings Methods ==========

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert(
      'settings',
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final maps = await db.query(
      'settings',
      where: 'key = ?',
      whereArgs: [key],
    );
    if (maps.isEmpty) return null;
    return maps.first['value'] as String;
  }
}