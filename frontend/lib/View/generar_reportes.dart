import 'package:flutter/material.dart';
import 'package:frontend/Controller/auth_provider_controller.dart';
import 'package:frontend/Model/Services/reporte_service.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class GenerarReportesView extends StatefulWidget {
  const GenerarReportesView({super.key});

  @override
  State<GenerarReportesView> createState() => _GenerarReportesViewState();
}

class _GenerarReportesViewState extends State<GenerarReportesView> {
  final _formKey = GlobalKey<FormState>();
  final ReporteService _service = ReporteService();
  bool _isLoading = false;


  String? _tipoReporte = 'Boleta de Notas';
  String? _anioSeleccionado;
  String? _nivelSeleccionado;
  int? _idSalonSeleccionado;
  int? _bimestreSeleccionado;


  Map<String, dynamic>? _estudianteSeleccionado;
  bool _certificadoApto = false;
  String _certificadoMensaje = "";
  List<dynamic> _certificadoAdvertencias = [];

  final TextEditingController _fechaInicioCtrl = TextEditingController();
  final TextEditingController _fechaFinCtrl = TextEditingController();
  final TextEditingController _estudianteCtrl = TextEditingController();


  List<String> _anios = [];
  List<String> _niveles = [];
  List<Map<String, dynamic>> _salones = [];
  List<String> _bimestres = [];

  @override
  void initState() {
    super.initState();
    _cargarAnios();
  }


  Future<void> _cargarAnios() async {
    try {
      final data = await _service.getAnios();
      if (mounted) setState(() => _anios = data);
    } catch (e) {}
  }

  Future<void> _cargarNiveles(String anio) async {
    setState(() {
      _nivelSeleccionado = null;
      _idSalonSeleccionado = null;
      _bimestreSeleccionado = null;
      _niveles = [];
      _salones = [];
      _bimestres = [];
    });
    try {
      final data = await _service.getNiveles(anio);
      if (mounted) setState(() => _niveles = data);
    } catch (e) {}
  }

  Future<void> _cargarSalones(String nivel) async {
    setState(() {
      _idSalonSeleccionado = null;
      _bimestreSeleccionado = null;
      _salones = [];
      _bimestres = [];
    });
    if (_tipoReporte == 'Reporte de Rendimiento') {
      _cargarBimestresNivel(nivel);
    } else {
      try {
        final data = await _service.getSalones(_anioSeleccionado!, nivel);
        if (mounted) setState(() => _salones = data);
      } catch (e) {}
    }
  }

  Future<void> _cargarBimestresSalon(int idPeriodo) async {
    setState(() {
      _bimestreSeleccionado = null;
      _bimestres = [];
    });
    try {
      final data = await _service.getBimestres(idPeriodo);
      if (mounted) setState(() => _bimestres = data);
    } catch (e) {}
  }

  Future<void> _cargarBimestresNivel(String nivel) async {
    try {
      final data = await _service.getBimestresPorNivel(
        _anioSeleccionado!,
        nivel,
      );
      if (mounted) setState(() => _bimestres = data);
    } catch (e) {}
  }


  Future<void> _seleccionarEstudiante(Map<String, dynamic> estudiante) async {
    setState(() {
      _estudianteSeleccionado = estudiante;
      _estudianteCtrl.text = estudiante['nombre_completo'];
      _certificadoApto = false;
      _certificadoMensaje = "Verificando requisitos...";
    });

    try {
      final data = await _service.validarRequisitosCertificado(
        int.parse(estudiante['id_estudiante'].toString()),
        int.parse(estudiante['id_periodo'].toString()),
      );

      if (mounted) {
        setState(() {
          _certificadoApto = data['apto'];
          _certificadoMensaje = data['mensaje'];
          _certificadoAdvertencias = data['advertencias_grado'] ?? [];
        });
      }
    } catch (e) {
      setState(() => _certificadoMensaje = "Error validando: $e");
    }
  }


