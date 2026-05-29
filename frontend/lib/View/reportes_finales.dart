import 'package:flutter/material.dart';
import 'package:frontend/Controller/auth_provider_controller.dart';
import 'package:frontend/Model/Entities/reporte_entity.dart';
import 'package:frontend/Model/Services/pdf_generator_service.dart';
import 'package:frontend/Model/Services/reporte_service.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart'; // Para compartir/descargar PDF
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';

class ReportesFinalesView extends StatefulWidget {
  const ReportesFinalesView({super.key});

  @override
  State<ReportesFinalesView> createState() => _ReportesFinalesViewState();
}

class _ReportesFinalesViewState extends State<ReportesFinalesView>
    with SingleTickerProviderStateMixin {
  final ReporteService _service = ReporteService();
  final PdfGeneratorService _pdfService = PdfGeneratorService();

  bool _isLoading = true;

  // Datos Originales (Sin Filtrar)
  List<Reporte> _boletasOriginales = [];
  List<Reporte> _rendimientoOriginales = [];
  List<Reporte> _certificadosOriginales = [];

  // Datos Filtrados (Para mostrar)
  Map<String, List<Reporte>> _boletasFiltradasGroup = {};
  List<Reporte> _rendimientoFiltrados = [];
  List<Reporte> _certificadosFiltrados = [];

  // Controladores de Busqueda
  final TextEditingController _searchBoletas = TextEditingController();
  final TextEditingController _searchRendimiento = TextEditingController();
  final TextEditingController _searchCertificados = TextEditingController();

  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _setupSearchListeners();
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarReportes());
  }

  void _setupSearchListeners() {
    _searchBoletas.addListener(() => _filtrarBoletas());
    _searchRendimiento.addListener(() => _filtrarRendimiento());
    _searchCertificados.addListener(() => _filtrarCertificados());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchBoletas.dispose();
    _searchRendimiento.dispose();
    _searchCertificados.dispose();
    super.dispose();
  }

  // --- CARGA DE DATOS ---
  Future<void> _cargarReportes() async {
    setState(() => _isLoading = true);
    final usuario = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).usuarioActual;
    if (usuario == null) return;

    try {
      final res = await _service.listarReportes(
        usuario.idUsuario,
        usuario.idRol,
      );
      if (res.status == 'success' && res.data != null) {
        final finales = res.data!.where((r) => r.idEstadoReporte == 3).toList();

        _boletasOriginales = finales
            .where((r) => r.tipoReporte == 'Boleta de Notas')
            .toList();
        _rendimientoOriginales = finales
            .where((r) => r.tipoReporte == 'Reporte de Rendimiento')
            .toList();
        _certificadosOriginales = finales
            .where((r) => r.tipoReporte == 'Certificado de Estudios')
            .toList();

        // Inicializar filtros
        _filtrarBoletas();
        _filtrarRendimiento();
        _filtrarCertificados();
      } else {
        _mostrarError("Error al cargar", detalle: res.message);
      }
    } catch (e) {
      _mostrarError("Error de conexión", detalle: e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- LÓGICA DE FILTRADO ---

  void _filtrarBoletas() {
    String query = _searchBoletas.text.toLowerCase();
    Map<String, List<Reporte>> agrupado = {};

    for (var r in _boletasOriginales) {
      // Construir string de búsqueda con todos los campos requeridos
      String searchable = _construirSearchStringBoleta(r).toLowerCase();

      if (searchable.contains(query)) {
        String key = r.informacionAdicional ?? "Otros";
        if (!agrupado.containsKey(key)) agrupado[key] = [];
        agrupado[key]!.add(r);
      }
    }
    setState(() => _boletasFiltradasGroup = agrupado);
  }

  String _construirSearchStringBoleta(Reporte r) {
    // Parametros: Alumno, Matricula
    // Info: Año, Nivel, Grado, Seccion, Bimestre, Docente
    String p = r.parametros ?? "";
    String i = r.informacionAdicional ?? ""; // Ya viene con pipes |
    return "$p $i";
  }

  void _filtrarRendimiento() {
    String query = _searchRendimiento.text.toLowerCase();
    setState(() {
      _rendimientoFiltrados = _rendimientoOriginales.where((r) {
        String searchable =
            (r.parametros ?? "") + (r.informacionAdicional ?? "");
        return searchable.toLowerCase().contains(query);
      }).toList();
    });
  }

  void _filtrarCertificados() {
    String query = _searchCertificados.text.toLowerCase();
    setState(() {
      _certificadosFiltrados = _certificadosOriginales.where((r) {
        String searchable = (r.parametros ?? "")
            .toLowerCase(); // Nombre, Codigo, Año estan aqui
        return searchable.contains(query);
      }).toList();
    });
  }

  // --- LÓGICA DE EXPORTACIÓN ---

  Future<void> _exportarPDF(Reporte r) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 1. Obtener datos completos
      final resData = await _service.obtenerDatosPdf(r.idReporte);

      if (resData.status == 'success') {
        // 2. Generar PDF
        final bytes = await _pdfService.generarPdf(resData.data!);
        Navigator.pop(context); // Cerrar loader

        // 3. Descargar/Compartir
        String nombreArchivo = "${r.tipoReporte}_${r.idReporte}.pdf";
        await Printing.sharePdf(bytes: bytes, filename: nombreArchivo);

        // Opcional: Llamar al backend para marcar como "Exportado" (CU-16) si se requiere cambio de estado
        // await _service.marcarExportado(r.idReporte);
      } else {
        Navigator.pop(context);
        _mostrarError("Error datos", detalle: resData.message);
      }
    } catch (e) {
      Navigator.pop(context);
      _mostrarError("Error exportación", detalle: e);
    }
  }

  Future<void> _exportarGrupoBoletas(String key, List<Reporte> lista) async {
    // Exportación Masiva (Secuencial)
    bool confirm =
        await showDialog(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text("Exportación Masiva"),
            content: Text(
              "Se descargarán ${lista.length} archivos individualmente.\n¿Desea continuar?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text("Cancelar"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text("Descargar Todo"),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    for (var r in lista) {
      await _exportarPDF(r);
      // Pequeña pausa para no saturar el navegador
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  // --- UTILS ---
  String _parseAlumnoName(Reporte r) {
    final params = r.parametros ?? "";
    if (params.contains("ALUMNO:")) {
      final parts = params.split('|');
      for (var part in parts) {
        if (part.trim().startsWith("ALUMNO:"))
          return part.replaceAll("ALUMNO:", "").trim();
      }
    }
    return params.split('|')[0];
  }

  // --- UI ---
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                "Reportes Finales",
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                  fontSize: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "Consulte y exporte los documentos académicos finalizados.",
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 20),

          Container(
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                  ),
                ],
              ),
              labelColor: Colors.teal[800],
              unselectedLabelColor: Colors.grey[600],
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              tabs: [
                _tab("Boletas", _boletasOriginales.length, Icons.folder_shared),
                _tab(
                  "Rendimiento",
                  _rendimientoOriginales.length,
                  Icons.bar_chart,
                ),
                _tab(
                  "Certificados",
                  _certificadosOriginales.length,
                  Icons.workspace_premium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildTabContent(
                        controller: _searchBoletas,
                        hint: "Filtrar por: Alumno, Código, Grado, Docente...",
                        child: _buildBoletasList(),
                      ),
                      _buildTabContent(
                        controller: _searchRendimiento,
                        hint: "Filtrar por: Año, Nivel, Periodo...",
                        child: _buildSimpleList(
                          _rendimientoFiltrados,
                          Icons.bar_chart,
                          Colors.indigo,
                        ),
                      ),
                      _buildTabContent(
                        controller: _searchCertificados,
                        hint: "Filtrar por: Alumno, Código, Año...",
                        child: _buildSimpleList(
                          _certificadosFiltrados,
                          Icons.workspace_premium,
                          Colors.amber[800]!,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _tab(String l, int c, IconData i) => Tab(
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(i, size: 18),
        const SizedBox(width: 8),
        Text(l),
        if (c > 0)
          Container(
            margin: const EdgeInsets.only(left: 6),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.teal[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              "$c",
              style: TextStyle(color: Colors.teal[900], fontSize: 10),
            ),
          ),
      ],
    ),
  );

  // Estructura común del tab con buscador
  Widget _buildTabContent({
    required TextEditingController controller,
    required String hint,
    required Widget child,
  }) {
    return Column(
      children: [
        TextField(
          controller: controller,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: hint,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 15,
              vertical: 10,
            ),
          ),
        ),
        const SizedBox(height: 15),
        Expanded(child: child),
      ],
    );
  }

  // LISTA BOLETAS AGRUPADAS
  Widget _buildBoletasList() {
    if (_boletasFiltradasGroup.isEmpty) return _empty();

    return ListView.builder(
      itemCount: _boletasFiltradasGroup.length,
      itemBuilder: (c, i) {
        String key = _boletasFiltradasGroup.keys.elementAt(i);
        List<Reporte> list = _boletasFiltradasGroup[key]!;

        // Parse key for display: AÑO|NIVEL|GRADO|SECCION|BIM|DOCENTE
        List<String> p = key.split('|');
        String titulo = p.length > 3 ? "${p[2]} - ${p[3]}" : key;
        String sub = p.length > 5 ? "${p[5]} (${p[4]})" : "";

        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ExpansionTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.teal[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.folder, color: Colors.teal),
            ),
            title: Text(
              titulo,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text("${list.length} Boletas • $sub"),
            trailing: ElevatedButton.icon(
              onPressed: () => _exportarGrupoBoletas(key, list),
              icon: const Icon(Icons.download, size: 18),
              label: const Text("TODO"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
            children: list.map((r) => _itemBoleta(r)).toList(),
          ),
        );
      },
    );
  }

  Widget _itemBoleta(Reporte r) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
        color: Colors.grey[50],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.person, size: 16, color: Colors.grey),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _parseAlumnoName(r),
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),
          _actionBtnSmall(
            Icons.visibility,
            Colors.blue,
            "Ver",
            () => _verPdf(r),
          ), // Reutilizamos _verPdf para preview
          const SizedBox(width: 10),
          _actionBtnSmall(
            Icons.download,
            Colors.green,
            "Exportar",
            () => _exportarPDF(r),
          ),
        ],
      ),
    );
  }

  // LISTA SIMPLE (Rendimiento / Certificados)
  Widget _buildSimpleList(List<Reporte> list, IconData icon, Color color) {
    if (list.isEmpty) return _empty();
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (c, i) {
        Reporte r = list[i];
        String title = r.tipoReporte;
        String sub = "";

        if (r.tipoReporte == 'Reporte de Rendimiento') {
          String fecha = DateFormat(
            'dd/MM/yyyy',
          ).format(DateTime.parse(r.fechaGeneracion));
          sub =
              "ID: #${r.idReporte} | $fecha | ${r.parametros?.split('|')[1] ?? ''}";
        } else {
          sub = _parseAlumnoName(r);
        }

        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color),
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Text(sub, style: const TextStyle(fontSize: 12)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.visibility_outlined,
                    color: Colors.grey,
                  ),
                  onPressed: () => _verPdf(r),
                  tooltip: "Vista Previa",
                ),
                ElevatedButton.icon(
                  onPressed: () => _exportarPDF(r),
                  icon: const Icon(Icons.file_download, size: 18),
                  label: const Text("Exportar"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _actionBtnSmall(
    IconData icon,
    Color color,
    String tooltip,
    VoidCallback fn,
  ) {
    return InkWell(
      onTap: fn,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }

  Widget _empty() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.search_off, size: 50, color: Colors.grey[300]),
        const SizedBox(height: 10),
        Text(
          "No se encontraron documentos.",
          style: TextStyle(color: Colors.grey[500]),
        ),
      ],
    ),
  );

  // Reutilizamos _verPdf para la vista previa dentro de esta pantalla (solo lectura)
  Future<void> _verPdf(Reporte r) async {
    showDialog(
      barrierDismissible: false,
      context: context,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final res = await _service.obtenerDatosPdf(r.idReporte);
      Navigator.pop(context);
      if (res.status == 'success') {
        final bytes = await _pdfService.generarPdf(res.data!);
        await showDialog(
          context: context,
          builder: (c) => Dialog(
            child: Container(
              width: 900,
              height: 800,
              padding: const EdgeInsets.all(10),
              child: PdfPreview(
                build: (f) => bytes,
                allowPrinting: false,
                allowSharing: false, // Solo vista
                initialPageFormat: PdfPageFormat.a4,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context);
    }
  }

  void _mostrarError(String t, {dynamic detalle}) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t),
        content: Text(detalle.toString()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("Cerrar"),
          ),
        ],
      ),
    );
  }
}
