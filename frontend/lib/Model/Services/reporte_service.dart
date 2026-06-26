import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:frontend/Model/Entities/api_response_entity.dart';
import 'package:frontend/Model/Entities/reporte_entity.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'package:excel/excel.dart';

class ReporteService {

  Future<ApiResponse<List<Reporte>>> listarReportes(
    int idUsuario,
    int idRol,
  ) async {
    try {
      final body = {
        "accion": "listar_reportes",
        "id_usuario": idUsuario,
        "id_rol": idRol,
      };
      final response = await http.post(
        Uri.parse(ApiConfig.baseUrl),
        headers: ApiConfig.headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final jsonMap = jsonDecode(response.body);
        return ApiResponse<List<Reporte>>.fromJson(jsonMap, (data) {
          final list = data as List;
          return list.map((item) => Reporte.fromJson(item)).toList();
        });
      }
      return ApiResponse(
        status: "error",
        message: "HTTP ${response.statusCode}",
      );
    } catch (e) {
      return ApiResponse(status: "error", message: "Error: $e");
    }
  }

  // CR-SDRF-4: Escudo preventivo en el servicio para mitigar desbordamientos del parser Excel.
  Future<ApiResponse<dynamic>> enviarAsistenciaExcel(
    PlatformFile file,
    int idUsuario, {
    int? idDocente,
    bool force = false,
  }) async {
    try {
      final rawExt = file.name.split('.').last.toLowerCase();
      final extension = rawExt.replaceAll(RegExp(r'[^a-z0-9]'), '');
      
      if (extension != 'xls' && extension != 'xlsx') {
        return ApiResponse(
            status: "error", 
            message: "Formato inválido. Solo se admiten archivos Excel (.xls, .xlsx)."
        );
      }
      if (file.size > 5 * 1024 * 1024) {
        return ApiResponse(
            status: "error", 
            message: "El archivo excede el límite máximo de 5MB."
        );
      }

      List<int> bytes = _obtenerBytes(file);
      if (bytes.isEmpty) return ApiResponse(status: "error", message: "Archivo vacío.");

      var excel;
      try {
        excel = Excel.decodeBytes(bytes);
      } catch (e) {
        return _manejarErrorFormato(e);
      }

      List<List<String>> filasTodas = [];
      for (var tableKey in excel.tables.keys) {
        var table = excel.tables[tableKey];
        if (table != null) {
          for (var row in table.rows) {
            List<String> filaLimpia = row
                .map((c) => c?.value?.toString().trim() ?? "")
                .toList()
                .cast<String>();
            if (filaLimpia.any((c) => c.isNotEmpty)) filasTodas.add(filaLimpia);
          }
        }
      }

      final body = {
        "accion": "procesar_asistencia_excel",
        "id_usuario": idUsuario,
        "nombre_archivo": file.name,
        "filas": filasTodas,
        "force_upload": force,
      };
      if (idDocente != null) body["id_docente"] = idDocente;

      return await _enviarRequest(body);
    } catch (e) {
      return ApiResponse(status: "error", message: "Error procesando asistencia: $e");
    }
  }

  // CR-SDRF-4: Validación de seguridad replicada para el módulo de Calificaciones.
  Future<ApiResponse<dynamic>> enviarNotasExcel(
    PlatformFile file,
    int idUsuario, {
    int? idDocente,
    bool force = false,
  }) async {
    try {
      final rawExt = file.name.split('.').last.toLowerCase();
      final extension = rawExt.replaceAll(RegExp(r'[^a-z0-9]'), '');

      if (extension != 'xls' && extension != 'xlsx') {
        return ApiResponse(
            status: "error", 
            message: "Formato inválido. Las Notas requieren estrictamente archivos Excel (.xls, .xlsx)."
        );
      }
      if (file.size > 5 * 1024 * 1024) {
        return ApiResponse(
            status: "error", 
            message: "El archivo excede el límite máximo de 5MB."
        );
      }

      List<int> bytes = _obtenerBytes(file);
      if (bytes.isEmpty) return ApiResponse(status: "error", message: "Archivo vacío.");

      var excel;
      try {
        excel = Excel.decodeBytes(bytes);
      } catch (e) {
        return _manejarErrorFormato(e);
      }

      Map<String, List<List<String>>> hojasData = {};
      for (var key in excel.tables.keys) {
        var table = excel.tables[key];
        if (table != null) {
          List<List<String>> filasHoja = [];
          for (var row in table.rows) {
            List<String> filaLimpia = row
                .map((c) => c?.value?.toString().trim() ?? "")
                .toList()
                .cast<String>();
            filasHoja.add(filaLimpia);
          }
          hojasData[key] = filasHoja;
        }
      }

      final body = {
        "accion": "procesar_notas_excel",
        "id_usuario": idUsuario,
        "nombre_archivo": file.name,
        "filas": hojasData,
        "force_upload": force,
      };
      if (idDocente != null) body["id_docente"] = idDocente;

      return await _enviarRequest(body);
    } catch (e) {
      return ApiResponse(status: "error", message: "Error procesando notas: $e");
    }
  }

