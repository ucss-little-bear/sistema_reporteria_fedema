import 'package:flutter/material.dart';
import 'package:frontend/Controller/auth_provider_controller.dart';
import 'package:provider/provider.dart';

class DashboardView extends StatelessWidget {
  final Function(int) onNavigate;

  const DashboardView({super.key, required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<AuthProvider>().usuarioActual;
    final theme = Theme.of(context);

    if (usuario == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            "Bienvenido, ${usuario.nombres} ${usuario.apellidos}",
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              fontSize: 28,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Sistema de Gestión Académica - ${usuario.rolDescripcion}",
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 30), // Reduje un poco el espacio aquí también
          // Grilla de Tarjetas
          LayoutBuilder(
            builder: (context, constraints) {
              // Lógica responsiva de columnas
              int crossAxisCount = constraints.maxWidth > 900
                  ? 3
                  : (constraints.maxWidth > 400 ? 2 : 1);

              // CORRECCIÓN VISUAL:
              // Aumentamos el aspect ratio para que las tarjetas sean menos altas.
              // 1.6 significa que el ancho es 1.6 veces el alto.
              double aspectRatio = constraints.maxWidth > 400 ? 1.7 : 1.5;

              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 20, // Espaciado un poco más compacto
                mainAxisSpacing: 20,
                shrinkWrap: true,
                childAspectRatio: aspectRatio, // <--- Esto reduce la altura
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

    // --- ROL 1: SECRETARÍA ---
    if (idRol == 1) {
      cards.add(
        _buildCard(
          title: "Importar Archivos",
          desc: "Cargar datos del SIAGIE",
          icon: Icons.upload_file,
          navIndex: 1,
          color: Colors.blue,
        ),
      );
      cards.add(
        _buildCard(
          title: "Generar Reportes",
          desc: "Crear boletas y certificados",
          icon: Icons.description,
          navIndex: 2,
          color: Colors.orange,
        ),
      );
      cards.add(
        _buildCard(
          title: "Firmar Revisados",
          desc: "Aplicar firma final",
          icon: Icons.verified_user,
          navIndex: 3,
          color: Colors.purple,
        ),
      );
      cards.add(
        _buildCard(
          title: "Gestionar Usuarios",
          desc: "Administrar accesos",
          icon: Icons.people,
          navIndex: 5,
          color: Colors.teal,
        ),
      );
    }

    // --- ROL 2: DIRECTORA ---
    if (idRol == 2) {
      cards.add(
        _buildCard(
          title: "Firmar Reportes",
          desc: "Aplicar primera firma",
          icon: Icons.edit_document,
          navIndex: 1,
          color: const Color(0xFF1A237E),
        ),
      );
      cards.add(
        _buildCard(
          title: "Rendimiento",
          desc: "Ver reportes finales",
          icon: Icons.analytics,
          navIndex: 2,
          color: Colors.green,
        ),
      );
      cards.add(
        _buildCard(
          title: "Historial",
          desc: "Consultar anteriores",
          icon: Icons.history,
          navIndex: 3,
          color: Colors.grey,
        ),
      );
    }

    // --- ROL 3: DOCENTE ---
    if (idRol == 3) {
      cards.add(
        _buildCard(
          title: "Firmar Boleta",
          desc: "Validar notas cursos",
          icon: Icons.assignment_turned_in,
          navIndex: 1,
          color: Colors.indigo,
        ),
      );
      cards.add(
        _buildCard(
          title: "Boletas Finales",
          desc: "Descargar listas",
          icon: Icons.task,
          navIndex: 2,
          color: Colors.teal,
        ),
      );
      cards.add(
        _buildCard(
          title: "Historial",
          desc: "Consultar historial",
          icon: Icons.history,
          navIndex: 3,
          color: Colors.grey,
        ),
      );
    }

    return cards;
  }

  Widget _buildCard({
    required String title,
    required String desc,
    required IconData icon,
    required int navIndex,
    required Color color,
  }) {
    return Builder(
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20), // Padding interno más ajustado
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            // CORRECCIÓN: Usar spaceBetween en lugar de Spacer para distribución exacta
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Parte Superior: Icono y Textos
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icono
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 26),
                  ),
                  const SizedBox(height: 12), // Espacio reducido
                  // Título
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Descripción
                  Text(
                    desc,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),

              // Parte Inferior: Botón
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => onNavigate(navIndex),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                    ), // Botón más delgado
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    foregroundColor: Colors.black87,
                  ),
                  child: Text(
                    "Ir a $title",
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
