import 'package:flutter/material.dart';
import 'package:frontend/Controller/auth_provider_controller.dart';
import 'package:frontend/View/boletas_finales.dart';
import 'package:frontend/View/firmar_boleta_notas.dart';
import 'package:frontend/View/firmar_reportes_generados.dart';
import 'package:frontend/View/firmar_reportes_revisados.dart';
import 'package:frontend/View/generar_reportes.dart';
import 'package:frontend/View/gestionar_usuarios.dart';
import 'package:frontend/View/historial_reportes.dart';
import 'package:frontend/View/importar_archivos_siagie.dart';
import 'package:frontend/View/login_screen.dart';
import 'package:frontend/View/panel_principal.dart';
import 'package:frontend/View/reportes_finales.dart';
import 'package:frontend/View/reportes_rendimiento.dart';
import 'package:provider/provider.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  bool _isSidebarExpanded = true;

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Icon(Icons.logout, color: Colors.red[700]),
            const SizedBox(width: 10),
            const Text(
              "Cerrar Sesión",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: const Text(
          "¿Estás seguro de que deseas salir del sistema?",
          style: TextStyle(color: Colors.black87),
        ),
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
            child: const Text("No, cancelar"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text("Sí, Salir"),
          ),
        ],
      ),
    );
  }

  void _logout() {
    Provider.of<AuthProvider>(context, listen: false).logout();
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  void _showNotificationsPreview(BuildContext context, String roleName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Icon(
              Icons.notifications_none,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(width: 10),
            const Text(
              "Avisos dinámicos",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          "Campana visual agregada para el rol: $roleName.\n\n"
          "En una siguiente iteración se conectará con los estados de reportes "
          "y boletas para mostrar acciones pendientes.",
          style: const TextStyle(color: Colors.black87),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text("Entendido"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usuario = context.watch<AuthProvider>().usuarioActual;
    final theme = Theme.of(context);

    if (usuario == null) {
      Future.microtask(
        () => Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        ),
      );
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final List<Map<String, dynamic>> menuItems = [];

    menuItems.add({
      'icon': Icons.dashboard,
      'title': 'Panel Principal',
      'view': DashboardView(
        onNavigate: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    });

    if (usuario.idRol == 1) {
      menuItems.addAll([
        {
          'icon': Icons.upload_file,
          'title': 'Importar Archivos',
          'view': const ImportarArchivosView(),
        },
        {
          'icon': Icons.description,
          'title': 'Generar Reportes',
          'view': const GenerarReportesView(),
        },
        {
          'icon': Icons.verified_user,
          'title': 'Firmar Revisados',
          'view': const FirmarReportesRevisadosView(),
        },
        {
          'icon': Icons.folder_shared,
          'title': 'Reportes Finales',
          'view': const ReportesFinalesView(),
        },
        {
          'icon': Icons.people,
          'title': 'Gestionar Usuarios',
          'view': const GestionarUsuariosView(),
        },
        {
          'icon': Icons.history,
          'title': 'Historial de Reportes',
          'view': const HistorialReportesView(),
        },
      ]);
    }

    if (usuario.idRol == 2) {
      menuItems.addAll([
        {
          'icon': Icons.edit_document,
          'title': 'Firmar Generados',
          'view': const FirmarReportesGeneradosView(),
        },
        {
          'icon': Icons.analytics,
          'title': 'Reporte de Rendimiento',
          'view': const ReportesRendimientoView(),
        },
        {
          'icon': Icons.history,
          'title': 'Historial de Reportes',
          'view': const HistorialReportesView(),
        },
      ]);
    }

    if (usuario.idRol == 3) {
      menuItems.addAll([
        {
          'icon': Icons.assignment_turned_in,
          'title': 'Firmar Boletas',
          'view': const FirmarBoletaNotasView(),
        },
        {
          'icon': Icons.task,
          'title': 'Boletas Finales',
          'view': const BoletasFinalesView(),
        },
        {
          'icon': Icons.history,
          'title': 'Historial de Reportes',
          'view': const HistorialReportesView(),
        },
      ]);
    }

    if (_selectedIndex >= menuItems.length) {
      _selectedIndex = 0;
    }

    final currentTitle = menuItems[_selectedIndex]['title'] as String;
    final roleName = usuario.rolDescripcion ?? "Usuario";

    return Scaffold(
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: _isSidebarExpanded ? 260 : 70,
            color: theme.primaryColor,
            child: Column(
              children: [
                Padding(
                  padding: _isSidebarExpanded
                      ? const EdgeInsets.fromLTRB(24, 24, 16, 20)
                      : const EdgeInsets.symmetric(vertical: 24),
                  child: Row(
                    mainAxisAlignment: _isSidebarExpanded
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.school,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),

                      if (_isSidebarExpanded) ...[
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            "Sistema Académico",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.chevron_left,
                            color: Colors.white54,
                          ),
                          onPressed: () =>
                              setState(() => _isSidebarExpanded = false),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ],
                  ),
                ),

                if (!_isSidebarExpanded)
                  IconButton(
                    icon: const Icon(
                      Icons.chevron_right,
                      color: Colors.white54,
                    ),
                    onPressed: () => setState(() => _isSidebarExpanded = true),
                  ),

                if (_isSidebarExpanded) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          "Hola, ${usuario.nombres.split(' ')[0]}",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Text(
                            usuario.rolDescripcion ?? "Usuario",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                const Divider(color: Colors.white10, height: 1),
                const SizedBox(height: 8),

                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: menuItems.length,
                    itemBuilder: (context, index) {
                      final item = menuItems[index];
                      final isSelected = index == _selectedIndex;

                      return Tooltip(
                        message: _isSidebarExpanded ? "" : item['title'],
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.white.withOpacity(0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () =>
                                  setState(() => _selectedIndex = index),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                  horizontal: 12,
                                ),
                                child: Row(
                                  mainAxisAlignment: _isSidebarExpanded
                                      ? MainAxisAlignment.start
                                      : MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      item['icon'],
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.white60,
                                      size: 22,
                                    ),
                                    if (_isSidebarExpanded) ...[
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          item['title'],
                                          style: TextStyle(
                                            color: isSelected
                                                ? Colors.white
                                                : Colors.white70,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                            fontSize: 14,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const Divider(color: Colors.white10, height: 1),

                Padding(
                  padding: EdgeInsets.all(_isSidebarExpanded ? 16 : 8),
                  child: _LogoutButton(
                    isExpanded: _isSidebarExpanded,
                    onTap: () => _showLogoutConfirmation(context),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: Container(
              color: const Color(0xFFF5F6FA),
              child: Column(
                children: [
                  Container(
                    height: 72,
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(color: Color(0xFFE5E7EB)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            currentTitle,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1F2937),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Tooltip(
                          message: "Avisos dinámicos",
                          child: IconButton(
                            icon: const Icon(Icons.notifications_none),
                            color: theme.primaryColor,
                            iconSize: 28,
                            onPressed: () =>
                                _showNotificationsPreview(context, roleName),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: menuItems[_selectedIndex]['view'] as Widget,
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

class _LogoutButton extends StatefulWidget {
  final bool isExpanded;
  final VoidCallback onTap;

  const _LogoutButton({required this.isExpanded, required this.onTap});

  @override
  State<_LogoutButton> createState() => _LogoutButtonState();
}

class _LogoutButtonState extends State<_LogoutButton> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
          decoration: BoxDecoration(
            color: _isHovering
                ? Colors.red.withOpacity(0.2)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: _isHovering
                ? Border.all(color: Colors.red.withOpacity(0.5))
                : null,
          ),
          child: Row(
            mainAxisAlignment: widget.isExpanded
                ? MainAxisAlignment.start
                : MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.logout,
                color: _isHovering ? Colors.red[200] : Colors.white70,
                size: 20,
              ),
              if (widget.isExpanded) ...[
                const SizedBox(width: 12),
                Flexible(
                  child: Text(
                    "Cerrar Sesión",
                    style: TextStyle(
                      color: _isHovering ? Colors.red[200] : Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