  Future<List<String>> getAnios() async {
    final res = await _post("listar_anios_reporte", {});
    return (res['data'] as List).map((e) => e.toString()).toList();
  }

  Future<List<String>> getNiveles(String anio) async {
    final res = await _post("listar_niveles_reporte", {"anio": anio});
    return (res['data'] as List).map((e) => e.toString()).toList();
  }

  Future<List<Map<String, dynamic>>> getSalones(
    String anio,
    String nivel,
  ) async {
    final res = await _post("listar_salones_reporte", {
      "anio": anio,
      "nivel": nivel,
    });
    return List<Map<String, dynamic>>.from(res['data']);
  }

  Future<List<String>> getBimestres(int idPeriodo) async {
    final res = await _post("listar_bimestres_reporte", {
      "id_periodo": idPeriodo,
    });
    return (res['data'] as List).map((e) => e.toString()).toList();
  }

  Future<List<String>> getBimestresPorNivel(String anio, String nivel) async {
    final res = await _post("listar_bimestres_nivel", {
      "anio": anio,
      "nivel": nivel,
    });
    return (res['data'] as List).map((e) => e.toString()).toList();
  }

  Future<ApiResponse<dynamic>> generarBoletaNotas({
    required int idUsuario,
    required int idPeriodo,
    required int bimestre,
    required String fechaInicio,
    required String fechaFin,
    bool force = false,
  }) async {
    try {
      final body = {
        "accion": "generar_boleta_notas",
        "id_usuario": idUsuario,
        "id_periodo": idPeriodo,
        "bimestre": bimestre,
        "fecha_inicio": fechaInicio,
        "fecha_fin": fechaFin,
        "force": force,
      };
      return await _enviarRequest(body);
    } catch (e) {
      return ApiResponse(status: "error", message: "Error: $e");
    }
  }

  Future<ApiResponse<dynamic>> generarReporteRendimiento({
    required int idUsuario,
    required String anio,
    required String nivel,
    required int bimestre,
    required String fechaInicio,
    required String fechaFin,
    bool force = false,
    bool ignoreMissing = false,
  }) async {
    try {
      final body = {
        "accion": "generar_reporte_rendimiento",
        "id_usuario": idUsuario,
        "anio": anio,
        "nivel": nivel,
        "bimestre": bimestre,
        "fecha_inicio": fechaInicio,
        "fecha_fin": fechaFin,
        "force": force,
        "ignore_missing": ignoreMissing,
      };
      return await _enviarRequest(body);
    } catch (e) {
      return ApiResponse(status: "error", message: "Error: $e");
    }
  }

  List<int> _obtenerBytes(PlatformFile file) {
    if (file.bytes != null) return file.bytes!;
    if (file.path != null) return File(file.path!).readAsBytesSync();
    return [];
  }

  ApiResponse<dynamic> _manejarErrorFormato(dynamic e) {
    if (e.toString().toLowerCase().contains("damaged") ||
        e.toString().toLowerCase().contains("corrupted") ||
        e.toString().toLowerCase().contains("archive")) {
      return ApiResponse(
        status: "error",
        message:
            "⚠️ Formato Incompatible.\n\nAbra el archivo en Excel y guárdelo nuevamente como '.xlsx'.",
      );
    }
    return ApiResponse(status: "error", message: "Error leyendo Excel: $e");
  }

