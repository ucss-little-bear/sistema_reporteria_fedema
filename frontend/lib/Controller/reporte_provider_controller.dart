import 'package:flutter/material.dart';
import 'package:frontend/Model/Entities/api_response_entity.dart';
import 'package:frontend/Model/Entities/reporte_entity.dart';
import 'package:frontend/Model/Services/reporte_service.dart';

class ReporteProvider extends ChangeNotifier {
  final ReporteService _reporteService = ReporteService();

  List<Reporte> _listaReportes = [];
  bool _isLoading = false;
  String? _errorMessage;


  List<Reporte> get listaReportes => _listaReportes;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;



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
        _listaReportes = [];
      }
    } catch (e) {
      _errorMessage = 'Error de conexión al cargar reportes';
    }

    _setLoading(false);
  }





  void _setLoading(bool valor) {
    _isLoading = valor;
    notifyListeners();
  }
}
