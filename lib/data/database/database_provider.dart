import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:perfinance/data/database/app_database.dart';

final databaseProvider = FutureProvider<Database>((ref) async {
  final dir = await getApplicationDocumentsDirectory();
  return openAppDatabase(dir.path);
});
