import 'package:my_porject/db/sqlite_methods_call_log.dart';

import '../models/log_model.dart';

class LogRepository {
  static var dbObject;

  static init({required String dbName}) {
    dbObject = SqliteMethodsforCallLog();
    dbObject.openDb(dbName);
    dbObject.init();
  }

  static addLogs(Log log) => dbObject.addLogs(log);

  static deleteLogs(int logId) => dbObject.deleteLogs(logId);

  static getLogs() => dbObject.getLogs();

  static close() => dbObject.close();
}
