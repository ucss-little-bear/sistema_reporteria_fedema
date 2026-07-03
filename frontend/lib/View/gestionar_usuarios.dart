import 'package:flutter/material.dart';
import 'package:frontend/Controller/auth_provider_controller.dart';
import 'package:frontend/Controller/usuario_provider_controller.dart';
import 'package:frontend/Model/Entities/usuario_entity.dart';
import 'package:frontend/Model/Services/usuario_service.dart';

import 'package:provider/provider.dart';

class GestionarUsuariosView extends StatefulWidget {
  const GestionarUsuariosView({super.key});

  @override
  State<GestionarUsuariosView> createState() => _GestionarUsuariosViewState();
}

class _GestionarUsuariosViewState extends State<GestionarUsuariosView> {
  final TextEditingController _searchController = TextEditingController();
  String _filtroRol = 'Todos';
  String _filtroEstado = 'Todos';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<UsuarioProvider>(context, listen: false).cargarUsuarios();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _abrirDialogoUsuario({Usuario? usuarioEditar}) {
    showDialog(
      context: context,
      builder: (context) => DialogUsuario(usuario: usuarioEditar),
    );
  }

  void _abrirDialogoPassword(Usuario usuario) {
    showDialog(
      context: context,
      builder: (context) => DialogCambiarPassword(usuario: usuario),
    );
  }

  void _confirmarCambioEstado(Usuario user) {
    final currentUser = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).usuarioActual;