  Future<void> _generarReporte({
    bool force = false,
    bool ignoreMissing = false,
  }) async {
    if (!_formKey.currentState!.validate()) {
      _mostrarSnack("Complete campos obligatorios");
      return;
    }

    if (_tipoReporte == 'Certificado de Estudios') {
      if (_estudianteSeleccionado == null) {
        _mostrarSnack("Seleccione un estudiante");
        return;
      }
      if (!_certificadoApto) {
        _mostrarError("No Apto", detalle: _certificadoMensaje);
        return;
      }
    } else {
      DateTime start = DateTime.parse(_fechaInicioCtrl.text);
      DateTime end = DateTime.parse(_fechaFinCtrl.text);
      if (start.isAfter(end)) {
        _mostrarError("Fechas Inválidas", detalle: "Inicio > Fin");
        return;
      }
    }

    if (!force && !ignoreMissing) {
      if (!await _pedirConfirmacionInicial()) return;
    }

    setState(() => _isLoading = true);
    final usuario = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).usuarioActual;

    try {
      dynamic res;

      if (_tipoReporte == 'Boleta de Notas') {
        res = await _service.generarBoletaNotas(
          idUsuario: usuario!.idUsuario,
          idPeriodo: _idSalonSeleccionado!,
          bimestre: _bimestreSeleccionado!,
          fechaInicio: _fechaInicioCtrl.text,
          fechaFin: _fechaFinCtrl.text,
          force: force,
        );
      } else if (_tipoReporte == 'Reporte de Rendimiento') {
        res = await _service.generarReporteRendimiento(
          idUsuario: usuario!.idUsuario,
          anio: _anioSeleccionado!,
          nivel: _nivelSeleccionado!,
          bimestre: _bimestreSeleccionado!,
          fechaInicio: _fechaInicioCtrl.text,
          fechaFin: _fechaFinCtrl.text,
          force: force,
          ignoreMissing: ignoreMissing,
        );
      } else if (_tipoReporte == 'Certificado de Estudios') {
        res = await _service.generarCertificado(
          idUsuario: usuario!.idUsuario,
          idEstudiante: int.parse(
            _estudianteSeleccionado!['id_estudiante'].toString(),
          ),
          idPeriodo: int.parse(
            _estudianteSeleccionado!['id_periodo'].toString(),
          ),
          anio: _anioSeleccionado!,
          force: force,
        );
      }

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (res.status == 'success') {
        _mostrarExito("Reporte Generado", res.message ?? "Éxito");
      } else if (res.status == 'duplicate_warning') {
        _mostrarAlertaDuplicado(
          res.message!,
          () => _generarReporte(force: true, ignoreMissing: ignoreMissing),
        );
      } else if (res.status == 'integrity_warning') {
        final data = res.data as Map<String, dynamic>;
        final lista = List<String>.from(data['faltantes']);
        _mostrarAlertaIntegridad(
          "Faltan Datos",
          "Los siguientes salones...\n\n• ${lista.join('\n• ')}",
          () => _generarReporte(ignoreMissing: true, force: force),
        );
      } else {
        _mostrarError("Error", detalle: res.message);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _mostrarError("Error conexión", detalle: e);
    }
  }


