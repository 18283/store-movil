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
      version: 2,
      onCreate: (db, _) async {
        await db.execute('''
        CREATE TABLE catalogo_snapshot (
          clave TEXT PRIMARY KEY,
          empresa_id INTEGER NOT NULL,
          sucursal_id INTEGER NOT NULL,
          guardado_en TEXT NOT NULL,
          version_datos TEXT NOT NULL,
          payload TEXT NOT NULL
        )
      ''');
        await db.execute(_crearTablaOperaciones);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(_crearTablaOperaciones);
        }
      },
    );
    return _db!;
  }

  static const _crearTablaOperaciones = '''
    CREATE TABLE operacion_pendiente (
      clave_idempotencia TEXT PRIMARY KEY,
      tipo TEXT NOT NULL,
      estado TEXT NOT NULL,
      creado_en_dispositivo TEXT NOT NULL,
      resumen TEXT NOT NULL,
      payload TEXT NOT NULL,
      motivo_rechazo TEXT,
      reserva_id INTEGER,
      venta_id INTEGER
    )
  ''';

  // ------------------------------------------------------------------------- #
  //  CU11/CU12/CU13/CU14/CU15 — Cola de operaciones pendientes
  // ------------------------------------------------------------------------- #
  Future<void> guardarOperacion(OperacionPendiente op) async {
    final db = await _database();
    await db.insert('operacion_pendiente', {
      'clave_idempotencia': op.claveIdempotencia,
      'tipo': op.tipo,
      'estado': op.estado.name,
      'creado_en_dispositivo': op.creadoEnDispositivo.toIso8601String(),
      'resumen': op.resumen,
      'payload': jsonEncode(op.payload),
      'motivo_rechazo': op.motivoRechazo,
      'reserva_id': op.reservaId,
      'venta_id': op.ventaId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<OperacionPendiente>> listarOperaciones() async {
    final db = await _database();
    final filas = await db.query(
      'operacion_pendiente',
      orderBy: 'creado_en_dispositivo DESC',
    );
    return filas.map(_operacionDesdeFila).toList();
  }

  OperacionPendiente _operacionDesdeFila(Map<String, Object?> fila) =>
      OperacionPendiente(
        claveIdempotencia: fila['clave_idempotencia']! as String,
        tipo: fila['tipo']! as String,
        estado: estadoOperacionDesdeTexto(fila['estado']! as String),
        creadoEnDispositivo: DateTime.parse(
          fila['creado_en_dispositivo']! as String,
        ),
        resumen: fila['resumen']! as String,
        payload: jsonDecode(fila['payload']! as String) as Map<String, dynamic>,
        motivoRechazo: fila['motivo_rechazo'] as String?,
        reservaId: fila['reserva_id'] as int?,
        ventaId: fila['venta_id'] as int?,
      );

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
