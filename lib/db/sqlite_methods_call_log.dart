import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/log_model.dart';

class SqliteMethodsforCallLog {
  Database? _db;

  String databaseName = ' ';

  String tableName = 'call_logs';

  String id = 'log_id';
  String callerName = 'caller_name';
  String callerPic = 'caller_pic';
  String receiverName = 'receiver_name';
  String receiverPic = 'receiver_pic';
  String callStatus = 'call_status';
  String timeStamp = 'time_stamp';

  Future<Database?> get db async {
    if (_db != null) {
      return _db;
    }
    if (kDebugMode) { debugPrint('db was null, now awaiting it'); }
    _db = await init();
    return _db;
  }

  openDb(dbName) => (databaseName = dbName);

  init() async {
    Directory dir = await getApplicationDocumentsDirectory();

    String path = join(dir.path, databaseName);

    var db = await openDatabase(path, version: 1, onCreate: _onCreate);
    return db;
  }

  _onCreate(Database db, int version) async {
    String createTableQuery =
        "CREATE TABLE $tableName ($id INTEGER PRIMARY KEY, $callerName TEXT, $callerPic TEXT , $receiverName TEXT, $receiverPic TEXT, $callStatus TEXT, $timeStamp TEXT)";

    await db.execute(createTableQuery);
    if (kDebugMode) { debugPrint('table created'); }
  }

  addLogs(Log log) async {
    var dbClient = await db;
    if (kDebugMode) { debugPrint("The log has been added in sqlite db"); }
    await dbClient?.insert(tableName, log.toMap(log));
  }

  deleteLogs(int logId) async {
    var dbClient = await db;
    return await dbClient
        ?.delete(tableName, where: '$id = ?', whereArgs: [logId + 1]);
  }

  updateLogs(Log log) async {
    var dbClient = await db;

    await dbClient?.update(
      tableName,
      log.toMap(log),
      where: '$id = ?',
      whereArgs: [log.logId],
    );
  }

  Future<List<Log>?> getLogs() async {
    try {
      var dbClient = await db;

      // List<Map<String, Object?>>? maps = await dbClient?.rawQuery('SELECT * FROM $tableName');
      List<Map<String, Object?>>? maps =
          await dbClient?.query(tableName, columns: [
        id,
        callerName,
        callerPic,
        receiverName,
        receiverPic,
        callStatus,
        timeStamp,
      ]);
      List<Log> logList = [];

      if (maps != null) {
        for (Map map in maps) {
          logList.add(Log.fromMap(map));
        }
      }

      return logList;
    } catch (e) {
      if (kDebugMode) { debugPrint('$e'); }
      return null;
    }
  }

  close() async {
    var dbClient = await db;
    dbClient?.close();
  }
}
