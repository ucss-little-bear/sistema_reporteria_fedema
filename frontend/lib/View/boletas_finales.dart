import 'package:flutter/material.dart';
import 'package:frontend/Controller/auth_provider_controller.dart';
import 'package:frontend/Model/Entities/reporte_entity.dart';
import 'package:frontend/Model/Services/pdf_generator_service.dart';
import 'package:frontend/Model/Services/reporte_service.dart';

import 'package:provider/provider.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';

class BoletasFinalesView extends StatefulWidget {
  const BoletasFinalesView({super.key});

  @override
  State<BoletasFinalesView> createState() => _BoletasFinalesViewState();
}

class _BoletasFinalesViewState extends State<BoletasFinalesView> {
  final ReporteService _service = ReporteService();
  final PdfGeneratorService _pdfService = PdfGeneratorService();

  bool _isLoading = true;

  // Datos
  List<Reporte> _boletasOriginales = [];
  Map<String, List<Reporte>> _boletasAgrupadas = {};

  // Controlador de Búsqueda
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => _filtrarBoletas());
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarReportes());
  }

  @override
  void dispose() {
    _searchController.dispose();
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
        _boletasOriginales = res.data!
            .where(
              (r) =>
                  r.tipoReporte == 'Boleta de Notas' && r.idEstadoReporte == 3,
            )
            .toList();

        _filtrarBoletas();
      } else {
        _mostrarError("Error al cargar", detalle: res.message);
      }
    } catch (e) {
      _mostrarError("Error de conexión", detalle: e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filtrarBoletas() {
    String query = _searchController.text.toLowerCase();
    Map<String, List<Reporte>> agrupado = {};

    for (var r in _boletasOriginales) {
      String p = r.parametros ?? "";
      String i = r.informacionAdicional ?? "";
      String searchable = "$p $i".toLowerCase();

      if (searchable.contains(query)) {
        String key = r.informacionAdicional ?? "Otros";
        if (!agrupado.containsKey(key)) agrupado[key] = [];
        agrupado[key]!.add(r);
      }
    }
    setState(() => _boletasAgrupadas = agrupado);
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
        // Generamos el PDF con TODAS las firmas (Sec + Dir + Doc)
        final bytes = await _pdfService.generarPdf(resData.data!);
        Navigator.pop(context);

        String nombreArchivo = "Boleta_${r.idReporte}.pdf";
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

  Future<void> _exportarGrupo(String key, List<Reporte> lista) async {
    bool confirm =
        await showDialog(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text("Descarga Masiva"),
            content: Text(
              "Se descargarán las ${lista.length} boletas de este grupo una por una.\n¿Desea continuar?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text("Cancelar"),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(c, true),
                child: const Text("Descargar"),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirm) return;

    for (var r in lista) {
      await _exportarPDF(r);
      // Pequeña pausa para estabilidad
      await Future.delayed(const Duration(milliseconds: 600));
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
          // Encabezado
          Row(
            children: [
              Text(
                "Boletas Finales",
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
            "Consulte y descargue las boletas de notas finalizadas de sus salones.",
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 25),

          // Buscador
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: "Buscar por: Alumno, Grado, Sección, Bimestre...",
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

          // Contenido
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _boletasAgrupadas.isEmpty
                ? _emptyState()
                : ListView.builder(
                    itemCount: _boletasAgrupadas.length,
                    itemBuilder: (c, i) {
                      String key = _boletasAgrupadas.keys.elementAt(i);
                      List<Reporte> lista = _boletasAgrupadas[key]!;
                      return _buildGroupCard(key, lista);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupCard(String key, List<Reporte> list) {
    // Parsear key para mostrar titulo bonito: AÑO|NIVEL|GRADO|SECCION|BIM|DOCENTE
    List<String> p = key.split('|');
    String titulo = p.length > 3 ? "${p[2]} - ${p[3]}" : key;
    String subtitulo = p.length > 4
        ? "Bimestre ${p[4].replaceAll('B', '')}"
        : "";

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.indigo[50],
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.class_, color: Colors.indigo),
        ),
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text("${list.length} Boletas • $subtitulo"),

        // Botón de Exportación Masiva
        trailing: ElevatedButton.icon(
          onPressed: () => _exportarGrupo(key, list),
          icon: const Icon(Icons.download_for_offline, size: 18),
          label: const Text("EXPORTAR TODO"),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo[700],
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),

        children: list.map((r) => _buildItemBoleta(r)).toList(),
      ),
    );
  }

  Widget _buildItemBoleta(Reporte r) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.person, size: 16, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _parseAlumnoName(r),
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
            ),
          ),

          // Botón Ver (Preview)
          Tooltip(
            message: "Vista Previa",
            child: InkWell(
              onTap: () => _verPdfPreview(r),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.visibility,
                  size: 18,
                  color: Colors.blue,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Botón Descargar Individual
          Tooltip(
            message: "Descargar PDF",
            child: InkWell(
              onTap: () => _exportarPDF(r),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(
                  Icons.download,
                  size: 18,
                  color: Colors.green,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Método auxiliar para ver PDF sin descargar
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
        Icon(Icons.folder_off, size: 60, color: Colors.grey[300]),
        const SizedBox(height: 15),
        Text(
          "No tiene boletas finalizadas.",
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
