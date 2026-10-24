import 'dart:convert';

import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'offline_models.dart';

class OfflineDatabase {
  Database? _db;

  Future<Database> _database() async {
    if (_db != null) return _db!;
    final ruta = p.join(await getDatabasesPath(), 'fashionstore_offline.db');
    _db = await openDatabase(
      ruta,
      version: 1,
      onCreate: (db, _) => db.execute('''
        CREATE TABLE catalogo_snapshot (
          clave TEXT PRIMARY KEY,
          empresa_id INTEGER NOT NULL,
          sucursal_id INTEGER NOT NULL,
          guardado_en TEXT NOT NULL,
          version_datos TEXT NOT NULL,
          payload TEXT NOT NULL
        )
      '''),
    );
    return _db!;
  }

  Future<DatosOffline> guardar(Map<String, dynamic> payload) async {
    final validado = DatosOffline.fromJson(payload);
    if (validado.schemaVersion != 1) {
      throw const FormatException(
        'La versión de datos offline no es compatible.',
      );
    }
    final ahora = DateTime.now();
    final db = await _database();
    await db.transaction((tx) async {
      await tx.insert('catalogo_snapshot', {
        'clave': '${validado.empresaId}:${validado.sucursalId}',
        'empresa_id': validado.empresaId,
        'sucursal_id': validado.sucursalId,
        'guardado_en': ahora.toIso8601String(),
        'version_datos': validado.versionDatos,
        'payload': jsonEncode(payload),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    return DatosOffline.fromJson(payload, guardadoEn: ahora);
  }

  Future<DatosOffline?> obtener(int empresaId, int sucursalId) async {
    final db = await _database();
    final rows = await db.query(
      'catalogo_snapshot',
      where: 'empresa_id = ? AND sucursal_id = ?',
      whereArgs: [empresaId, sucursalId],
      limit: 1,
    );
    return rows.isEmpty ? null : _desdeFila(rows.first);
  }

  Future<DatosOffline?> ultimoDeEmpresa(int empresaId) async {
    final db = await _database();
    final rows = await db.query(
      'catalogo_snapshot',
      where: 'empresa_id = ?',
      whereArgs: [empresaId],
      orderBy: 'guardado_en DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : _desdeFila(rows.first);
  }

  DatosOffline _desdeFila(Map<String, Object?> row) => DatosOffline.fromJson(
    jsonDecode(row['payload']! as String) as Map<String, dynamic>,
    guardadoEn: DateTime.parse(row['guardado_en']! as String),
  );
}