    if (currentUser != null && currentUser.idUsuario == user.idUsuario) {
      showDialog(
        context: context,
        builder: (c) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: const [
              Icon(Icons.error_outline, color: Colors.red),
              SizedBox(width: 10),
              Text("Acción Denegada"),
            ],
          ),
          content: const Text(
            "Por seguridad, no puede desactivar su propia cuenta mientras está en uso.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c),
              child: const Text("Entendido"),
            ),
          ],
        ),
      );
      return;
    }

    bool esActivo = (user.estado == 1);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            Icon(
              esActivo
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_outline,
              color: esActivo ? Colors.orange : Colors.green,
            ),
            const SizedBox(width: 10),
            Text(esActivo ? "Desactivar Usuario" : "Activar Usuario"),
          ],
        ),
        content: Text(
          "¿Está seguro que desea ${esActivo ? 'desactivar' : 'activar'} al usuario ${user.nombres}?",
          style: const TextStyle(color: Colors.black87),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Provider.of<UsuarioProvider>(
                context,
                listen: false,
              ).cambiarEstado(user.idUsuario, user.estado);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: esActivo ? Colors.orange : Colors.green,
            ),
            child: Text(esActivo ? "Desactivar" : "Activar"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final usuarioProvider = context.watch<UsuarioProvider>();

    List<Usuario> usuariosFiltrados = usuarioProvider.usuarios.where((user) {
      final query = _searchController.text.toLowerCase();
      final nombreCompleto = "${user.nombres} ${user.apellidos}".toLowerCase();
      final username = user.nombreUsuario.toLowerCase();
      bool matchTexto =
          query.isEmpty ||
          nombreCompleto.contains(query) ||
          username.contains(query);

      bool matchRol = true;
      if (_filtroRol != 'Todos') {
        final rolBackend = (user.rolDescripcion ?? "").toLowerCase();
        if (_filtroRol == 'Secretaría Académica') {
          matchRol = rolBackend.contains('secretar') || rolBackend == '1';
        } else if (_filtroRol == 'Directora') {
          matchRol = rolBackend.contains('director') || rolBackend == '2';
        } else if (_filtroRol == 'Docente') {
          matchRol = rolBackend.contains('docente') || rolBackend == '3';
        }
      }

      bool matchEstado = true;
      if (_filtroEstado != 'Todos') {
        final esActivo = (user.estado == 1);
        if (_filtroEstado == 'Activo') matchEstado = esActivo;
        if (_filtroEstado == 'Inactivo') matchEstado = !esActivo;
      }
      return matchTexto && matchRol && matchEstado;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Gestionar Cuentas de Usuarios",
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.primaryColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Administre las cuentas de usuario del sistema.",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: () => _abrirDialogoUsuario(),
              icon: const Icon(Icons.person_add, size: 20),
              label: const Text("Crear Usuario"),
            ),
          ],
        ),
        const SizedBox(height: 32),

        Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Filtros de Búsqueda",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _searchController,
                        decoration: const InputDecoration(
                          labelText: "Buscar por nombre o usuario",
                          prefixIcon: Icon(Icons.search),
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 0,
                            horizontal: 12,
                          ),
                        ),
                        onChanged: (val) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _filtroRol,
                        decoration: const InputDecoration(
                          labelText: "Rol",
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 0,
                          ),
                        ),
                        items:
                            [
                                  'Todos',
                                  'Secretaría Académica',
                                  'Directora',
                                  'Docente',
                                ]
                                .map(
                                  (rol) => DropdownMenuItem(
                                    value: rol,
                                    child: Text(rol),
                                  ),
                                )
                                .toList(),
                        onChanged: (val) => setState(() => _filtroRol = val!),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _filtroEstado,
                        decoration: const InputDecoration(
                          labelText: "Estado",
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 0,
                          ),
                        ),
                        items: ['Todos', 'Activo', 'Inactivo']
                            .map(
                              (est) => DropdownMenuItem(
                                value: est,
                                child: Text(est),
                              ),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _filtroEstado = val!),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        Expanded(
          child: Card(
            child: usuarioProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : usuariosFiltrados.isEmpty
                ? Center(
                    child: Text(
                      "No se encontraron usuarios",
                      style: TextStyle(color: Colors.grey[500]),
                    ),
                  )
                : SingleChildScrollView(
                    scrollDirection: Axis.vertical,
                    child: SizedBox(
                      width: double.infinity,
                      child: DataTable(
                        headingRowColor: WidgetStateProperty.all(
                          Colors.grey[50],
                        ),
                        columns: const [
                          DataColumn(
                            label: Text(
                              "Nombre",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              "Usuario",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              "Rol",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              "Estado",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          DataColumn(
                            label: Text(
                              "Acciones",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                        rows: usuariosFiltrados.map((user) {
                          bool isActive = (user.estado == 1);

                          return DataRow(
                            cells: [
                              DataCell(
                                Text("${user.nombres} ${user.apellidos}"),
                              ),
                              DataCell(Text(user.nombreUsuario)),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                  child: Text(
                                    user.rolDescripcion ?? "N/A",
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                              DataCell(
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? Colors.green[50]
                                        : Colors.red[50],
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isActive
                                          ? Colors.green[200]!
                                          : Colors.red[200]!,
                                    ),
                                  ),
                                  child: Text(
                                    isActive ? "Activo" : "Inactivo",
                                    style: TextStyle(
                                      color: isActive
                                          ? Colors.green[800]
                                          : Colors.red[800],
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Row(
                                  children: [
                                    IconButton(
                                      tooltip: "Editar usuario",
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        color: Colors.blue,
                                      ),
                                      onPressed: () => _abrirDialogoUsuario(
                                        usuarioEditar: user,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.lock_reset,
                                        color: Colors.orange,
                                      ),
                                      tooltip: "Resetear PIN",
                                      onPressed: () async {
                                        bool confirmacion =
                                            await showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                title: const Text(
                                                  "Resetear PIN",
                                                ),
                                                content: Text(
                                                  "¿Desea borrar el PIN de ${user.nombres}? Tendrá que crear uno nuevo.",
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          context,
                                                          false,
                                                        ),
                                                    child: const Text(
                                                      "Cancelar",
                                                    ),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          context,
                                                          true,
                                                        ),
                                                    style:
                                                        ElevatedButton.styleFrom(
                                                          backgroundColor:
                                                              Colors.red,
                                                          foregroundColor:
                                                              Colors.white,
                                                        ),
                                                    child: const Text(
                                                      "Resetear",
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ) ??
                                            false;

                                        if (confirmacion) {
                                          bool exito = await UsuarioService()
                                              .resetearPinFirma(user.idUsuario);
                                          if (!context.mounted) return;

                                          if (exito) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  "PIN reseteado correctamente",
                                                ),
                                                backgroundColor: Colors.green,
                                              ),
                                            );

                                            // 1. Recargar la lista de la tabla
                                            Provider.of<UsuarioProvider>(
                                              context,
                                              listen: false,
                                            ).cargarUsuarios();

                                            // 2. LA SOLUCIÓN: Si la secretaria borra SU PROPIO PIN, actualizamos la alerta lateral al instante
                                            final authProvider =
                                                Provider.of<AuthProvider>(
                                                  context,
                                                  listen: false,
                                                );
                                            if (authProvider
                                                    .usuarioActual
                                                    ?.idUsuario ==
                                                user.idUsuario) {
                                              authProvider.actualizarEstadoPin(
                                                false,
                                              );
                                            }
                                          } else {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  "Error al resetear PIN",
                                                ),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          }
                                        }
                                      },
                                    ),
                                    IconButton(
                                      tooltip: "Cambiar contraseña",
                                      icon: const Icon(
                                        Icons.key,
                                        color: Colors.amber,
                                      ),
                                      onPressed: () =>
                                          _abrirDialogoPassword(user),
                                    ),
                                    IconButton(
                                      tooltip: isActive
                                          ? "Desactivar usuario"
                                          : "Activar usuario",
                                      icon: Icon(
                                        isActive
                                            ? Icons.block
                                            : Icons.check_circle_outline,
                                        color: isActive
                                            ? Colors.red
                                            : Colors.green,
                                      ),
                                      onPressed: () =>
                                          _confirmarCambioEstado(user),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

class DialogUsuario extends StatefulWidget {
  final Usuario? usuario;

  const DialogUsuario({super.key, this.usuario});

  @override
  State<DialogUsuario> createState() => _DialogUsuarioState();
}

class _DialogUsuarioState extends State<DialogUsuario> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nombresCtrl;
  late TextEditingController _apellidosCtrl;
  late TextEditingController _dniCtrl;
  late TextEditingController _correoCtrl;
  late TextEditingController _usuarioCtrl;
  late TextEditingController _passCtrl;
  late TextEditingController _confirmPassCtrl;

  late int _rolSeleccionado;
  bool _obscurePass = true;

  @override
  void initState() {
    super.initState();
    _nombresCtrl = TextEditingController(text: widget.usuario?.nombres ?? '');
    _apellidosCtrl = TextEditingController(
      text: widget.usuario?.apellidos ?? '',
    );
    _dniCtrl = TextEditingController(
      text: widget.usuario?.dni?.toString() ?? '',
    );
    _correoCtrl = TextEditingController(text: widget.usuario?.correo ?? '');
    _usuarioCtrl = TextEditingController(
      text: widget.usuario?.nombreUsuario ?? '',
    );
    _passCtrl = TextEditingController();
    _confirmPassCtrl = TextEditingController();

    _rolSeleccionado = widget.usuario?.idRol ?? 3;
  }

  @override
  void dispose() {
    _nombresCtrl.dispose();
    _apellidosCtrl.dispose();
    _dniCtrl.dispose();
    _correoCtrl.dispose();
    _usuarioCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _guardarConConfirmacion() async {
    if (!_formKey.currentState!.validate()) return;

    final esEdicion = widget.usuario != null;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(esEdicion ? "Confirmar Edición" : "Confirmar Creación"),
        content: Text(
          esEdicion
              ? "¿Está seguro de guardar los cambios para este usuario?"
              : "¿Está seguro de crear este nuevo usuario?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("No", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
            ),
            child: const Text("Sí, Guardar"),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      final provider = Provider.of<UsuarioProvider>(context, listen: false);

      final datos = {
        "nombres": _nombresCtrl.text.trim(),
        "apellidos": _apellidosCtrl.text.trim(),
        "dni": _dniCtrl.text.trim(),
        "id_rol": _rolSeleccionado,
        "usuario": _usuarioCtrl.text.trim(),
        "correo": _correoCtrl.text.trim(),
      };

      bool success;
      if (esEdicion) {
        datos["id_usuario"] = widget.usuario!.idUsuario;
        success = await provider.editarUsuario(datos);
      } else {
        datos["password"] = _passCtrl.text;
        success = await provider.crearUsuario(datos);
      }

      if (mounted) {
        if (success) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                esEdicion ? "Usuario actualizado" : "Usuario creado",
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(provider.errorMessage ?? "Error"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool esEdicion = widget.usuario != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            esEdicion ? "Editar Usuario" : "Crear Usuario",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
          ),
          const SizedBox(height: 4),
          Text(
            "Complete la información requerida",
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
              fontWeight: FontWeight.normal,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _nombresCtrl,
                      decoration: const InputDecoration(labelText: "Nombres"),
                      validator: (v) => v!.isEmpty ? 'Requerido' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _apellidosCtrl,
                      decoration: const InputDecoration(labelText: "Apellidos"),
                      validator: (v) => v!.isEmpty ? 'Requerido' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _dniCtrl,
                      decoration: const InputDecoration(
                        labelText: "DNI",
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      keyboardType: TextInputType.number,
                      maxLength: 8,
                      validator: (v) =>
                          (v!.isEmpty || v.length != 8) ? '8 dígitos' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 3,
                    child: DropdownButtonFormField<int>(
                      initialValue: _rolSeleccionado,
                      decoration: const InputDecoration(
                        labelText: "Rol",
                        prefixIcon: Icon(Icons.admin_panel_settings_outlined),
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 1,
                          child: Text("Secretaría Académica"),
                        ),
                        DropdownMenuItem(value: 2, child: Text("Directora")),
                        DropdownMenuItem(value: 3, child: Text("Docente")),
                      ],
                      onChanged: (val) =>
                          setState(() => _rolSeleccionado = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _correoCtrl,
                decoration: const InputDecoration(
                  labelText: "Correo Electrónico",
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                    (v!.isEmpty || !v.contains('@')) ? 'Inválido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _usuarioCtrl,
                decoration: const InputDecoration(
                  labelText: "Nombre de Usuario",
                  prefixIcon: Icon(Icons.account_circle_outlined),
                ),
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
              if (!esEdicion) ...[
                const SizedBox(height: 24),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Seguridad",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _passCtrl,
                        obscureText: _obscurePass,
                        decoration: InputDecoration(
                          labelText: "Contraseña",
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePass
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                            onPressed: () =>
                                setState(() => _obscurePass = !_obscurePass),
                          ),
                        ),
                        validator: (v) => v!.length < 6 ? 'Mínimo 6' : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _confirmPassCtrl,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: "Confirmar",
                          prefixIcon: Icon(Icons.lock_reset),
                        ),
                        validator: (v) =>
                            v != _passCtrl.text ? 'No coinciden' : null,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          ),
          child: const Text("Cancelar"),
        ),
        ElevatedButton(
          onPressed: _guardarConConfirmacion,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          ),
          child: Text(esEdicion ? "Actualizar" : "Guardar Usuario"),
        ),
      ],
    );
  }
}

class DialogCambiarPassword extends StatefulWidget {
  final Usuario usuario;

  const DialogCambiarPassword({super.key, required this.usuario});

  @override
  State<DialogCambiarPassword> createState() => _DialogCambiarPasswordState();
}

class _DialogCambiarPasswordState extends State<DialogCambiarPassword> {
  final _formKey = GlobalKey<FormState>();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _cambiarPassword() async {
    if (!_formKey.currentState!.validate()) return;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text("Confirmar Cambio"),
        content: Text(
          "¿Está seguro de cambiar la contraseña para el usuario ${widget.usuario.nombreUsuario}?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancelar"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber[800]),
            child: const Text("Sí, Cambiar"),
          ),
        ],
      ),
    );

    if (confirmar == true && mounted) {
      final success = await Provider.of<UsuarioProvider>(
        context,
        listen: false,
      ).cambiarPassword(widget.usuario.idUsuario, _passCtrl.text);

      if (mounted) {
        if (success) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Contraseña actualizada exitosamente"),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Error al cambiar contraseña"),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        "Cambiar Contraseña",
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Usuario: ${widget.usuario.nombres} ${widget.usuario.apellidos}",
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _passCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: "Nueva Contraseña",
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
                validator: (v) => v!.length < 6 ? 'Mínimo 6 caracteres' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Confirmar Contraseña",
                  prefixIcon: Icon(Icons.lock_reset),
                ),
                validator: (v) =>
                    v != _passCtrl.text ? 'Las contraseñas no coinciden' : null,
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.all(24),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancelar"),
        ),
        ElevatedButton(
          onPressed: _cambiarPassword,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.amber[700],
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
          child: const Text("Cambiar Contraseña"),
        ),
      ],
    );
  }
}
