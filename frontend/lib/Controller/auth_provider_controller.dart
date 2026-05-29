import 'package:flutter/material.dart';
import '../Model/Entities/usuario_entity.dart';
import '../Model/Entities/api_response_entity.dart';
import '../Model/Services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  Usuario? _usuarioActual;
  bool _isLoading = false;
  String? _errorMessage;

  // Getters para que la Vista pueda leer los datos
  Usuario? get usuarioActual => _usuarioActual;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get estaAutenticado => _usuarioActual != null;

  // Función de Login (CU-14)
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
        return true; // Login exitoso
      } else {
        _errorMessage = response.message ?? 'Error desconocido';
        _setLoading(false);
        return false; // Login fallido
      }
    } catch (e) {
      _errorMessage = 'Error de conexión: $e';
      _setLoading(false);
      return false;
    }
  }

  // Función de Logout (limpia el estado)
  void logout() {
    _usuarioActual = null;
    _errorMessage = null;
    notifyListeners();
  }

  // Helper interno para actualizar estado de carga y notificar
  void _setLoading(bool valor) {
    _isLoading = valor;
    notifyListeners(); // ¡Esto es lo que actualiza la pantalla!
  }
}
