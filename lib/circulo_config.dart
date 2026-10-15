import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:permission_handler/permission_handler.dart';
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

  // Función para enviar WhatsApp con enlace web personalizado y dinámico
  Future<void> _enviarWhatsApp(String telefono, String contactoNombre) async {
    // Aquí puedes reemplazar 'https://tupaginaweb.com/mosca-auth' por tu link real de GitHub Pages o Netlify
    final String urlBaseWeb = 'https://tupaginaweb.com/mosca-auth';
    final String enlacePersonalizado = '$urlBaseWeb?de=${Uri.encodeComponent(widget.userName)}&para=${Uri.encodeComponent(contactoNombre)}&tel=$telefono';

    final mensaje = 
        '🛡️ *MOSCA - Círculo de Seguridad*\n\n'
        'Hola $contactoNombre, soy ${widget.userName}. Te he añadido a mi círculo de confianza.\n\n'
        'Para activar los permisos de recepción de alertas y ubicación SOS, por favor ingresa al siguiente enlace y confirma:\n\n'
        '👉 $enlacePersonalizado';

    final url = Uri.parse('https://wa.me/51$telefono?text=${Uri.encodeComponent(mensaje)}');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir WhatsApp en este dispositivo.')),
        );
      }
    }
  }

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
            const Text('Invita a tu contacto', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Se le enviará un mensaje con un enlace web personalizado para que acepte los permisos de seguridad.', style: TextStyle(fontSize: 12, color: Colors.grey)),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Nombre del contacto', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Celular (+51)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366)),
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: () {
                  if (_nameController.text.isNotEmpty && _phoneController.text.isNotEmpty) {
                    final String nombre = _nameController.text;
                    final String telefono = _phoneController.text;

                    setState(() {
                      _contactos.add({
                        'nombre': nombre,
                        'telefono': telefono,
                        'estado': 'Pendiente', // Inicia en pendiente hasta que el enlace responda
                      });
                    });

                    _enviarWhatsApp(telefono, nombre);

                    _nameController.clear();
                    _phoneController.clear();
                    Navigator.pop(context);
                  }
                },
                label: const Text('Enviar Enlace por WhatsApp', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Simulación interactiva del enlace web cuando el usuario pulsa el contacto
  void _verificarEnlaceWeb(int index) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Verificar Enlace: ${_contactos[index]['nombre']}'),
        content: const Text(
          'El contacto ha recibido su enlace web personalizado.\n\n'
          '¿Deseas confirmar que la persona abrió el enlace y pulsó "Aceptar Permisos"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF007A78)),
            onPressed: () {
              setState(() {
                _contactos[index]['estado'] = 'Aceptó';
              });
              Navigator.pop(ctx);
            },
            child: const Text('Confirmar Aceptación', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _solicitarPermisosYContinuar() async {
    PermissionStatus statusUbicacion = await Permission.location.request();

    if (statusUbicacion.isGranted) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(userName: widget.userName),
          ),
        );
      }
    } else {
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Permiso de Ubicación Necesario'),
            content: const Text('Mosca necesita acceso a tu ubicación para compartir coordenadas con tu círculo de confianza.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido')),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF007A78);
    final int aceptadosCount = _contactos.where((c) => c['estado'] == 'Aceptó').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F9),
      appBar: AppBar(
        title: const Text('Círculo de Confianza'),
        backgroundColor: Colors.white,
        foregroundColor: primaryColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  Text('Hola, ${widget.userName}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
                  const SizedBox(height: 6),
                  const Text('Comparte el enlace web de autorización con tus contactos de confianza.', style: TextStyle(fontSize: 13)),
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
                      child: const Text('Agregar nuevo contacto', style: TextStyle(color: Colors.white, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            Text('Contactos agregados (${_contactos.length} de 5)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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
                    child: const Text('Aún no hay contactos agregados.', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _contactos.length,
                    itemBuilder: (context, index) {
                      final c = _contactos[index];
                      final bool esAceptado = c['estado'] == 'Aceptó';

                      return InkWell(
                        onTap: () => _verificarEnlaceWeb(index),
                        child: Container(
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
                                  CircleAvatar(
                                    backgroundColor: esAceptado ? primaryColor : Colors.orange,
                                    child: Text(c['nombre'][0], style: const TextStyle(color: Colors.white)),
                                  ),
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
                                decoration: BoxDecoration(
                                  color: esAceptado ? Colors.green.shade50 : Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  c['estado'],
                                  style: TextStyle(
                                    color: esAceptado ? Colors.green : Colors.orange.shade800,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),

            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: aceptadosCount == 0 ? Colors.grey : primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: aceptadosCount == 0 ? null : _solicitarPermisosYContinuar,
                child: Text(
                  aceptadosCount == 0 ? 'Esperando aceptación del enlace web...' : 'Activar mi círculo e ingresar',
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}