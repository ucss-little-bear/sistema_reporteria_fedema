import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:frontend/Controller/auth_provider_controller.dart';
import 'package:frontend/Model/Services/usuario_service.dart';

class ValidarPinDialog extends StatefulWidget {
  const ValidarPinDialog({super.key});

  @override
  State<ValidarPinDialog> createState() => _ValidarPinDialogState();
}

class _ValidarPinDialogState extends State<ValidarPinDialog> {
  String _pin = '';
  bool _isPinVisible = false;

  void _onKeypadPressed(String value) {
    if (_pin.length < 4) setState(() => _pin += value);
  }

  void _onBackspace() {
    if (_pin.isNotEmpty)
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Widget _buildKeypadButton(
    String label, {
    VoidCallback? onPressed,
    IconData? icon,
  }) {
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
      child: Container(
        padding: const EdgeInsets.all(24),
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  Icons.verified_user_outlined,
                  color: Colors.blue[700],
                  size: 24,
                ),
                const SizedBox(width: 10),
                const Text(
                  "Validar Identidad",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              "Ingrese su PIN de 4 dígitos para autorizar la firma del documento.",
              style: TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: List.generate(4, (index) {
                    String char = index < _pin.length
                        ? (_isPinVisible ? _pin[index] : "*")
                        : "";
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      width: 40,
                      height: 45,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: index < _pin.length
                              ? Colors.blue
                              : Colors.grey[300]!,
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
                IconButton(
                  icon: Icon(
                    _isPinVisible ? Icons.visibility_off : Icons.visibility,
                    color: Colors.grey[600],
                  ),
                  onPressed: () =>
                      setState(() => _isPinVisible = !_isPinVisible),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Teclado
            Column(
              children: [
                Row(
                  children: [
                    Expanded(child: _buildKeypadButton('1')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildKeypadButton('2')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildKeypadButton('3')),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildKeypadButton('4')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildKeypadButton('5')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildKeypadButton('6')),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildKeypadButton('7')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildKeypadButton('8')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildKeypadButton('9')),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Expanded(child: SizedBox()),
                    const SizedBox(width: 12),
                    Expanded(child: _buildKeypadButton('0')),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildKeypadButton(
                        '',
                        onPressed: _onBackspace,
                        icon: Icons.backspace_outlined,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 28),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text(
                    "Cancelar",
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _pin.length == 4
                      ? () async {
                          final id = Provider.of<AuthProvider>(
                            context,
                            listen: false,
                          ).usuarioActual!.idUsuario;
                          bool valido = await UsuarioService()
                              .verificarPinFirma(id, _pin);
                          if (!context.mounted) return;
                          if (valido) {
                            Navigator.pop(
                              context,
                              true,
                            ); // Retorna true si pasó
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("PIN Incorrecto"),
                                backgroundColor: Colors.red,
                              ),
                            );
                            setState(
                              () => _pin = '',
                            ); // Limpia para intentar de nuevo
                          }
                        }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Validar y Firmar"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
