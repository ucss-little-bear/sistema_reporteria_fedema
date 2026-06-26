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
import 'package:frontend/View/crear_pin_dialog.dart';
import 'package:provider/provider.dart';
import 'package:frontend/Model/Services/reporte_service.dart';

class MainLayout extends StatefulWidget {
  const MainLayout({super.key});

  @override
  State<MainLayout> createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _selectedIndex = 0;
  bool _isSidebarExpanded = true;
  final LayerLink _notificacionesLayerLink = LayerLink();
  OverlayEntry? _notificacionesOverlay;

  final ReporteService _reporteService = ReporteService();

  List<Map<String, dynamic>> _avisosPendientes = [];
  bool _cargandoAvisos = false;
  String? _errorAvisos;
  bool _avisosInicializados = false;
  int? _ultimoUsuarioAvisos;
  int? _ultimoRolAvisos;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final usuario = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).usuarioActual;

    if (usuario != null &&
        (!_avisosInicializados ||
            _ultimoUsuarioAvisos != usuario.idUsuario ||
            _ultimoRolAvisos != usuario.idRol)) {
      _avisosInicializados = true;
      _ultimoUsuarioAvisos = usuario.idUsuario;
      _ultimoRolAvisos = usuario.idRol;

      Future.microtask(_cargarAvisosPendientes);
    }
  }

  @override
  void dispose() {
    _cerrarPanelNotificaciones();
    super.dispose();
  }

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

  Future<void> _cargarAvisosPendientes() async {
    final usuario = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).usuarioActual;

    if (usuario == null) return;

    setState(() {
      _cargandoAvisos = true;
      _errorAvisos = null;
    });

    final response = await _reporteService.obtenerAvisosPendientes(
      usuario.idUsuario,
      usuario.idRol,
    );

    if (!mounted) return;

    setState(() {
      _cargandoAvisos = false;

      if (response.status == 'success') {
        _avisosPendientes = response.data ?? [];
      } else {
        _avisosPendientes = [];
        _errorAvisos = response.message;
      }
    });
  }

  int _totalAvisosPendientes() {
    return _avisosPendientes.fold<int>(0, (total, aviso) {
      final cantidad = int.tryParse('${aviso['cantidad'] ?? 0}') ?? 0;
      return total + cantidad;
    });
  }

  IconData _obtenerIconoAviso(String idAviso) {
    switch (idAviso) {
      case 'firmar_generados':
        return Icons.edit_document;
      case 'firmar_revisados':
        return Icons.verified_user;
      case 'reportes_finales':
        return Icons.folder_shared;
      case 'firmar_boletas':
        return Icons.assignment_turned_in;
      case 'boletas_finales':
        return Icons.task;
      default:
        return Icons.notifications_none;
    }
  }

  Color _obtenerColorAviso(String idAviso) {
    switch (idAviso) {
      case 'firmar_generados':
        return Colors.orange;
      case 'firmar_revisados':
        return Colors.blue;
      case 'reportes_finales':
        return Colors.green;
      case 'firmar_boletas':
        return Colors.purple;
      case 'boletas_finales':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }

  Future<void> _navegarDesdeAviso(
    Map<String, dynamic> aviso,
    List<Map<String, dynamic>> menuItems,
  ) async {
    final moduloTitulo = aviso['modulo_titulo']?.toString() ?? '';
    final idAviso = aviso['id']?.toString() ?? '';

    final index = menuItems.indexWhere(
      (item) => item['title'] == moduloTitulo,
    );

    _cerrarPanelNotificaciones();

    if (index >= 0) {
      setState(() {
        _selectedIndex = index;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'No se encontró el módulo asociado: $moduloTitulo',
          ),
        ),
      );
    }

    if (idAviso == 'boletas_finales' || idAviso == 'reportes_finales') {
      final usuario = Provider.of<AuthProvider>(
        context,
        listen: false,
      ).usuarioActual;

      if (usuario != null) {
        await _reporteService.marcarAvisoReporteVisto(
          usuario.idUsuario,
          usuario.idRol,
          idAviso,
        );

        if (!mounted) return;

        await _cargarAvisosPendientes();
      }
    }
  }

  void _cerrarPanelNotificaciones() {
    _notificacionesOverlay?.remove();
    _notificacionesOverlay = null;
  }

  Future<void> _togglePanelNotificaciones(
    List<Map<String, dynamic>> menuItems,
  ) async {
    if (_notificacionesOverlay != null) {
      _cerrarPanelNotificaciones();
      return;
    }

    await _cargarAvisosPendientes();

    if (!mounted) return;

    _notificacionesOverlay = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _cerrarPanelNotificaciones,
                child: Container(color: Colors.transparent),
              ),
            ),
            CompositedTransformFollower(
              link: _notificacionesLayerLink,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomRight,
              followerAnchor: Alignment.topRight,
              offset: const Offset(0, 10),
              child: Material(
                color: Colors.transparent,
                child: _buildPanelNotificaciones(menuItems),
              ),
            ),
          ],
        );
      },
    );

    Overlay.of(context).insert(_notificacionesOverlay!);
  }

  Widget _buildPanelNotificaciones(
    List<Map<String, dynamic>> menuItems,
  ) {
    return Container(
      width: MediaQuery.of(context).size.width < 500
      ? MediaQuery.of(context).size.width - 32
      : 420,
      constraints: const BoxConstraints(
        maxHeight: 460,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(
              children: [
                Icon(
                  Icons.notifications_none,
                  color: Theme.of(context).primaryColor,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    "Avisos dinámicos",
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  color: Theme.of(context).primaryColor,
                  onPressed: () async {
                    await _cargarAvisosPendientes();

                    _cerrarPanelNotificaciones();

                    if (!mounted) return;

                    await _togglePanelNotificaciones(menuItems);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  color: Colors.grey[600],
                  onPressed: _cerrarPanelNotificaciones,
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          if (_cargandoAvisos)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_errorAvisos != null)
            Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                _errorAvisos!,
                style: const TextStyle(color: Colors.red),
              ),
            )
          else if (_avisosPendientes.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 45, horizontal: 20),
              child: Text(
                "No tienes avisos pendientes.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 15,
                ),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.all(10),
                itemCount: _avisosPendientes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final aviso = _avisosPendientes[index];
                  final idAviso = aviso['id']?.toString() ?? '';
                  final cantidad = aviso['cantidad']?.toString() ?? '0';
                  final titulo = aviso['titulo']?.toString() ?? 'Aviso';
                  final descripcion =
                      aviso['descripcion']?.toString() ?? '';
                  final moduloTitulo =
                      aviso['modulo_titulo']?.toString() ?? '';

                  final color = _obtenerColorAviso(idAviso);

                  return Material(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () async {
                        await _navegarDesdeAviso(
                          aviso,
                          menuItems,
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: color.withOpacity(0.18),
                              child: Icon(
                                _obtenerIconoAviso(idAviso),
                                color: color,
                                size: 21,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "$cantidad $titulo",
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1F2937),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    descripcion,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    "Ir a $moduloTitulo",
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Theme.of(context).primaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right,
                              color: Colors.black38,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    ); 
  }

  Widget _buildNotificationButton(
    ThemeData theme,
    List<Map<String, dynamic>> menuItems,
  ) {
    final totalAvisos = _totalAvisosPendientes();

    return CompositedTransformTarget(
      link: _notificacionesLayerLink,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          IconButton(
            icon: _cargandoAvisos
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.notifications_none),
            color: theme.primaryColor,
            iconSize: 28,
            onPressed: _cargandoAvisos
                ? null
                : () async {
                    await _togglePanelNotificaciones(menuItems);
                  },
          ),
          if (totalAvisos > 0)
            Positioned(
              right: 4,
              top: 4,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 5,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.red[700],
                  borderRadius: BorderRadius.circular(10),
                ),
                constraints: const BoxConstraints(minWidth: 18),
                child: Text(
                  totalAvisos > 99 ? "99+" : totalAvisos.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
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
          'view': FirmarReportesRevisadosView(
            onAvisosActualizados: _cargarAvisosPendientes,
          ),
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
          'view': FirmarReportesGeneradosView(
            onAvisosActualizados: _cargarAvisosPendientes,
          ),
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
          'view': FirmarBoletaNotasView(
            onAvisosActualizados: _cargarAvisosPendientes,
          ),
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

                // ===== INICIO DEL CAMBIO VISUAL: AVISO PIN CONFIGURACIÓN =====
                if (usuario.tienePinConfigurado == false) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Tooltip(
                      message: _isSidebarExpanded ? "" : "Falta configurar PIN de firma",
                      child: InkWell(
                        onTap: () {
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            builder: (context) => const CrearPinDialog(),
                          );
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: _isSidebarExpanded ? 12 : 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.amber.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisAlignment: _isSidebarExpanded
                                ? MainAxisAlignment.start
                                : MainAxisAlignment.center,
                            children: [
                              Icon(Icons.vpn_key_outlined, color: Colors.amber[400], size: 20),
                              if (_isSidebarExpanded) ...[
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "Falta configurar PIN",
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        "Click para crear",
                                        style: TextStyle(
                                          color: Colors.white60,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                // ===== FIN DEL CAMBIO VISUAL =====
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
<<<<<<< HEAD

=======
>>>>>>> seguridad/SDRF-2-implementación-de-pin-de-seguridad-para-firmas-mansilla
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
                        _buildNotificationButton(theme, menuItems),
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