  Future<dynamic> _post(String accion, Map<String, dynamic> datos) async {
    datos['accion'] = accion;
    final response = await http.post(
      Uri.parse(ApiConfig.baseUrl),
      headers: ApiConfig.headers,
      body: jsonEncode(datos),
    );
    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json;
    }
    throw Exception("Error HTTP ${response.statusCode}");
  }

  Future<ApiResponse<dynamic>> _enviarRequest(Map<String, dynamic> body) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.baseUrl),
        headers: ApiConfig.headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        if (response.body.isEmpty)
          return ApiResponse(
            status: "error",
            message: "Respuesta vacía del servidor",
          );
        try {
          final json = jsonDecode(response.body);
          return ApiResponse(
            status: json['status'] ?? 'error',
            message: json['message'] ?? 'Sin mensaje',
            data: json['data'],
          );
        } catch (e) {
          return ApiResponse(
            status: "error",
            message: "Respuesta no válida del servidor.",
          );
        }
      } else {
        return ApiResponse(
          status: "error",
          message: "Error HTTP ${response.statusCode}",
        );
      }
    } catch (e) {
      return ApiResponse(status: "error", message: "Error de Conexión: $e");
    }
  }

  Future<ApiResponse<bool>> crearReporte(
    int idUsuario,
    int tipoReporte,
    String parametros,
  ) async {
    try {
      final body = jsonEncode({
        "accion": "crear_reporte",
        "id_usuario": idUsuario,
        "tipo_reporte": tipoReporte,
        "ruta":
            "ruta/temporal/pendiente.pdf",
        "parametros": parametros,
      });

      final response = await http.post(
        Uri.parse(ApiConfig.baseUrl),
        headers: ApiConfig.headers,
        body: body,
      );

      if (response.statusCode == 200) {
        final jsonMap = jsonDecode(response.body);

        return ApiResponse(
          status: jsonMap['status'],
          message: jsonMap['message'],
          data: jsonMap['status'] == 'success',
        );
      }
      return ApiResponse(status: "error", message: "Error al conectar");
    } catch (e) {
      return ApiResponse(status: "error", message: "Excepción: $e");
    }
  }

  Future<ApiResponse<bool>> firmarReporte(
    int idReporte,
    int idUsuario,
    int idRol,
  ) async {
    try {
      final body = {
        "accion": "cambiar_estado_reporte",
        "id_reporte": idReporte,
        "id_usuario": idUsuario,
        "id_rol": idRol,
      };
      final response = await http.post(
        Uri.parse(ApiConfig.baseUrl),
        headers: ApiConfig.headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return ApiResponse(
          status: json['status'],
          message: json['message'],
          data: json['status'] == 'success',
        );
      }
      return ApiResponse(
        status: "error",
        message: "HTTP ${response.statusCode}",
      );
    } catch (e) {
      return ApiResponse(status: "error", message: "Error: $e");
    }
  }

  Future<ApiResponse<bool>> firmarLote(
    List<int> ids,
    int idUsuario,
    int idRol,
  ) async {
    try {
      final body = {
        "accion": "firmar_lote_reportes",
        "ids": ids,
        "id_usuario": idUsuario,
        "id_rol": idRol,
      };
      final response = await http.post(
        Uri.parse(ApiConfig.baseUrl),
        headers: ApiConfig.headers,
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        return ApiResponse(
          status: json['status'],
          message: json['message'],
          data: json['status'] == 'success',
        );
      }
      return ApiResponse(
        status: "error",
        message: "HTTP ${response.statusCode}",
      );
    } catch (e) {
      return ApiResponse(status: "error", message: "Error: $e");
    }
  }

  Future<List<Map<String, dynamic>>> buscarEstudiantes(
    String anio,
    String query,
  ) async {
    final res = await _post("buscar_estudiantes_certificado", {
      "anio": anio,
      "busqueda": query,
    });
    return List<Map<String, dynamic>>.from(res['data']);
  }

  Future<Map<String, dynamic>> validarRequisitosCertificado(
    int idEstudiante,
    int idPeriodo,
  ) async {
    final res = await _post("validar_requisitos_certificado", {
      "id_estudiante": idEstudiante,
      "id_periodo": idPeriodo,
    });
    return res['data'];
  }

  Future<ApiResponse<dynamic>> generarCertificado({
    required int idUsuario,
    required int idEstudiante,
    required int idPeriodo,
    required String anio,
    bool force = false,
  }) async {
    try {
      final body = {
        "accion": "generar_certificado_estudios",
        "id_usuario": idUsuario,
        "id_estudiante": idEstudiante,
        "id_periodo": idPeriodo,
        "anio": anio,
        "force": force,
      };
      return await _enviarRequest(body);
    } catch (e) {
      return ApiResponse(status: "error", message: "Error: $e");
    }
  }

  Future<ApiResponse<Map<String, dynamic>>> obtenerDatosPdf(
    int idReporte,
  ) async {
    try {
      final res = await _post("obtener_datos_reporte", {
        "id_reporte": idReporte,
      });

      if (res['status'] == 'success' && res['data'] != null) {
        return ApiResponse(
          status: 'success',
          message: 'Datos cargados',
          data: Map<String, dynamic>.from(res['data']),
        );
      }
      return ApiResponse(status: 'error', message: res['message']);
    } catch (e) {
      return ApiResponse(status: "error", message: "Error: $e");
    }
  }
}