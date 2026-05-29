import 'package:flutter/material.dart';
import 'package:frontend/Model/Entities/usuario_entity.dart';
import 'package:frontend/Model/Services/usuario_service.dart';

class UsuarioProvider extends ChangeNotifier {
  final UsuarioService _service = UsuarioService();

  List<Usuario> _usuarios = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<Usuario> get usuarios => _usuarios;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> cargarUsuarios() async {
    _isLoading = true;
    notifyListeners();

    final response = await _service.listarUsuarios();

    if (response.status == 'success') {
      _usuarios = response.data ?? [];
    } else {
      _errorMessage = response.message;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> crearUsuario(Map<String, dynamic> datos) async {
    _isLoading = true;
    notifyListeners();

    final response = await _service.crearUsuario(datos);

    if (response.status == 'success') {
      await cargarUsuarios(); // Recargar lista
      return true;
    } else {
      _errorMessage = response.message;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> editarUsuario(Map<String, dynamic> datos) async {
    _isLoading = true;
    notifyListeners();

    final response = await _service.editarUsuario(datos);

    if (response.status == 'success') {
      await cargarUsuarios(); // Recargar lista para ver cambios
      return true;
    } else {
      _errorMessage = response.message;
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> cambiarEstado(int idUsuario, int estadoActual) async {
    // Invertir estado (Si es 1 pasa a 0, si es 0 pasa a 1)
    int nuevoEstado = estadoActual == 1 ? 0 : 1;

    final response = await _service.cambiarEstado(idUsuario, nuevoEstado);

    if (response.status == 'success') {
      await cargarUsuarios();
      return true;
    }
    return false;
  }

  Future<bool> cambiarPassword(int idUsuario, String newPassword) async {
    _isLoading = true;
    notifyListeners();

    final response = await _service.cambiarPassword(idUsuario, newPassword);

    _isLoading = false;
    notifyListeners();

    if (response.status != 'success') {
      _errorMessage = response.message;
      return false;
    }
    return true;
  }
}
