import 'dart:convert';
import 'package:http/http.dart' as http;
import '../Entities/usuario_entity.dart';
import '../Entities/api_response_entity.dart';
import 'api_config.dart';

class AuthService {
  // Función para iniciar sesión (CU-14)
  Future<ApiResponse<Usuario>> login(String usuario, String password) async {
    try {
      final body = jsonEncode({
        "accion": "login",
        "usuario": usuario,
        "password": password,
      });

      final response = await http.post(
        Uri.parse(ApiConfig.baseUrl),
        headers: ApiConfig.headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final jsonMap = jsonDecode(response.body);

        // Mapear la respuesta usando el factory de Usuario
        return ApiResponse<Usuario>.fromJson(
          jsonMap,
          (data) => Usuario.fromJson(data as Map<String, dynamic>),
        );
      } else {
        return ApiResponse(
          status: "error",
          message: "Error de servidor: ${response.statusCode}",
        );
      }
    } catch (e) {
      return ApiResponse(status: "error", message: "Error de conexión: $e");
    }
  }
}
