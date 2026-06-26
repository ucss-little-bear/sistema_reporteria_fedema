import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/Controller/auth_provider_controller.dart';
import 'package:frontend/Model/Services/usuario_service.dart';

class CrearPinDialog extends StatefulWidget {
  const CrearPinDialog({super.key});

  @override
  State<CrearPinDialog> createState() => _CrearPinDialogState();
}

class _CrearPinDialogState extends State<CrearPinDialog> {
  String _pin = '';
  bool _isPinVisible = false;

  void _onKeypadPressed(String value) {
    if (_pin.length < 4) {
      setState(() {
        _pin += value;
      });
    }
  }

  void _onBackspace() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
      });
    }
  }

  Widget _buildKeypadButton(String label, {VoidCallback? onPressed, IconData? icon}) {
    return Material(
      color: Colors.grey[100],
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed ?? () => _onKeypadPressed(label),
        child: Container(
          height: 55,
          alignment: Alignment.center,
          child: icon != null
              ? Icon(icon, color: Colors.black87, size: 22)
              : Text(
                  label,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: Container(
        padding: const EdgeInsets.all(24),
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cabecera
            Row(
              children: [
                Icon(Icons.lock_outline, color: Colors.amber[700], size: 24),
                const SizedBox(width: 10),
                const Text(
                  "Crear PIN de Firma",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              "Establezca un PIN numérico de 4 dígitos exclusivo para realizar firmas oficiales en el sistema.",
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 24),

            // Visor de PIN ingresado
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    String char = "";
                    if (index < _pin.length) {
                      char = _isPinVisible ? _pin[index] : "*";
                    }
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: 40,
                      height: 45,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: index < _pin.length ? Colors.blue : Colors.grey[300]!,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey[50],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        char,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Icon(
                    _isPinVisible ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey[600],
                  ),
                  onPressed: () {
                    setState(() {
                      _isPinVisible = !_isPinVisible;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Teclado Numérico
            Column(
              children: [
                Row(children: [Expanded(child: _buildKeypadButton('1')), const SizedBox(width: 12), Expanded(child: _buildKeypadButton('2')), const SizedBox(width: 12), Expanded(child: _buildKeypadButton('3'))]), const SizedBox(height: 12),
                Row(children: [Expanded(child: _buildKeypadButton('4')), const SizedBox(width: 12), Expanded(child: _buildKeypadButton('5')), const SizedBox(width: 12), Expanded(child: _buildKeypadButton('6'))]), const SizedBox(height: 12),
                Row(children: [Expanded(child: _buildKeypadButton('7')), const SizedBox(width: 12), Expanded(child: _buildKeypadButton('8')), const SizedBox(width: 12), Expanded(child: _buildKeypadButton('9'))]), const SizedBox(height: 12),
                Row(children: [const Expanded(child: SizedBox()), const SizedBox(width: 12), Expanded(child: _buildKeypadButton('0')), const SizedBox(width: 12), Expanded(child: _buildKeypadButton('', onPressed: _onBackspace, icon: Icons.backspace_outlined))]),
              ],
            ),
            const SizedBox(height: 28),

            // Acciones del Diálogo
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(foregroundColor: Colors.grey[700]),
                  child: const Text("Cancelar"),
                ),
                const SizedBox(width: 12),
                
                // ===== BOTÓN GUARDAR CON DEBUG =====
                ElevatedButton(
                  onPressed: _pin.length == 4
                      ? () async {
                          print("--------------------------------");
                          print("Paso 1: Botón Guardar PIN presionado");
                          try {
                            final authProvider = Provider.of<AuthProvider>(context, listen: false);
                            final usuario = authProvider.usuarioActual;
                            
                            if (usuario == null) {
                              print("Paso 1.5 ERROR FATAL: El usuario actual es NULL en el provider.");
                              return;
                            }
                            
                            final idUsuario = usuario.idUsuario;
                            print("Paso 2: Proveedor leído. Llamando servicio para Usuario ID: $idUsuario");
                            
                            bool exito = await UsuarioService().crearPinFirma(idUsuario, _pin);
                            
                            print("Paso 3: Respuesta del servicio terminada. ¿Éxito?: $exito");
                            
                            if (!context.mounted) return;
                            
                            if (exito) {
                              authProvider.actualizarEstadoPin(true);
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("PIN creado exitosamente"), backgroundColor: Colors.green),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text("Error al crear PIN"), backgroundColor: Colors.red),
                              );
                            }
                          } catch (e) {
                            print("Paso ERROR: Hubo un fallo en la interfaz de Flutter: $e");
                          }
                          print("--------------------------------");
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[200],
                    disabledForegroundColor: Colors.grey[400],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text("Guardar PIN"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}