import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:frontend/Controller/auth_provider_controller.dart';
import 'package:frontend/Model/Services/reporte_service.dart';

import 'package:provider/provider.dart';

class ImportarArchivosView extends StatefulWidget {
  const ImportarArchivosView({super.key});

  @override
  State<ImportarArchivosView> createState() => _ImportarArchivosViewState();
}

class _ImportarArchivosViewState extends State<ImportarArchivosView> {
  String? _tipoArchivoSeleccionado;
  file_picker.PlatformFile? _archivoSeleccionado;
  bool _isUploading = false;
  final ReporteService _reporteService = ReporteService();

  final List<Map<String, dynamic>> _tiposArchivo = [
    {'id': '1', 'nombre': 'Reporte de Asistencia (Excel)'},
    {'id': '2', 'nombre': 'Reporte de Notas (Excel)'},
  ];

  Future<void> _seleccionarArchivo() async {
    try {
      file_picker.FilePickerResult? result =
          await file_picker.FilePicker.pickFiles(
            type: file_picker.FileType.custom,
            allowedExtensions: ['xlsx', 'xls'],
            withData: true,
          );

      if (result != null) {
        setState(() {
          _archivoSeleccionado = result.files.first;
        });
      }
    } catch (e) {
      _mostrarError("Error al seleccionar archivo: $e");
    }
  }

