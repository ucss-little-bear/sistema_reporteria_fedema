import 'package:flutter/material.dart';
import 'package:frontend/Controller/auth_provider_controller.dart';
import 'package:frontend/Model/Entities/reporte_entity.dart';
import 'package:frontend/Model/Services/pdf_generator_service.dart';
import 'package:frontend/Model/Services/reporte_service.dart';
import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';

class ReportesRendimientoView extends StatefulWidget {
  const ReportesRendimientoView({super.key});

  @override
  State<ReportesRendimientoView> createState() =>
      _ReportesRendimientoViewState();
}

class _ReportesRendimientoViewState extends State<ReportesRendimientoView> {
  final ReporteService _service = ReporteService();
  final PdfGeneratorService _pdfService = PdfGeneratorService();

  bool _isLoading = true;


  List<Reporte> _reportesOriginales = [];
  List<Reporte> _reportesFiltrados = [];


  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => _filtrarReportes());
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarReportes());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }


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




        _reportesOriginales = res.data!
            .where(
              (r) =>
                  r.tipoReporte == 'Reporte de Rendimiento' &&
                  r.idEstadoReporte == 3,
            )
            .toList();

        _filtrarReportes();
      } else {
        _mostrarError("Error al cargar", detalle: res.message);
      }
    } catch (e) {
      _mostrarError("Error de conexión", detalle: e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  void _filtrarReportes() {
    String query = _searchController.text.toLowerCase();

    setState(() {
      _reportesFiltrados = _reportesOriginales.where((r) {



        String p = r.parametros ?? "";
        String i = r.informacionAdicional ?? "";
        String searchable = "$p $i".toLowerCase();

        return searchable.contains(query);
      }).toList();
    });
  }


  Future<void> _exportarPDF(Reporte r) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final resData = await _service.obtenerDatosPdf(r.idReporte);
      if (resData.status == 'success') {

        final bytes = await _pdfService.generarPdf(resData.data!);
        Navigator.pop(context);

        String nombreArchivo = "Rendimiento_${r.idReporte}.pdf";
        await Printing.sharePdf(bytes: bytes, filename: nombreArchivo);
      } else {
        Navigator.pop(context);
        _mostrarError("Error al obtener datos", detalle: resData.message);
      }
    } catch (e) {
      Navigator.pop(context);
      _mostrarError("Error exportando", detalle: e);
    }
  }


  String _obtenerSubtitulo(Reporte r) {


    String params = r.parametros ?? "";
    String anio = "---";
    String nivel = "---";
    String bim = "---";

    if (params.contains('|')) {
      final parts = params.split('|');
      for (var p in parts) {
        if (p.trim().startsWith("AÑO:")) anio = p.replaceAll("AÑO:", "").trim();
        if (p.trim().startsWith("NIVEL:"))
          nivel = p.replaceAll("NIVEL:", "").trim();
        if (p.trim().startsWith("BIM:")) bim = p.replaceAll("BIM:", "").trim();
      }
    }

    String fecha = DateFormat(
      'dd/MM/yyyy',
    ).format(DateTime.parse(r.fechaGeneracion));
    return "Año $anio • $nivel • Bimestre $bim • $fecha";
  }


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
                "Reportes de Rendimiento",
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
            "Consulte y exporte los informes estadísticos finalizados.",
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 25),


          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: "Buscar por: Año, Nivel, Periodo, Salón...",
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 12,
              ),
            ),
          ),
          const SizedBox(height: 20),


          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _reportesFiltrados.isEmpty
                ? _emptyState()
                : ListView.builder(
                    itemCount: _reportesFiltrados.length,
                    itemBuilder: (c, i) =>
                        _buildReporteCard(_reportesFiltrados[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildReporteCard(Reporte r) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [

            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.indigo[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.bar_chart, color: Colors.indigo[900], size: 30),
            ),
            const SizedBox(width: 16),


            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Reporte de Rendimiento #${r.idReporte.toString().padLeft(4, '0')}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _obtenerSubtitulo(r),
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),


            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _actionBtn(
                  Icons.visibility_outlined,
                  Colors.blueGrey,
                  "Vista Previa",
                  () => _verPdfPreview(r),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: () => _exportarPDF(r),
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text("Exportar"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo[800],
                    foregroundColor: Colors.white,
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(
    IconData icon,
    Color color,
    String tooltip,
    VoidCallback fn,
  ) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: fn,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Icon(icon, size: 22, color: color),
        ),
      ),
    );
  }


  Future<void> _verPdfPreview(Reporte r) async {
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
                allowSharing: false,
                canChangeOrientation: false,
                canDebug: false,
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

  Widget _emptyState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.analytics_outlined, size: 70, color: Colors.grey[300]),
        const SizedBox(height: 15),
        Text(
          "No se encontraron reportes de rendimiento finalizados.",
          style: TextStyle(fontSize: 16, color: Colors.grey[500]),
        ),
      ],
    ),
  );

  void _mostrarError(String t, {dynamic detalle}) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(t, style: const TextStyle(color: Colors.red)),
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
