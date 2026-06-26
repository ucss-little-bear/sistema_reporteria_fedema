// CR-SDRF-4: Se integró 'desktop_drop' y 'dotted_border' para el módulo Drag & Drop.
// Se mantiene la estructura original de UI, pero con reactividad y validación de cliente.
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart' as file_picker;
import 'package:desktop_drop/desktop_drop.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:frontend/Controller/auth_provider_controller.dart';
import 'package:frontend/Model/Services/reporte_service.dart';
import 'package:provider/provider.dart';

class ImportarArchivosView extends StatefulWidget {
  const ImportarArchivosView({super.key});

  @override
  State<ImportarArchivosView> createState() => _ImportarArchivosViewState();
}

// CR-SDRF-4: SingleTickerProviderStateMixin añadido para orquestar la animación de temblor (Shake)
class _ImportarArchivosViewState extends State<ImportarArchivosView> with SingleTickerProviderStateMixin {
  String? _tipoArchivoSeleccionado;
  file_picker.PlatformFile? _archivoSeleccionado;
  bool _isUploading = false;
  
  // Variables reactivas para el Drag & Drop
  bool _isDragging = false; 
  bool _isDragValid = true; 
  String _dragErrorMessage = ""; 
  
  // Controladores del efecto Shake para retroalimentación de error
  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;
  
  final ReporteService _reporteService = ReporteService();

  // Textos originales conservados según requerimiento
  final List<Map<String, dynamic>> _tiposArchivo = [
    {'id': '1', 'nombre': 'Reporte de Asistencia (Excel)'},
    {'id': '2', 'nombre': 'Reporte de Notas (Excel)'},
  ];

  @override
  void initState() {
    super.initState();
    // CR-SDRF-4: Curva matemática para simular un temblor horizontal en caso de error
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 10.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 10.0, end: -10.0), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -10.0, end: 0.0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shakeController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _triggerErrorShake() {
    _shakeController.forward(from: 0.0);
  }

  // CR-SDRF-4: Método fallback de clic con validación de peso inyectada
  Future<void> _seleccionarArchivo() async {
    if (_tipoArchivoSeleccionado == null) {
      setState(() {
        _isDragValid = false;
        _dragErrorMessage = "Por favor, seleccione primero el Tipo de Archivo arriba.";
      });
      _triggerErrorShake();
      return;
    }

    try {
      file_picker.FilePickerResult? result =
          await file_picker.FilePicker.pickFiles(
            type: file_picker.FileType.custom,
            allowedExtensions: ['xlsx', 'xls'],
            withData: true, 
          );

      if (result != null) {
        if (result.files.first.size > 5 * 1024 * 1024) {
          setState(() {
            _archivoSeleccionado = null;
            _isDragValid = false;
            _dragErrorMessage = "El archivo seleccionado supera el límite de 5MB.";
          });
          _triggerErrorShake();
          return;
        }

        setState(() {
          _isDragValid = true;
          _dragErrorMessage = "";
          _archivoSeleccionado = result.files.first;
        });
      }
    } catch (e) {
      debugPrint("Error al seleccionar archivo: $e");
    }
  }

  void _iniciarArrastre(DropEventDetails details) {
    setState(() => _isDragging = true);
  }

