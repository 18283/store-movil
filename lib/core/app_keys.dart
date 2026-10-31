import 'package:flutter/material.dart';

/// Permite mostrar un SnackBar desde fuera del árbol de widgets (p. ej.
/// cuando llega una notificación push con la app en primer plano, CU14/CU15).
final GlobalKey<ScaffoldMessengerState> rootScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