  Future<void> _enviarDatos() async {
    if (_tipoArchivoSeleccionado == null || _archivoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, complete todos los campos'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    final usuario = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).usuarioActual;

    if (usuario == null) {
      _mostrarError("Sesión no válida. Vuelva a iniciar sesión.");
      setState(() => _isUploading = false);
      return;
    }

    try {
      if (_tipoArchivoSeleccionado == '1') {
        await _procesarAsistenciaExcel(usuario.idUsuario);
      } else if (_tipoArchivoSeleccionado == '2') {
        await _procesarNotas(usuario.idUsuario);
      }
    } catch (e) {
      _mostrarError("Error inesperado: $e");
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  // --- Lógica: Procesar Asistencia ---
  Future<void> _procesarAsistenciaExcel(
    int idUsuario, {
    int? idDocenteForzado,
    bool force = false,
  }) async {
    final res = await _reporteService.enviarAsistenciaExcel(
      _archivoSeleccionado!,
      idUsuario,
      idDocente: idDocenteForzado,
      force: force,
    );

    if (!mounted) return;

    if (res.status == 'success') {
      _mostrarExito(res.message ?? "Asistencia cargada correctamente.");
    } else if (res.status == 'duplicate_warning') {
      final data = res.data as Map<String, dynamic>;
      _mostrarAlertaDuplicado(
        "Asistencia Existente",
        "Ya existe asistencia registrada para el mes de ${data['mes']}. Se encontraron ${data['total']} registros previos.\n\n¿Desea sobrescribirlos?",
        () {
          setState(() => _isUploading = true);
          _procesarAsistenciaExcel(
            idUsuario,
            idDocenteForzado: idDocenteForzado,
            force: true,
          ).whenComplete(() => setState(() => _isUploading = false));
        },
      );
    } else if (res.status == 'require_teacher_selection') {
      final dataMap = res.data as Map<String, dynamic>;
      _mostrarModalSeleccionDocente(
        dataMap['docentes'],
        "${dataMap['grado']} - ${dataMap['seccion']} (${dataMap['anio']})",
        // Callback para ASISTENCIA
        (idDocenteSeleccionado) {
          setState(() => _isUploading = true);
          _procesarAsistenciaExcel(
            idUsuario,
            idDocenteForzado: idDocenteSeleccionado,
          ).whenComplete(() => setState(() => _isUploading = false));
        },
      );
    } else {
      _mostrarError(res.message ?? "Error desconocido.", detalle: res.data);
    }
  }

  // --- Lógica: Procesar Notas ---
  Future<void> _procesarNotas(
    int idUsuario, {
    int? idDocenteForzado,
    bool force = false,
  }) async {
    final res = await _reporteService.enviarNotasExcel(
      _archivoSeleccionado!,
      idUsuario,
      idDocente: idDocenteForzado, // AHORA SE ENVÍA EL DOCENTE
      force: force,
    );

    if (!mounted) return;

    if (res.status == 'success') {
      _mostrarExito(res.message ?? "Notas cargadas correctamente.");
    } else if (res.status == 'duplicate_warning') {
      final data = res.data as Map<String, dynamic>;
      _mostrarAlertaDuplicado(
        "Notas Existentes",
        "Ya existen notas para el Bimestre ${data['bimestre']} en este salón. Se encontraron ${data['total']} calificaciones previas.\n\n¿Desea sobrescribirlas?",
        () {
          setState(() => _isUploading = true);
          _procesarNotas(
            idUsuario,
            idDocenteForzado: idDocenteForzado,
            force: true,
          ).whenComplete(() => setState(() => _isUploading = false));
        },
      );
    } else if (res.status == 'require_teacher_selection') {
      // AHORA NOTAS TAMBIÉN MANEJA ESTE ESTADO
      final dataMap = res.data as Map<String, dynamic>;
      _mostrarModalSeleccionDocente(
        dataMap['docentes'],
        "${dataMap['grado']} - ${dataMap['seccion']} (${dataMap['anio']})",
        // Callback para NOTAS
        (idDocenteSeleccionado) {
          setState(() => _isUploading = true);
          _procesarNotas(
            idUsuario,
            idDocenteForzado: idDocenteSeleccionado,
          ).whenComplete(() => setState(() => _isUploading = false));
        },
      );
    } else {
      _mostrarError(res.message ?? "Error al cargar notas", detalle: res.data);
    }
  }

  // --- Modales Genéricos ---

  void _mostrarAlertaDuplicado(
    String titulo,
    String mensaje,
    VoidCallback onConfirm,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
              size: 28,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                titulo,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(mensaje),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: const Text("Sí, Sobrescribir"),
          ),
        ],
      ),
    );
  }

  // MODAL GENÉRICO CON CALLBACK
  void _mostrarModalSeleccionDocente(
    List<dynamic> docentes,
    String salonInfo,
    Function(int) onGuardar,
  ) {
    int? docenteSeleccionado;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              title: Row(
                children: const [
                  Icon(Icons.school_outlined, color: Colors.blue),
                  SizedBox(width: 10),
                  Text(
                    "Nuevo Salón Detectado",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("El salón $salonInfo no está registrado en el sistema."),
                  const SizedBox(height: 15),
                  const Text(
                    "Seleccione el docente responsable:",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_outline),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                    ),
                    hint: const Text("Seleccionar Docente..."),
                    items: docentes.map<DropdownMenuItem<int>>((d) {
                      return DropdownMenuItem<int>(
                        value: int.parse(d['id_docente'].toString()),
                        child: Text(d['nombre_completo']),
                      );
                    }).toList(),
                    onChanged: (val) =>
                        setStateModal(() => docenteSeleccionado = val),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text("Cancelar"),
                ),
                ElevatedButton.icon(
                  onPressed: docenteSeleccionado == null
                      ? null
                      : () {
                          Navigator.pop(ctx);
                          // Ejecutar el callback específico (sea notas o asistencia)
                          onGuardar(docenteSeleccionado!);
                        },
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text("Guardar y Procesar"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _mostrarExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 10),
            Expanded(child: Text(mensaje)),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
    setState(() {
      _archivoSeleccionado = null;
    });
  }

  void _mostrarError(String msg, {dynamic detalle}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(
          "Hubo un problema",
          style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(msg),
            if (detalle != null) ...[
              const SizedBox(height: 15),
              const Text(
                "Detalle técnico:",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 5),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Text(
                  detalle.toString(),
                  style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Entendido"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Importación Masiva SIAGIE",
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Sube los reportes oficiales en Excel para cargar Asistencias y Notas automáticamente.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 32),

          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.cloud_upload_outlined,
                        color: theme.colorScheme.secondary,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "Carga de Archivos",
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    "Seleccione el tipo de documento y adjunte el archivo Excel (.xlsx).",
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: Colors.grey,
                    ),
                  ),
                  const Divider(height: 30, thickness: 1),

                  Text(
                    "Tipo de Archivo",
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _tipoArchivoSeleccionado,
                    decoration: InputDecoration(
                      hintText: "Seleccione el tipo de reporte",
                      prefixIcon: const Icon(Icons.folder_open_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                    items: _tiposArchivo
                        .map(
                          (t) => DropdownMenuItem(
                            value: t['id'].toString(),
                            child: Text(t['nombre']),
                          ),
                        )
                        .toList(),
                    onChanged: (val) =>
                        setState(() => _tipoArchivoSeleccionado = val),
                  ),

                  const SizedBox(height: 24),

                  Text(
                    "Documento Adjunto",
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _seleccionarArchivo,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 30,
                        horizontal: 20,
                      ),
                      decoration: BoxDecoration(
                        color: _archivoSeleccionado != null
                            ? Colors.green.withOpacity(0.05)
                            : Colors.grey.withOpacity(0.05),
                        border: Border.all(
                          color: _archivoSeleccionado != null
                              ? Colors.green
                              : Colors.grey.withOpacity(0.4),
                          width: 1.5,
                          style: BorderStyle.solid,
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            _archivoSeleccionado != null
                                ? Icons.description
                                : Icons.upload_file,
                            size: 48,
                            color: _archivoSeleccionado != null
                                ? Colors.green[600]
                                : Colors.grey[500],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _archivoSeleccionado?.name ??
                                "Haz clic para seleccionar el archivo Excel",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: _archivoSeleccionado != null
                                  ? Colors.black87
                                  : Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                          if (_archivoSeleccionado == null)
                            Text(
                              "(Formatos soportados: .xlsx, .xls)",
                              style: TextStyle(
                                color: Colors.grey[400],
                                fontSize: 12,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed:
                          (_isUploading ||
                              _archivoSeleccionado == null ||
                              _tipoArchivoSeleccionado == null)
                          ? null
                          : _enviarDatos,
                      icon: _isUploading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(
                        _isUploading ? "Procesando..." : "Procesar Archivo",
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        disabledBackgroundColor: Colors.grey[300],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
