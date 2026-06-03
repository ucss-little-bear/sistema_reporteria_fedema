import 'package:flutter/material.dart';
import 'package:frontend/Controller/auth_provider_controller.dart';
import 'package:frontend/Model/Entities/reporte_entity.dart';
import 'package:frontend/Model/Services/reporte_service.dart';

import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

class HistorialReportesView extends StatefulWidget {
  const HistorialReportesView({super.key});

  @override
  State<HistorialReportesView> createState() => _HistorialReportesViewState();
}

class _HistorialReportesViewState extends State<HistorialReportesView>
    with TickerProviderStateMixin {

  final ReporteService _service = ReporteService();

  bool _isLoading = true;
  bool _esDocente = false;


  List<Reporte> _boletasOriginales = [];
  List<Reporte> _rendimientoOriginales = [];
  List<Reporte> _certificadosOriginales = [];


  Map<String, List<Reporte>> _boletasGroup = {};
  List<Reporte> _rendimientoFiltrados = [];
  List<Reporte> _certificadosFiltrados = [];


  final TextEditingController _searchBoletas = TextEditingController();
  final TextEditingController _searchRendimiento = TextEditingController();
  final TextEditingController _searchCertificados = TextEditingController();

  late TabController _tabController;

  @override
  void initState() {
    super.initState();

    _tabController = TabController(length: 1, vsync: this);

    _setupListeners();

    WidgetsBinding.instance.addPostFrameCallback((_) => _cargarHistorial());
  }

  void _setupListeners() {
    _searchBoletas.addListener(_filtrarBoletas);
    _searchRendimiento.addListener(_filtrarRendimiento);
    _searchCertificados.addListener(_filtrarCertificados);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchBoletas.dispose();
    _searchRendimiento.dispose();
    _searchCertificados.dispose();
    super.dispose();
  }


  Future<void> _cargarHistorial() async {
    setState(() => _isLoading = true);
    final usuario = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).usuarioActual;
    if (usuario == null) return;


    bool esDocenteNuevo = (usuario.idRol == 3);


    int nuevaLongitud = esDocenteNuevo ? 1 : 3;
    if (_tabController.length != nuevaLongitud) {
      _tabController.dispose();
      _tabController = TabController(length: nuevaLongitud, vsync: this);
    }

    _esDocente = esDocenteNuevo;

    try {
      final res = await _service.listarReportes(
        usuario.idUsuario,
        usuario.idRol,
      );

      if (res.status == 'success' && res.data != null) {
        final lista = res.data!;

        _boletasOriginales = lista
            .where((r) => r.tipoReporte == 'Boleta de Notas')
            .toList();

        if (!_esDocente) {
          _rendimientoOriginales = lista
              .where((r) => r.tipoReporte == 'Reporte de Rendimiento')
              .toList();
          _certificadosOriginales = lista
              .where((r) => r.tipoReporte == 'Certificado de Estudios')
              .toList();
        }


        _filtrarBoletas();
        if (!_esDocente) {
          _filtrarRendimiento();
          _filtrarCertificados();
        }
      } else {
        _mostrarError("Error", detalle: res.message);
      }
    } catch (e) {
      _mostrarError("Conexión fallida", detalle: e);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  void _filtrarBoletas() {
    String q = _searchBoletas.text.toLowerCase();
    Map<String, List<Reporte>> group = {};

    for (var r in _boletasOriginales) {
      String fullText =
          "${r.parametros} ${r.informacionAdicional} ${r.estadoReporte}"
              .toLowerCase();
      if (fullText.contains(q)) {
        String key = r.informacionAdicional ?? "Otros";
        if (!group.containsKey(key)) group[key] = [];
        group[key]!.add(r);
      }
    }
    setState(() => _boletasGroup = group);
  }

  void _filtrarRendimiento() {
    String q = _searchRendimiento.text.toLowerCase();
    setState(() {
      _rendimientoFiltrados = _rendimientoOriginales.where((r) {
        return "${r.parametros} ${r.informacionAdicional}"
            .toLowerCase()
            .contains(q);
      }).toList();
    });
  }

  void _filtrarCertificados() {
    String q = _searchCertificados.text.toLowerCase();
    setState(() {
      _certificadosFiltrados = _certificadosOriginales.where((r) {
        return "${r.parametros}".toLowerCase().contains(q);
      }).toList();
    });
  }


  Color _getColorEstado(int? idEstado) {
    switch (idEstado) {
      case 1:
        return Colors.blue;
      case 2:
        return Colors.orange;
      case 5:
        return Colors.purple;
      case 3:
        return Colors.green;
      case 4:
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

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
                "Historial de Reportes",
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
            "Consulte el estado y detalle de todos los reportes generados en el sistema.",
            style: TextStyle(color: Colors.grey[600]),
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
              labelColor: Colors.blueGrey[900],
              unselectedLabelColor: Colors.grey[600],
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              tabs: _buildTabs(),
            ),
          ),
          const SizedBox(height: 20),


          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: _buildTabViews(),
                  ),
          ),
        ],
      ),
    );
  }


  List<Widget> _buildTabs() {
    List<Widget> tabs = [
      _tab("Boletas", _boletasOriginales.length, Icons.folder),
    ];

    if (!_esDocente) {
      tabs.addAll([
        _tab("Rendimiento", _rendimientoOriginales.length, Icons.bar_chart),
        _tab(
          "Certificados",
          _certificadosOriginales.length,
          Icons.workspace_premium,
        ),
      ]);
    }
    return tabs;
  }


  List<Widget> _buildTabViews() {
    List<Widget> views = [
      _buildTabContent(
        _searchBoletas,
        "Filtrar boletas...",
        _buildBoletasList(),
      ),
    ];

    if (!_esDocente) {
      views.addAll([
        _buildTabContent(
          _searchRendimiento,
          "Filtrar reportes...",
          _buildSimpleList(_rendimientoFiltrados, Icons.bar_chart),
        ),
        _buildTabContent(
          _searchCertificados,
          "Filtrar certificados...",
          _buildSimpleList(_certificadosFiltrados, Icons.workspace_premium),
        ),
      ]);
    }
    return views;
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
              color: Colors.blueGrey[100],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              "$c",
              style: TextStyle(color: Colors.blueGrey[900], fontSize: 10),
            ),
          ),
      ],
    ),
  );

  Widget _buildTabContent(
    TextEditingController ctrl,
    String hint,
    Widget list,
  ) {
    return Column(
      children: [
        TextField(
          controller: ctrl,
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
        Expanded(child: list),
      ],
    );
  }


  Widget _buildBoletasList() {
    if (_boletasGroup.isEmpty) return _empty();
    return ListView.builder(
      itemCount: _boletasGroup.length,
      itemBuilder: (c, i) {
        String key = _boletasGroup.keys.elementAt(i);
        List<Reporte> list = _boletasGroup[key]!;

        List<String> p = key.split('|');
        String titulo = p.length > 3 ? "${p[2]} - ${p[3]}" : key;

        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: ExpansionTile(
            leading: _iconBox(Icons.class_, Colors.blueGrey),
            title: Text(
              titulo,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text("${list.length} Documentos"),
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
          _statusDot(r.idEstadoReporte),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _parseAlumnoName(r),
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
                Text(
                  r.estadoReporte,
                  style: TextStyle(
                    fontSize: 11,
                    color: _getColorEstado(r.idEstadoReporte),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.info_outline, size: 20, color: Colors.grey),
            onPressed: () => _verInfo(r),
          ),
        ],
      ),
    );
  }


  Widget _buildSimpleList(List<Reporte> list, IconData icon) {
    if (list.isEmpty) return _empty();
    return ListView.builder(
      itemCount: list.length,
      itemBuilder: (c, i) {
        Reporte r = list[i];
        String title = r.tipoReporte;
        String sub = r.tipoReporte == 'Reporte de Rendimiento'
            ? "ID: #${r.idReporte} - ${DateFormat('dd/MM/yyyy').format(DateTime.parse(r.fechaGeneracion))}"
            : _parseAlumnoName(r);

        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: ListTile(
            leading: _iconBox(icon, Colors.blueGrey),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sub, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                _statusChip(r.estadoReporte, r.idEstadoReporte),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => _verInfo(r),
            ),
          ),
        );
      },
    );
  }


  Widget _iconBox(IconData i, MaterialColor c) => Container(
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: c[50],
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(i, color: c[800]),
  );

  Widget _statusDot(int? estado) => Container(
    width: 10,
    height: 10,
    decoration: BoxDecoration(
      color: _getColorEstado(estado),
      shape: BoxShape.circle,
    ),
  );

  Widget _statusChip(String label, int? estado) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      color: _getColorEstado(estado).withOpacity(0.1),
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: _getColorEstado(estado).withOpacity(0.3)),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 10,
        color: _getColorEstado(estado),
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  Widget _empty() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.history, size: 50, color: Colors.grey[300]),
        const SizedBox(height: 10),
        Text(
          "Sin historial disponible.",
          style: TextStyle(color: Colors.grey[500]),
        ),
      ],
    ),
  );

  void _verInfo(Reporte r) {
    String contenido = r.parametros?.replaceAll('|', '\n\n') ?? "Sin datos";
    showDialog(
      context: context,
      builder: (c) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.history_edu, color: Colors.blueGrey[800]),
                  const SizedBox(width: 10),
                  Text(
                    "Historial #${r.idReporte}",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(c),
                  ),
                ],
              ),
              const Divider(),
              _infoRow(
                "Estado Actual:",
                r.estadoReporte,
                _getColorEstado(r.idEstadoReporte),
              ),
              const SizedBox(height: 10),
              _infoRow("Tipo:", r.tipoReporte, Colors.black87),
              _infoRow("Generado:", r.fechaGeneracion, Colors.black87),
              const SizedBox(height: 15),
              const Text(
                "DETALLES:",
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 5),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(contenido, style: const TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String? val, Color color) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            val ?? "-",
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 12,
            ),
          ),
        ),
      ],
    ),
  );

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