  Future<bool> _pedirConfirmacionInicial() async {
    String msg = "";
    if (_tipoReporte == 'Certificado de Estudios')
      msg =
          "Generar CERTIFICADO para ${_estudianteSeleccionado!['nombre_completo']}.";
    else if (_tipoReporte == 'Boleta de Notas')
      msg = "Generar BOLETAS para el salón seleccionado.";
    else
      msg = "Generar REPORTE DE RENDIMIENTO para el nivel $_nivelSeleccionado.";

    return await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: Row(
              children: const [
                Icon(Icons.help_outline, color: Colors.blue, size: 32),
                SizedBox(width: 15),
                Text(
                  "Confirmar",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              child: Text(
                "$msg\n\n¿Continuar?",
                style: const TextStyle(fontSize: 16),
              ),
            ),
            actionsPadding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 20,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text(
                  "Cancelar",
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(c, true),
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text(
                  "Sí, Generar",
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 25,
                    vertical: 15,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _mostrarExito(String t, String m) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 32),
            const SizedBox(width: 15),
            Text(
              t,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Text(m, style: const TextStyle(fontSize: 16)),
        ),
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 20,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("Aceptar", style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  void _mostrarError(String t, {dynamic detalle}) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 32),
            const SizedBox(width: 15),
            Text(
              t,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: SingleChildScrollView(
            child: Text(
              detalle.toString(),
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 20,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("Cerrar", style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  void _mostrarSnack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(m),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _mostrarAlertaIntegridad(String t, String m, VoidCallback ok) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            const Icon(
              Icons.assignment_late_outlined,
              color: Colors.orange,
              size: 32,
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                t,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          height: 300,
          child: SingleChildScrollView(
            child: Text(m, style: const TextStyle(fontSize: 16)),
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 20,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text(
              "Cancelar",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(c);
              ok();
            },
            child: const Text(
              "Ignorar y Generar",
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarAlertaDuplicado(String m, VoidCallback ok) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            const Icon(
              Icons.warning_amber_rounded,
              color: Colors.redAccent,
              size: 32,
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Text(
                "Reporte Existente",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Text(m, style: const TextStyle(fontSize: 16)),
        ),
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: 24,
          vertical: 20,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text(
              "Cancelar",
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(c);
              ok();
            },
            child: const Text("Sobrescribir", style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Future<void> _seleccionarFecha(TextEditingController c) async {
    DateTime? p = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: Theme.of(context).primaryColor,
          ),
          dialogTheme: const DialogThemeData(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(15)),
            ),
          ),
        ),
        child: child!,
      ),
    );
    if (p != null) c.text = DateFormat('yyyy-MM-dd').format(p);
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);


    InputDecoration inputDeco(String label, IconData icon) {
      return InputDecoration(
        labelText: label,
        hintText: "Seleccione $label",
        prefixIcon: Icon(icon, size: 22),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        filled: true,
        fillColor: Colors.white,
      );
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            Text(
              "Generación de Reportes",
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                fontSize: 28,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Configure los parámetros para generar boletas, actas y certificados oficiales.",
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
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [

                      Row(
                        children: [
                          Icon(
                            Icons.print_outlined,
                            color: theme.colorScheme.secondary,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            "Configuración del Reporte",
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        "Seleccione el tipo de documento y aplique los filtros.",
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                      const Divider(height: 30, thickness: 1),


                      Text(
                        "Tipo de Documento",
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _tipoReporte,
                        decoration: inputDeco(
                          "Tipo",
                          Icons.assignment_outlined,
                        ),
                        items:
                            [
                                  'Boleta de Notas',
                                  'Reporte de Rendimiento',
                                  'Certificado de Estudios',
                                ]
                                .map(
                                  (t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(t),
                                  ),
                                )
                                .toList(),
                        onChanged: (val) {
                          setState(() {
                            _tipoReporte = val;
                            _anioSeleccionado = null;
                            _nivelSeleccionado = null;
                            _estudianteSeleccionado = null;
                            _estudianteCtrl.clear();
                          });
                        },
                      ),
                      const SizedBox(height: 24),


                      Text(
                        "Año Académico",
                        style: theme.textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _anioSeleccionado,
                        decoration: inputDeco("Año", Icons.calendar_today),
                        items: _anios
                            .map(
                              (a) => DropdownMenuItem(value: a, child: Text(a)),
                            )
                            .toList(),
                        onChanged: (val) {
                          setState(() => _anioSeleccionado = val);
                          _cargarNiveles(val!);
                        },
                        validator: (v) => v == null ? 'Requerido' : null,
                      ),
                      const SizedBox(height: 24),


                      if (_tipoReporte == 'Certificado de Estudios') ...[
                        if (_anioSeleccionado != null) ...[
                          Text(
                            "Estudiante",
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Autocomplete<Map<String, dynamic>>(
                            optionsBuilder: (text) async {
                              if (text.text.length < 3) return [];
                              return await _service.buscarEstudiantes(
                                _anioSeleccionado!,
                                text.text,
                              );
                            },
                            displayStringForOption: (op) =>
                                op['nombre_completo'],
                            onSelected: _seleccionarEstudiante,
                            fieldViewBuilder:
                                (ctx, controller, focus, onSubmit) {
                                  return TextFormField(
                                    controller: controller,
                                    focusNode: focus,
                                    decoration: inputDeco(
                                      "Buscar (mín. 3 letras)",
                                      Icons.person_search,
                                    ),
                                  );
                                },
                          ),
                          const SizedBox(height: 20),

                          if (_estudianteSeleccionado != null)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: _certificadoApto
                                    ? Colors.green[50]
                                    : Colors.red[50],
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: _certificadoApto
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Estudiante: ${_estudianteSeleccionado!['nombre_completo']}",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    "Ubicación: ${_estudianteSeleccionado!['grado']} - ${_estudianteSeleccionado!['seccion']} (${_estudianteSeleccionado!['nivel']})",
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      Icon(
                                        _certificadoApto
                                            ? Icons.check_circle
                                            : Icons.cancel,
                                        color: _certificadoApto
                                            ? Colors.green
                                            : Colors.red,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          _certificadoMensaje,
                                          style: TextStyle(
                                            color: _certificadoApto
                                                ? Colors.green[800]
                                                : Colors.red[800],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (_certificadoAdvertencias.isNotEmpty) ...[
                                    const SizedBox(height: 10),
                                    const Text(
                                      "Advertencias:",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    ..._certificadoAdvertencias.map(
                                      (a) => Text(
                                        "• $a",
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                        ],
                      ]

                      else ...[
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Nivel",
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<String>(
                                    value: _nivelSeleccionado,
                                    decoration: inputDeco(
                                      "Nivel",
                                      Icons.school,
                                    ),
                                    items: _niveles
                                        .map(
                                          (n) => DropdownMenuItem(
                                            value: n,
                                            child: Text(n),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) {
                                      setState(() => _nivelSeleccionado = v);
                                      _cargarSalones(v!);
                                    },
                                    validator: (v) => v == null ? 'Req' : null,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Bimestre",
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  DropdownButtonFormField<int>(
                                    value: _bimestreSeleccionado,
                                    decoration: inputDeco(
                                      "Bim.",
                                      Icons.filter_3,
                                    ),
                                    items: _bimestres
                                        .map(
                                          (b) => DropdownMenuItem(
                                            value: int.parse(b),
                                            child: Text("Bimestre $b"),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (v) => setState(
                                      () => _bimestreSeleccionado = v,
                                    ),
                                    validator: (v) => v == null ? 'Req' : null,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        if (_tipoReporte == 'Boleta de Notas') ...[
                          Text(
                            "Salón (Grado y Sección)",
                            style: theme.textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<int>(
                            value: _idSalonSeleccionado,
                            decoration: inputDeco(
                              "Salón",
                              Icons.class_outlined,
                            ),
                            items: _salones
                                .map(
                                  (s) => DropdownMenuItem(
                                    value: int.parse(
                                      s['id_periodo'].toString(),
                                    ),
                                    child: Text(
                                      s['nombre'],
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) {
                              setState(() => _idSalonSeleccionado = v);
                              _cargarBimestresSalon(v!);
                            },
                            validator: (v) => v == null ? 'Requerido' : null,
                          ),
                          const SizedBox(height: 20),
                        ],


                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Fecha Inicio",
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _fechaInicioCtrl,
                                    decoration: inputDeco(
                                      "Desde",
                                      Icons.date_range,
                                    ),
                                    readOnly: true,
                                    onTap: () =>
                                        _seleccionarFecha(_fechaInicioCtrl),
                                    validator: (v) => v!.isEmpty ? 'Req' : null,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Fecha Fin",
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  TextFormField(
                                    controller: _fechaFinCtrl,
                                    decoration: inputDeco(
                                      "Hasta",
                                      Icons.event_busy,
                                    ),
                                    readOnly: true,
                                    onTap: () =>
                                        _seleccionarFecha(_fechaFinCtrl),
                                    validator: (v) => v!.isEmpty ? 'Req' : null,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _isLoading
                              ? null
                              : (_tipoReporte == 'Certificado de Estudios' &&
                                    !_certificadoApto)
                              ? null
                              : () => _generarReporte(),
                          icon: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                )
                              : const Icon(Icons.picture_as_pdf),
                          label: Text(
                            _isLoading ? "Procesando..." : "Generar Reporte",
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
            ),
          ],
        ),
      ),
    );
  }
}
