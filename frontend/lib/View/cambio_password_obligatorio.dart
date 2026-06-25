import 'package:flutter/material.dart';
import 'package:frontend/View/main_layout.dart';

import 'package:provider/provider.dart';
import 'package:frontend/Controller/auth_provider_controller.dart';
import 'package:frontend/Controller/usuario_provider_controller.dart';

class CambioPasswordObligatorioScreen extends StatefulWidget {
  const CambioPasswordObligatorioScreen({super.key});

  @override
  State<CambioPasswordObligatorioScreen> createState() => _CambioPasswordObligatorioScreenState();
}

class _CambioPasswordObligatorioScreenState extends State<CambioPasswordObligatorioScreen> {
  final _currentController = TextEditingController();
  final _nextController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _showCurrent = false;
  bool _showNext = false;
  bool _showConfirm = false;

  bool _isSuccess = false;

  @override
  void dispose() {
    _currentController.dispose();
    _nextController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  bool get _hasMinLength => _nextController.text.length >= 8;
  bool get _hasUpper => _nextController.text.contains(RegExp(r'[A-Z]'));
  bool get _hasNumber => _nextController.text.contains(RegExp(r'[0-9]'));
  
  bool get _strengthOk => _hasMinLength && _hasUpper && _hasNumber;
  bool get _match => _nextController.text.isNotEmpty && _nextController.text == _confirmController.text;
  bool get _canSubmit => _currentController.text.isNotEmpty && _strengthOk && _match;

  void _onSubmit() async {
    if (!_canSubmit) return;

    // Llamamos a los proveedores
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final usuarioProvider = Provider.of<UsuarioProvider>(context, listen: false);
    final usuario = authProvider.usuarioActual;
    
    if (usuario == null) return;

    // Conectamos con tu backend en PHP para guardar la nueva clave
    bool success = await usuarioProvider.cambiarPassword(usuario.idUsuario, _nextController.text);
    
    if (success) {
      // Apagamos el interruptor en la memoria
      authProvider.completarPrimerLogin();
      
      // Mostramos la tarjeta de éxito
      setState(() {
        _isSuccess = true;
      });
    } else {
      // Si algo falla en el servidor, avisamos
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al conectar con el servidor.'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        automaticallyImplyLeading: false, // Quita el botón de atrás (Regla de seguridad)
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.school, size: 20, color: theme.primaryColor),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SISTEMA DE REPORTERÍA FEDEMA',
                  style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
                Text(
                  _isSuccess ? 'Cambio Exitoso' : 'Activación de Cuenta',
                  style: const TextStyle(fontSize: 16, color: Colors.black87, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
      ),
      
      // AQUI ESTÁ EL CAMBIO CLAVE PARA EL SCROLL
      body: SingleChildScrollView(
        child: Container(
          width: double.infinity, // Obliga al scroll a irse al borde derecho exacto
          constraints: BoxConstraints(
            // Mantiene tu tarjeta blanca perfectamente centrada verticalmente
            minHeight: size.height - kToolbarHeight - MediaQuery.of(context).padding.top,
          ),
          alignment: Alignment.center,
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 450),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10)),
              ],
            ),
            padding: const EdgeInsets.all(32),
            child: _isSuccess ? _buildSuccessState(theme) : _buildFormState(theme),
          ),
        ),
      ),
    );
  }

  Widget _buildFormState(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Banner de Atención
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.primaryColor.withOpacity(0.05),
            border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lock_outline, color: theme.primaryColor, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.black87, fontSize: 13, height: 1.5),
                    children: [
                      const TextSpan(text: '¡Atención! ', style: TextStyle(fontWeight: FontWeight.bold)),
                      const TextSpan(text: 'Por seguridad de la información del colegio FEDEMA, debes personalizar tu contraseña para continuar.'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        
        const Text('Cambiar Contraseña', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const Text('Establece una contraseña personal y segura.', style: TextStyle(fontSize: 14, color: Colors.grey)),
        const SizedBox(height: 24),

        _buildPasswordField(
          label: 'Contraseña Temporal Actual',
          controller: _currentController,
          isVisible: _showCurrent,
          onToggle: () => setState(() => _showCurrent = !_showCurrent),
        ),
        const SizedBox(height: 16),
        _buildPasswordField(
          label: 'Nueva Contraseña',
          controller: _nextController,
          isVisible: _showNext,
          onToggle: () => setState(() => _showNext = !_showNext),
        ),
        const SizedBox(height: 16),
        _buildPasswordField(
          label: 'Confirmar Nueva Contraseña',
          controller: _confirmController,
          isVisible: _showConfirm,
          onToggle: () => setState(() => _showConfirm = !_showConfirm),
        ),
        
        const SizedBox(height: 24),
        
        // Panel de Requisitos
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.shield_outlined, size: 16, color: theme.primaryColor),
                  const SizedBox(width: 8),
                  const Text('Requisitos de Contraseña', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                ],
              ),
              const SizedBox(height: 12),
              _buildRequirementRow(_hasMinLength, 'Mínimo 8 caracteres'),
              const SizedBox(height: 8),
              _buildRequirementRow(_hasUpper, 'Al menos una mayúscula'),
              const SizedBox(height: 8),
              _buildRequirementRow(_hasNumber, 'Al menos un número'),
            ],
          ),
        ),

        const SizedBox(height: 32),

        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _canSubmit ? _onSubmit : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              disabledBackgroundColor: theme.primaryColor.withOpacity(0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Establecer Nueva Contraseña y Entrar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField({required String label, required TextEditingController controller, required bool isVisible, required VoidCallback onToggle}) {
    return TextFormField(
      controller: controller,
      obscureText: !isVisible,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(Icons.lock_outline_rounded, color: Colors.grey[400]),
        suffixIcon: IconButton(
          icon: Icon(isVisible ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.grey[400]),
          onPressed: onToggle,
        ),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).primaryColor.withOpacity(0.5))),
      ),
    );
  }

  Widget _buildRequirementRow(bool isMet, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: isMet ? Colors.green : Colors.transparent,
            border: Border.all(color: isMet ? Colors.green : Colors.grey.shade300),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.check, size: 10, color: isMet ? Colors.white : Colors.transparent),
        ),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(fontSize: 13, color: isMet ? Colors.black87 : Colors.grey.shade600)),
      ],
    );
  }

  Widget _buildSuccessState(ThemeData theme) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), shape: BoxShape.circle),
          child: const Icon(Icons.check_circle, size: 64, color: Colors.green),
        ),
        const SizedBox(height: 24),
        const Text('¡Contraseña actualizada exitosamente!', textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        const Text('Ahora tienes control exclusivo de tu cuenta.', style: TextStyle(color: Colors.grey)),
        const SizedBox(height: 40),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () {
              // Navega al Layout Principal al finalizar
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainLayout()));
            },
            icon: const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
            label: const Text('Ir al Inicio (Dashboard)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: theme.primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          ),
        ),
      ],
    );
  }
}