  void _terminarArrastre(DropEventDetails details) {
    setState(() => _isDragging = false);
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

    final usuario = Provider.of<AuthProvider>(context, listen: false).usuarioActual;

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

  Future<void> _procesarNotas(
    int idUsuario, {
    int? idDocenteForzado,
    bool force = false,
  }) async {
    final res = await _reporteService.enviarNotasExcel(
      _archivoSeleccionado!,
      idUsuario,
      idDocente: idDocenteForzado,
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
      final dataMap = res.data as Map<String, dynamic>;
      _mostrarModalSeleccionDocente(
        dataMap['docentes'],
        "${dataMap['grado']} - ${dataMap['seccion']} (${dataMap['anio']})",
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

  void _mostrarAlertaDuplicado(String titulo, String mensaje, VoidCallback onConfirm) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
            const SizedBox(width: 10),
            Expanded(child: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold))),
          ],
        ),
        content: Text(mensaje),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
            onPressed: () { Navigator.pop(ctx); onConfirm(); },
            child: const Text("Sí, Sobrescribir"),
          ),
        ],
      ),
    );
  }

  void _mostrarModalSeleccionDocente(List<dynamic> docentes, String salonInfo, Function(int) onGuardar) {
    int? docenteSeleccionado;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.school_outlined, color: Colors.blue),
                  SizedBox(width: 10),
                  Text("Nuevo Salón Detectado", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("El salón $salonInfo no está registrado en el sistema."),
                  const SizedBox(height: 15),
                  const Text("Seleccione el docente responsable:", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<int>(
                    isExpanded: true,
                    decoration: const InputDecoration(border: OutlineInputBorder(), prefixIcon: Icon(Icons.person_outline), contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14)),
                    hint: const Text("Seleccionar Docente..."),
                    items: docentes.map<DropdownMenuItem<int>>((d) {
                      return DropdownMenuItem<int>(value: int.parse(d['id_docente'].toString()), child: Text(d['nombre_completo']));
                    }).toList(),
                    onChanged: (val) => setStateModal(() => docenteSeleccionado = val),
                  ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
                ElevatedButton.icon(
                  onPressed: docenteSeleccionado == null ? null : () { Navigator.pop(ctx); onGuardar(docenteSeleccionado!); },
                  icon: const Icon(Icons.save, size: 18),
                  label: const Text("Guardar y Procesar"),
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor, foregroundColor: Colors.white),
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
    setState(() => _archivoSeleccionado = null);
  }

  void _mostrarError(String msg, {dynamic detalle}) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Hubo un problema", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(msg),
            if (detalle != null) ...[
              const SizedBox(height: 15),
              const Text("Detalle técnico:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 5),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey[300]!)),
                child: Text(detalle.toString(), style: const TextStyle(fontSize: 11, fontFamily: 'monospace'), maxLines: 5, overflow: TextOverflow.ellipsis),
              ),
            ],
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Entendido"))],
      ),
    );
  }

  // CR-SDRF-4: Lógica condicional de colores para UX visual
  Color _getDropZoneBorderColor() {
    if (_isDragging) return Theme.of(context).primaryColor;
    if (!_isDragValid && _archivoSeleccionado == null) return Colors.redAccent;
    return _archivoSeleccionado != null ? Colors.green : Colors.grey.withOpacity(0.5);
  }

  Color _getDropZoneBgColor() {
    if (_isDragging) return Theme.of(context).primaryColor.withOpacity(0.12);
    if (!_isDragValid && _archivoSeleccionado == null) return Colors.red.withOpacity(0.06);
    return _archivoSeleccionado != null ? Colors.green.withOpacity(0.06) : Colors.transparent;
  }

  IconData _getDropZoneIcon() {
    if (_isDragging) return Icons.download_rounded;
    if (!_isDragValid && _archivoSeleccionado == null) return Icons.error_outline_rounded;
    return _archivoSeleccionado != null ? Icons.check_circle_outline_rounded : Icons.cloud_upload_outlined;
  }

  Color _getDropZoneIconColor() {
    if (_isDragging) return Theme.of(context).primaryColor;
    if (!_isDragValid && _archivoSeleccionado == null) return Colors.redAccent;
    return _archivoSeleccionado != null ? Colors.green : Colors.grey[500]!;
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
              fontWeight: FontWeight.bold, color: Colors.black87, fontSize: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Sube los reportes oficiales en Excel para cargar Asistencias y Notas automáticamente.",
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 32),

          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.cloud_upload_outlined, color: theme.colorScheme.secondary, size: 28),
                      const SizedBox(width: 12),
                      Text("Carga de Archivos", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text("Seleccione el tipo de documento y adjunte el archivo Excel (.xlsx).", style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
                  const Divider(height: 30, thickness: 1),

                  Text("Tipo de Archivo", style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _tipoArchivoSeleccionado,
                    decoration: InputDecoration(
                      hintText: "Seleccione el tipo de reporte",
                      prefixIcon: const Icon(Icons.folder_open_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    ),
                    items: _tiposArchivo.map((t) => DropdownMenuItem(value: t['id'].toString(), child: Text(t['nombre']))).toList(),
                    onChanged: (val) {
                      setState(() {
                        _tipoArchivoSeleccionado = val;
                        _archivoSeleccionado = null; 
                        _isDragValid = true;
                        _dragErrorMessage = "";
                      });
                    },
                  ),

                  const SizedBox(height: 24),

                  Text("Documento Adjunto", style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  
                  // CR-SDRF-4: Implementación del Drag & Drop interactivo
                  DropTarget(
                    onDragEntered: _iniciarArrastre,
                    onDragUpdated: _iniciarArrastre,
                    onDragExited: _terminarArrastre,
                    onDragDone: (details) async {
                      setState(() => _isDragging = false);

                      if (_tipoArchivoSeleccionado == null) {
                        setState(() {
                          _archivoSeleccionado = null;
                          _isDragValid = false;
                          _dragErrorMessage = "Por favor, seleccione el Tipo de Archivo arriba primero.";
                        });
                        _triggerErrorShake();
                        return;
                      }
                      
                      if (details.files.isNotEmpty) {
                        final file = details.files.first;
                        final fileName = file.name;
                        
                        // CR-SDRF-4: Regex Sanitizer - Limpia caracteres invisibles/especiales que inyecta Flutter Web al arrastrar
                        final rawExtension = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
                        final extensionLimpia = rawExtension.replaceAll(RegExp(r'[^a-z0-9]'), '');
                        
                        // Validación estricta únicamente contra las extensiones Excel oficiales
                        if (extensionLimpia != 'xlsx' && extensionLimpia != 'xls') {
                          setState(() {
                            _archivoSeleccionado = null;
                            _isDragValid = false;
                            // Imprimimos la extensión limpia para transparencia en caso de error
                            _dragErrorMessage = "Formato inválido (.$extensionLimpia). Solo se admiten archivos .xls o .xlsx";
                          });
                          _triggerErrorShake();
                          return;
                        }

                        // Validación de peso máximo de 5MB
                        final tamano = await file.length();
                        if (tamano > 5 * 1024 * 1024) {
                          setState(() {
                            _archivoSeleccionado = null;
                            _isDragValid = false;
                            _dragErrorMessage = "El archivo excede el límite máximo de 5MB.";
                          });
                          _triggerErrorShake();
                          return;
                        }

                        final bytes = await file.readAsBytes();
                        
                        setState(() {
                          _isDragValid = true;
                          _dragErrorMessage = "";
                          _archivoSeleccionado = file_picker.PlatformFile(name: fileName, size: tamano, bytes: bytes);
                        });
                      }
                    },
                    child: AnimatedBuilder(
                      animation: _shakeAnimation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(_shakeAnimation.value, 0),
                          child: child,
                        );
                      },
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          AnimatedScale(
                            scale: _isDragging ? 1.02 : 1.0, 
                            duration: const Duration(milliseconds: 150),
                            curve: Curves.easeInOut,
                            child: InkWell(
                              onTap: _seleccionarArchivo,
                              borderRadius: BorderRadius.circular(10),
                              child: DottedBorder(
                                borderType: BorderType.RRect,
                                radius: const Radius.circular(10),
                                padding: EdgeInsets.zero,
                                color: _getDropZoneBorderColor(),
                                strokeWidth: _isDragging ? 2.5 : 1.5,
                                dashPattern: _isDragging ? [10, 0] : [8, 4], 
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(vertical: 35, horizontal: 20),
                                  decoration: BoxDecoration(
                                    color: _getDropZoneBgColor(),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Column(
                                    children: [
                                      AnimatedSwitcher(
                                        duration: const Duration(milliseconds: 250),
                                        transitionBuilder: (child, animation) => ScaleTransition(scale: animation, child: child),
                                        child: Icon(
                                          _getDropZoneIcon(),
                                          key: ValueKey<IconData>(_getDropZoneIcon()),
                                          size: 52,
                                          color: _getDropZoneIconColor(),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _archivoSeleccionado?.name ??
                                            (_dragErrorMessage.isNotEmpty 
                                                ? _dragErrorMessage 
                                                : "Arrastra tu archivo aquí o haz clic para seleccionar"),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: (!_isDragValid && _archivoSeleccionado == null)
                                              ? Colors.redAccent 
                                              : (_archivoSeleccionado != null ? Colors.green[800] : Colors.grey[700]),
                                          fontSize: 15,
                                        ),
                                      ),
                                      if (_archivoSeleccionado == null && _dragErrorMessage.isEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: Text(
                                            "(Formatos soportados: .xlsx, .xls | Max: 5MB)",
                                            style: TextStyle(color: Colors.grey[400], fontSize: 12),
                                          ),
                                        ),
                                      if (_archivoSeleccionado != null)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
                                            child: Text(
                                              "${(_archivoSeleccionado!.size / 1024 / 1024).toStringAsFixed(2)} MB",
                                              style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (_archivoSeleccionado != null)
                            Positioned(
                              top: 12,
                              right: 12,
                              child: IconButton(
                                icon: const Icon(Icons.cancel, color: Colors.redAccent),
                                tooltip: 'Eliminar archivo',
                                onPressed: () {
                                  setState(() {
                                    _archivoSeleccionado = null;
                                    _isDragValid = true; 
                                    _dragErrorMessage = "";
                                  });
                                },
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
                          (_isUploading || _archivoSeleccionado == null || _tipoArchivoSeleccionado == null)
                              ? null
                              : _enviarDatos,
                      icon: _isUploading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Icon(Icons.send_rounded),
                      label: Text(
                        _isUploading ? "Procesando..." : "Procesar Archivo",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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