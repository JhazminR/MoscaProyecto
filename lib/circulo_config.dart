import 'package:flutter/material.dart';
import 'main.dart';

class CirculoConfigScreen extends StatefulWidget {
  final String userName;
  const CirculoConfigScreen({super.key, required this.userName});

  @override
  State<CirculoConfigScreen> createState() => _CirculoConfigScreenState();
}

class _CirculoConfigScreenState extends State<CirculoConfigScreen> {
  final List<Map<String, dynamic>> _contactos = [];
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  void _agregarContactoModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Invita a tu persona', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text('La invitación es el primer paso. Solo podrá recibir alertas cuando la acepte.'),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nombre del contacto', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Celular con código de país', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF007A78)),
                onPressed: () {
                  if (_nameController.text.isNotEmpty) {
                    setState(() {
                      _contactos.add({
                        'nombre': _nameController.text,
                        'telefono': _phoneController.text,
                        'estado': 'Aceptó', // Simulado tras el envío del Bot
                      });
                    });
                    _nameController.clear();
                    _phoneController.clear();
                    Navigator.pop(context);
                  }
                },
                child: const Text('Enviar invitación por WhatsApp', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Abrir Chat Bot Asistente IA (Simulador de las 4 opciones)
  void _abrirAsistenteBot() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AsistenteBotSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF007A78);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F9),
      appBar: AppBar(
        title: const Text('Configurar círculo de confianza'),
        backgroundColor: Colors.white,
        foregroundColor: primaryColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Banner Informativo inicial
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Siempre cerca.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
                  const SizedBox(height: 6),
                  const Text('No estás sola. Estamos en tu círculo.', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  const Text('De 1 a 5 contactos autorizados para recibir tu ubicación y alertas.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _agregarContactoModal,
                      child: const Text('Configurar mi círculo', style: TextStyle(color: Colors.white, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Lista de contactos agregados
            Text('Tus contactos (${_contactos.length} de 5)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 12),
            _contactos.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(20),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: const Text('Aún no hay contactos agregados. Pulsa arriba para empezar.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _contactos.length,
                    itemBuilder: (context, index) {
                      final c = _contactos[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(backgroundColor: primaryColor, child: Text(c['nombre'][0], style: const TextStyle(color: Colors.white))),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(c['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                    Text(c['telefono'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                              child: Text(c['estado'], style: const TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 24),

            // Botón para probar el Bot Asistente IA (Las 4 opciones)
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: primaryColor),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _abrirAsistenteBot,
                icon: const Icon(Icons.smart_toy_outlined, color: primaryColor),
                label: const Text('Probar Bot Asistente IA (Seguimiento)', style: TextStyle(color: primaryColor)),
              ),
            ),
            const SizedBox(height: 16),

            // Botón para pasar al Mapa Principal
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _contactos.isEmpty ? Colors.grey : primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _contactos.isEmpty
                    ? null
                    : () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => HomeScreen(userName: widget.userName)),
                        );
                      },
                child: const Text('Activar mapa y compartir ubicación', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// WIDGET DEL BOT ASISTENTE IA (CON LAS 4 OPCIONES DEL PROTOTIPO)
// -----------------------------------------------------------------------------
class AsistenteBotSheet extends StatefulWidget {
  const AsistenteBotSheet({super.key});

  @override
  State<AsistenteBotSheet> createState() => _AsistenteBotSheetState();
}

class _AsistenteBotSheetState extends State<AsistenteBotSheet> {
  String _estadoActual = "Asistente IA: ¿Cómo estás Lucía? Se activó una alerta SOS.";

  void _responderOpcion(int opcion) {
    setState(() {
      switch (opcion) {
        case 1:
          _estadoActual = "¡Excelente! Has marcado: 'Ya con él/ella, todo bien.' Círculo notificado de que estás a salvo.";
          break;
        case 2:
          _estadoActual = "Registrado: 'En camino, ya en contacto y seguro/a.'";
          break;
        case 3:
          _estadoActual = "Alerta: 'Ubicación recibida, pero no responde.' Derivando automáticamente al siguiente contacto...";
          break;
        case 4:
          _estadoActual = "Emergencia: 'No puedo ayudar.' Derivando aviso a servicios de emergencia.";
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF007A78);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.smart_toy, color: primaryColor),
                  SizedBox(width: 8),
                  Text('Asistente Mosca (IA)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const Divider(),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFFE6F4F1), borderRadius: BorderRadius.circular(12)),
            child: Text(_estadoActual, style: const TextStyle(color: primaryColor, fontWeight: FontWeight.w500)),
          ),
          const SizedBox(height: 20),
          const Text('Elige una respuesta rápida para el bot:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 10),

          // Las 4 Opciones del prototipo
          Expanded(
            child: ListView(
              children: [
                _buildOpcionCard(1, 'Ya con él/ella, todo bien.', 'Confirma compañía y seguridad.'),
                _buildOpcionCard(2, 'En camino, ya en contacto y seguro/a.', 'Confirma tránsito seguro.'),
                _buildOpcionCard(3, 'Ubicación recibida, pero no responde.', 'Deriva automáticamente al siguiente contacto.'),
                _buildOpcionCard(4, 'No puedo ayudar.', 'Deriva aviso y activa protocolo de emergencia.'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOpcionCard(int id, String titulo, String subtitulo) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        subtitle: Text(subtitulo, style: const TextStyle(fontSize: 11)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF007A78)),
        onTap: () => _responderOpcion(id),
      ),
    );
  }
}