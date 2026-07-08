import 'package:flutter/material.dart';
import 'package:frontend/Controller/auth_provider_controller.dart';
import 'package:frontend/Model/Services/reporte_service.dart';
import 'package:provider/provider.dart';

class DashboardView extends StatefulWidget {
  final Function(int) onNavigate;
  const DashboardView({super.key, required this.onNavigate});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  Map<String, dynamic>? stats;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarEstadisticas();
  }

  Future<void> _cargarEstadisticas() async {
    final usuario = context.read<AuthProvider>().usuarioActual;
    if (usuario != null) {
      final res = await ReporteService().obtenerEstadisticasDashboard(usuario.idUsuario, usuario.idRol);
      if (res.status == 'success') {
        setState(() {
          stats = res.data;
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<AuthProvider>().usuarioActual;
    final theme = Theme.of(context);

    if (usuario == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Hola, ${usuario.rolDescripcion}",
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Tienes un resumen de elementos que requieren tu atención.",
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 30),
          
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else
            LayoutBuilder(
              builder: (context, constraints) {
                int crossAxisCount = constraints.maxWidth > 900 ? 3 : (constraints.maxWidth > 400 ? 2 : 1);
                double aspectRatio = constraints.maxWidth > 400 ? 1.6 : 1.4;

                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 20,
                  mainAxisSpacing: 20,
                  shrinkWrap: true,
                  childAspectRatio: aspectRatio,
                  physics: const NeverScrollableScrollPhysics(),
                  children: _buildDashboardCards(usuario.idRol),
                );
              },
            ),
        ],
      ),
    );
  }

  List<Widget> _buildDashboardCards(int idRol) {
    List<Widget> cards = [];
  
    int pendientes = (stats != null && stats!.containsKey('pendientes_firma')) 
        ? (stats!['pendientes_firma'] ?? 0) 
        : 0;

    if (idRol == 1) {
      cards.add(_buildCard(title: "Importar Archivos", desc: "Cargar datos del SIAGIE", icon: Icons.upload_file, navIndex: 1, color: Colors.blue));
      cards.add(_buildCard(title: "Generar Reportes", desc: "Crear boletas y certificados", icon: Icons.description, navIndex: 2, color: Colors.orange));
      cards.add(_buildCard(
        title: "Firmar Revisados", 
        desc: "Aplicar firma final", 
        icon: Icons.verified_user, 
        navIndex: 3, 
        color: Colors.purple,
        kpiCount: pendientes,
        kpiLabel: "Pendientes",
        isUrgent: pendientes > 0
      ));
      cards.add(_buildCard(title: "Gestionar Usuarios", desc: "Administrar accesos", icon: Icons.people, navIndex: 5, color: Colors.teal));
    }

    if (idRol == 2) {
      cards.add(_buildCard(
        title: "Firmar Reportes", 
        desc: "Aplicar primera firma", 
        icon: Icons.edit_document, 
        navIndex: 1, 
        color: const Color(0xFF1A237E),
        kpiCount: pendientes,
        kpiLabel: "Por validar",
        isUrgent: pendientes > 0
      ));
      cards.add(_buildCard(title: "Rendimiento", desc: "Ver reportes finales", icon: Icons.analytics, navIndex: 2, color: Colors.green));
      cards.add(_buildCard(title: "Historial", desc: "Consultar anteriores", icon: Icons.history, navIndex: 3, color: Colors.grey));
    }

    if (idRol == 3) {
      cards.add(_buildCard(
        title: "Firmar Boleta", 
        desc: "Validar notas cursos", 
        icon: Icons.assignment_turned_in, 
        navIndex: 1, 
        color: Colors.indigo,
        kpiCount: pendientes,
        kpiLabel: "Pendientes",
        isUrgent: pendientes > 0
      ));
      cards.add(_buildCard(title: "Boletas Finales", desc: "Descargar listas", icon: Icons.task, navIndex: 2, color: Colors.teal));
      cards.add(_buildCard(title: "Historial", desc: "Consultar historial", icon: Icons.history, navIndex: 3, color: Colors.grey));
    }

    return cards;
  }

  Widget _buildCard({
    required String title,
    required String desc,
    required IconData icon,
    required int navIndex,
    required Color color,
    int? kpiCount,
    String? kpiLabel,
    bool isUrgent = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                ],
              ),
              if (isUrgent)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                  child: const Text("• Urgente", style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                )
            ],
          ),
          
          if (kpiCount != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(kpiCount.toString(), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, height: 1.0)),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(kpiLabel ?? "", style: TextStyle(fontSize: 14, color: Colors.grey[600], fontWeight: FontWeight.w500)),
                ),
              ],
            ),
            
          Text(desc, style: TextStyle(fontSize: 13, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
          
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => widget.onNavigate(navIndex),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text("Abrir ➔", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87)),
            ),
          ),
        ],
      ),
    );
  }
}