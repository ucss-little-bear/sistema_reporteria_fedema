import 'dart:convert';
import 'package:http/http.dart' as http;
import '../Entities/usuario_entity.dart';
import '../Entities/api_response_entity.dart';
import 'api_config.dart';

class UsuarioService {
  // Listar todos los usuarios
  Future<ApiResponse<List<Usuario>>> listarUsuarios() async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.baseUrl),
        headers: ApiConfig
            .headers, // Asegúrate que sea {"Content-Type": "application/json"}
        body: jsonEncode({"accion": "listar_usuarios"}),
      );

      if (response.statusCode == 200) {
        // Verificamos si el cuerpo está vacío
        if (response.body.isEmpty) {
          return ApiResponse(
            status: "error",
            message: "El servidor devolvió una respuesta vacía",
          );
        }

        try {
          final jsonMap = jsonDecode(response.body);
          return ApiResponse<List<Usuario>>.fromJson(
            jsonMap,
            (data) =>
                (data as List).map((item) => Usuario.fromJson(item)).toList(),
          );
        } catch (e) {
          return ApiResponse(
            status: "error",
            message: "Error al decodificar JSON: $e\nCuerpo: ${response.body}",
          );
        }
      }
      return ApiResponse(
        status: "error",
        message: "Error HTTP: ${response.statusCode}",
      );
    } catch (e) {
      return ApiResponse(status: "error", message: "Excepción: $e");
    }
  }

  Future<ApiResponse<bool>> editarUsuario(Map<String, dynamic> datos) async {
    try {
      datos['accion'] = 'editar_usuario';
      final response = await http.post(
        Uri.parse(ApiConfig.baseUrl),
        headers: ApiConfig.headers,
        body: jsonEncode(datos),
      );

      final jsonMap = jsonDecode(response.body);
      return ApiResponse(
        status: jsonMap['status'],
        message: jsonMap['message'],
        data: jsonMap['status'] == 'success',
      );
    } catch (e) {
      return ApiResponse(status: "error", message: "$e");
    }
  }

  // Crear usuario
  Future<ApiResponse<bool>> crearUsuario(Map<String, dynamic> datos) async {
    try {
      datos['accion'] = 'crear_usuario';
      final response = await http.post(
        Uri.parse(ApiConfig.baseUrl),
        headers: ApiConfig.headers,
        body: jsonEncode(datos),
      );

      final jsonMap = jsonDecode(response.body);
      return ApiResponse(
        status: jsonMap['status'],
        message: jsonMap['message'],
        data: jsonMap['status'] == 'success',
      );
    } catch (e) {
      return ApiResponse(status: "error", message: "$e");
    }
  }

  Future<ApiResponse<bool>> cambiarPassword(
    int idUsuario,
    String newPassword,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.baseUrl),
        headers: ApiConfig.headers,
        body: jsonEncode({
          "accion": "cambiar_password",
          "id_usuario": idUsuario,
          "new_password": newPassword,
        }),
      );

      final jsonMap = jsonDecode(response.body);
      return ApiResponse(
        status: jsonMap['status'],
        message: jsonMap['message'],
        data: jsonMap['status'] == 'success',
      );
    } catch (e) {
      return ApiResponse(status: "error", message: "$e");
    }
  }

  // Cambiar estado (Activar/Desactivar)
  Future<ApiResponse<bool>> cambiarEstado(
    int idUsuario,
    int nuevoEstado,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.baseUrl),
        headers: ApiConfig.headers,
        body: jsonEncode({
          "accion": "cambiar_estado_usuario",
          "id_usuario": idUsuario,
          "nuevo_estado": nuevoEstado,
        }),
      );
      final jsonMap = jsonDecode(response.body);
      return ApiResponse(
        status: jsonMap['status'],
        message: jsonMap['message'],
        data: jsonMap['status'] == 'success',
      );
    } catch (e) {
      return ApiResponse(status: "error", message: "$e");
    }
  }
}
