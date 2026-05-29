import 'package:flutter/material.dart';
import 'package:frontend/Model/Entities/api_response_entity.dart';
import 'package:frontend/Model/Entities/reporte_entity.dart';
import 'package:frontend/Model/Services/reporte_service.dart';

class ReporteProvider extends ChangeNotifier {
  final ReporteService _reporteService = ReporteService();

  List<Reporte> _listaReportes = [];
  bool _isLoading = false;
  String? _errorMessage;

  // Getters
  List<Reporte> get listaReportes => _listaReportes;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // CU-13: Cargar reportes (Listar)
  // Recibe el usuario actual para saber qué filtrar
  Future<void> cargarReportes(int idUsuario, int idRol) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      ApiResponse<List<Reporte>> response = await _reporteService
          .listarReportes(idUsuario, idRol);

      if (response.status == 'success' && response.data != null) {
        _listaReportes = response.data!;
      } else {
        _errorMessage =
            response.message ?? 'No se pudieron cargar los reportes';
        _listaReportes = []; // Limpiar lista en caso de error
      }
    } catch (e) {
      _errorMessage = 'Error de conexión al cargar reportes';
    }

    _setLoading(false);
  }

  // CU-03: Crear un nuevo reporte

  // CU-05, CU-07, CU-09: Firmar reporte (Actualizar estado)

  void _setLoading(bool valor) {
    _isLoading = valor;
    notifyListeners();
  }
}
