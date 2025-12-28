import 'dart:io';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../config/constants.dart';
import '../models/user_progress.dart';

class DatabaseService {
  static Database? _database;
  static final DatabaseService instance = DatabaseService._internal();
  static bool _initialized = false;

  DatabaseService._internal();

  /// Initialize the database factory for Windows
  static Future<void> initializeFfi() async {
    if (_initialized) return;
    
    // Initialize FFI for Windows/Linux
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _initialized = true;
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final String dbFolder = join(appDocDir.path, 'HappyColor');
    
    // Create directory if it doesn't exist
    final dbDir = Directory(dbFolder);
    if (!await dbDir.exists()) {
      await dbDir.create(recursive: true);
    }

    final String dbPath = join(dbFolder, AppConstants.databaseName);

    return await openDatabase(
      dbPath,
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

  // ========== Close Database ==========
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}