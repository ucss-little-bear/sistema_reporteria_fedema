import 'package:frontend/Controller/auth_provider_controller.dart';
import 'package:frontend/Model/Entities/reporte_entity.dart';
import 'package:frontend/Model/Services/pdf_generator_service.dart';
import 'package:frontend/Model/Services/reporte_service.dart';
import 'package:pdf/pdf.dart';
import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:printing/printing.dart';

class FirmarBoletaNotasView extends StatefulWidget {
  final Future<void> Function()? onAvisosActualizados;

  const FirmarBoletaNotasView({
    super.key,
    this.onAvisosActualizados,
  });

  @override
  State<FirmarBoletaNotasView> createState() => _FirmarBoletaNotasViewState();
}

class _FirmarBoletaNotasViewState extends State<FirmarBoletaNotasView>
    with SingleTickerProviderStateMixin {
  final ReporteService _service = ReporteService();
  final PdfGeneratorService _pdfService = PdfGeneratorService();

  bool _isLoading = true;



  Map<String, List<Reporte>> _boletasAgrupadas = {};

  late TabController _tabController;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 1, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarReportes());
  }

  @override
  void dispose() {
    _tabController.dispose();
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


        final pendientes = res.data!
            .where(
              (r) =>
                  r.idEstadoReporte == 5 && r.tipoReporte == 'Boleta de Notas',
            )
            .toList();
        _distribuirDatos(pendientes);
      } else {
        _mostrarError("Error al cargar", detalle: res.message);
      }
    } catch (e) {
      _mostrarError("Error de conexión", detalle: e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _distribuirDatos(List<Reporte> data) {
    _boletasAgrupadas.clear();
    for (var r in data) {

      String k = r.informacionAdicional ?? "Otros";
      if (!_boletasAgrupadas.containsKey(k)) _boletasAgrupadas[k] = [];
      _boletasAgrupadas[k]!.add(r);
    }
  }


  Future<void> _verPdf(Reporte r) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final resData = await _service.obtenerDatosPdf(r.idReporte);
      Navigator.pop(context);

      if (resData.status == 'success') {

        final bytes = await _pdfService.generarPdf(resData.data!);

        if (mounted) {
          await showDialog(
            context: context,
            builder: (ctx) => Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              child: Container(
                width: 900,
                height: 800,
                padding: const EdgeInsets.all(10),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          "Vista Previa (Pendiente Firma Docente)",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                            fontSize: 16,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const Divider(),
                    Expanded(
                      child: PdfPreview(
                        build: (format) => bytes,
                        allowPrinting: false,
                        allowSharing: false,
                        canChangeOrientation: false,
                        canChangePageFormat: false,
                        canDebug: false,
                        actions: [],
                        initialPageFormat: PdfPageFormat.a4,
                        pdfFileName: "VistaPrevia.pdf",
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
      } else {
        _mostrarError("No se pudo generar", detalle: resData.message);
      }
    } catch (e) {
      Navigator.pop(context);
      _mostrarError("Error generando PDF", detalle: e);
    }
  }


  Future<void> _confirmarFirma(Reporte r) async {
    bool ok =
        await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: Row(
              children: const [
                Icon(Icons.history_edu, color: Colors.blueAccent),
                SizedBox(width: 10),
                Text("Firma Final Docente"),
              ],
            ),
            content: const Text(
              "Al firmar, la boleta pasará a estado 'Final' y estará lista para su entrega.\nSe estamparán sus credenciales.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text("Cancelar"),
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.edit_document, size: 16),
                label: const Text("Firmar y Finalizar"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent[700],
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(c, true),
              ),
            ],
          ),
        ) ??
        false;

    if (ok) {
      final usuario = Provider.of<AuthProvider>(
        context,
        listen: false,
      ).usuarioActual;
      if (usuario == null) return;

      setState(() => _isLoading = true);


      final res = await _service.firmarReporte(
        r.idReporte,
        usuario.idUsuario,
        usuario.idRol,
      );

      if (res.status == 'success') {
        await _cargarReportes();
        await widget.onAvisosActualizados?.call();

        _mostrarExito(
          "Completado",
          "Boleta firmada y finalizada exitosamente.",
        );
      } else {
        setState(() => _isLoading = false);
        _mostrarError("Error al firmar", detalle: res.message);
      }
    }
  }

  Future<void> _confirmarFirmaLote(String key, List<Reporte> lista) async {

    List<String> p = key.split('|');
    String salon = p.length > 3 ? "${p[2]} - ${p[3]}" : "este salón";

    bool ok =
        await showDialog<bool>(
          context: context,
          builder: (c) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: Row(
              children: const [
                Icon(Icons.rule_folder, color: Colors.indigo),
                SizedBox(width: 10),
                Text("Firma Masiva Docente"),
              ],
            ),
            content: Text(
              "¿Firmar y finalizar las ${lista.length} boletas de $salon?\nEsta acción completará el ciclo de aprobación.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c, false),
                child: const Text("Cancelar"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.pop(c, true),
                child: const Text("Finalizar Todo"),
              ),
            ],
          ),
        ) ??
        false;

    if (ok) {
      final usuario = Provider.of<AuthProvider>(
        context,
        listen: false,
      ).usuarioActual;
      if (usuario == null) return;

      setState(() => _isLoading = true);
      final ids = lista.map((e) => e.idReporte).toList();

      final res = await _service.firmarLote(
        ids,
        usuario.idUsuario,
        usuario.idRol,
      );

      if (res.status == 'success') {
        await _cargarReportes();
        await widget.onAvisosActualizados?.call();

        _mostrarExito(
          "Lote Finalizado",
          "Todas las boletas han sido firmadas.",
        );
      } else {
        setState(() => _isLoading = false);
        _mostrarError("Error", detalle: res.message);
      }
    }
  }

  String _obtenerDescripcionReporte(Reporte r) {
    final params = r.parametros ?? "";
    if (params.contains("ALUMNO:")) {
      final parts = params.split('|');
      for (var part in parts) {
        if (part.trim().startsWith("ALUMNO:")) {
          return part.replaceAll("ALUMNO:", "").trim();
        }
      }
    }
    return params.split('|')[0];
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
                "Firma de Boletas",
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
            "Finalice las boletas de notas aplicando su firma digital.",
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 25),


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
              labelColor: Colors.blueAccent[700],
              unselectedLabelColor: Colors.grey[600],
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              tabs: [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.folder_shared, size: 18),
                      const SizedBox(width: 8),
                      const Text("Boletas Pendientes"),
                      if (_countBoletas() > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[100],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            "${_countBoletas()}",
                            style: TextStyle(
                              color: Colors.blue[900],
                              fontSize: 10,
                            ),
                          ),
                        ),
                    ],
                  ),
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
                    children: [_buildBoletasView()],
                  ),
          ),
        ],
      ),
    );
  }

  int _countBoletas() {
    int c = 0;
    _boletasAgrupadas.forEach((k, v) => c += v.length);
    return c;
  }

  Widget _buildBoletasView() {
    if (_boletasAgrupadas.isEmpty) return _empty("No hay boletas pendientes.");
    return ListView.builder(
      itemCount: _boletasAgrupadas.length,
      itemBuilder: (c, i) {
        String key = _boletasAgrupadas.keys.elementAt(i);
        return _cardBoletaGroup(key, _boletasAgrupadas[key]!);
      },
    );
  }

  Widget _empty(String m) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.check_circle_outline, size: 60, color: Colors.grey[300]),
        const SizedBox(height: 10),
        Text(m, style: TextStyle(color: Colors.grey[500])),
      ],
    ),
  );

  Widget _cardBoletaGroup(String key, List<Reporte> list) {
    List<String> p = key.split('|');
    String title = p.length > 3 ? "${p[2]} - ${p[3]}" : key;

    String periodo = p.length > 4 ? "Bimestre ${p[4].replaceAll('B', '')}" : "";

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
          child: const Icon(Icons.folder_special, color: Colors.indigo),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(
          "${list.length} Alumnos  •  $periodo",
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        trailing: Container(
          margin: const EdgeInsets.only(right: 8),
          child: ElevatedButton.icon(
            onPressed: () => _confirmarFirmaLote(key, list),
            icon: const Icon(Icons.done_all, size: 18),
            label: const Text("FIRMAR TODO"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              elevation: 4,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              shadowColor: Colors.indigo.withOpacity(0.4),
            ),
          ),
        ),
        children: list
            .map(
              (r) => Container(
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.person, size: 16, color: Colors.grey),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _obtenerDescripcionReporte(r),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    _miniBtn(Icons.info, Colors.grey, () => _verInfo(r)),
                    const SizedBox(width: 8),
                    _miniBtn(
                      Icons.picture_as_pdf,
                      Colors.amber[800]!,
                      () => _verPdf(r),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(
                        Icons.edit_document,
                        size: 18,
                        color: Colors.blueAccent,
                      ),
                      tooltip: "Firmar Individual",
                      onPressed: () => _confirmarFirma(r),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _miniBtn(IconData i, Color c, VoidCallback fn) => InkWell(
    onTap: fn,
    child: Icon(i, size: 20, color: c),
  );

  void _verInfo(Reporte r) {
    String contenido = r.parametros?.replaceAll('|', '\n\n') ?? "Sin datos";

    showDialog(
      context: context,
      builder: (c) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Container(
          width: 400,
          padding: EdgeInsets.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blueAccent[50],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(15),
                    topRight: Radius.circular(15),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.description,
                        color: Colors.blueAccent[700],
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Detalle de Boleta",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            "ID: #${r.idReporte.toString().padLeft(4, '0')}",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.blueAccent[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey),
                      onPressed: () => Navigator.pop(c),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(25),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _infoRow("Tipo:", r.tipoReporte),
                    const SizedBox(height: 15),
                    const Text(
                      "INFORMACIÓN:",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Text(
                        contenido,
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ),
                    const SizedBox(height: 15),
                    _infoRow("Generado:", r.fechaGeneracion),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(c),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      foregroundColor: Colors.black87,
                      elevation: 0,
                    ),
                    child: const Text("Cerrar"),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }

  void _mostrarExito(String t, String m) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green),
            const SizedBox(width: 10),
            Text(t, style: const TextStyle(color: Colors.green)),
          ],
        ),
        content: Text(m),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("OK"),
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
            const Icon(Icons.error, color: Colors.red),
            const SizedBox(width: 10),
            Text(t, style: const TextStyle(color: Colors.red)),
          ],
        ),
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
