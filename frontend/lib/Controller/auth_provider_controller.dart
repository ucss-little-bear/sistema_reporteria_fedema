import 'package:flutter/material.dart';
import '../Model/Entities/usuario_entity.dart';
import '../Model/Entities/api_response_entity.dart';
import '../Model/Services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  Usuario? _usuarioActual;
  bool _isLoading = false;
  String? _errorMessage;

  Usuario? get usuarioActual => _usuarioActual;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get estaAutenticado => _usuarioActual != null;

  Future<bool> login(String usuario, String password) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      ApiResponse<Usuario> response = await _authService.login(
        usuario,
        password,
      );

      if (response.status == 'success' && response.data != null) {
        _usuarioActual = response.data;
        _setLoading(false);
        return true;
      } else {
        _errorMessage = response.message ?? 'Error desconocido';
        _setLoading(false);
        return false;
      }
    } catch (e) {
      _errorMessage = 'Error de conexión: $e';
      _setLoading(false);
      return false;
    }
  }

  // NUEVA FUNCIÓN: Apaga el interruptor localmente
  void completarPrimerLogin() {
    if (_usuarioActual != null) {
      _usuarioActual = Usuario(
        idUsuario: _usuarioActual!.idUsuario,
        idRol: _usuarioActual!.idRol,
        nombres: _usuarioActual!.nombres,
        apellidos: _usuarioActual!.apellidos,
        dni: _usuarioActual!.dni,
        nombreUsuario: _usuarioActual!.nombreUsuario,
        correo: _usuarioActual!.correo,
        rolDescripcion: _usuarioActual!.rolDescripcion,
        estado: _usuarioActual!.estado,
        primerLogin: false, // Lo pasamos a falso
        tienePinConfigurado: _usuarioActual!.tienePinConfigurado,
      );
      notifyListeners();
    }
  }

  void logout() {
    _usuarioActual = null;
    _errorMessage = null;
    notifyListeners();
  }

  void _setLoading(bool valor) {
    _isLoading = valor;
    notifyListeners();
  }

  void actualizarEstadoPin(bool estado) {
    if (_usuarioActual != null) {
      _usuarioActual = _usuarioActual!.copyWith(tienePinConfigurado: estado);
      notifyListeners();
    }
  }
}
