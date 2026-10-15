import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'login.dart';

void main() {
  runApp(const MoscaApp());
}

class MoscaApp extends StatelessWidget {
  const MoscaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mosca',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF007A78),
        scaffoldBackgroundColor: const Color(0xFFF7F9F9),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF007A78),
          primary: const Color(0xFF007A78),
        ),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

// -----------------------------------------------------------------------------
// PANTALLA PRINCIPAL (CONTACTOS DE EMERGENCIA RÁPIDA DE TRUJILLO)
// -----------------------------------------------------------------------------
class HomeScreen extends StatelessWidget {
  final String userName;

  const HomeScreen({super.key, required this.userName});

  // Función para realizar la llamada telefónica directa
  Future<void> _hacerLlamada(String numero) async {
    final Uri url = Uri(scheme: 'tel', path: numero);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF007A78);

    // Lista de contactos de emergencia solicitados
    final List<Map<String, String>> emergencias = [
      {'nombre': 'Bomberos', 'numero': '116', 'sub': 'Emergencias e incendios'},
      {'nombre': 'Seguridad Ciudadana', 'numero': '044298734', 'sub': 'Serenazgo Trujillo'},
      {'nombre': 'Policía Nacional del Perú', 'numero': '105', 'sub': 'Emergencias policiales'},
      {'nombre': 'SAMU', 'numero': '106', 'sub': 'Atención médica de urgencia'},
    ];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabecera con Nombre de Usuario y Ubicación
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TRUJILLO · PERÚ',
                        style: TextStyle(fontSize: 11, color: primaryColor, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Hola, $userName',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  CircleAvatar(
                    backgroundColor: const Color(0xFFE6F4F1),
                    child: Text(
                      userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                      style: const TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              const Text(
                'Contactos de Emergencia Rápida',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              const Text(
                'Presiona el botón de llamar para comunicarte de inmediato:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),

              // Lista de emergencias
              Expanded(
                child: ListView.builder(
                  itemCount: emergencias.length,
                  itemBuilder: (context, index) {
                    final e = emergencias[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                      color: Colors.white,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE6F4F1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.phone_in_talk, color: primaryColor),
                        ),
                        title: Text(e['nombre']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text('${e['sub']} (${e['numero']})', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: () => _hacerLlamada(e['numero']!),
                          child: const Text('Llamar', style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Botón de Alerta SOS General
              Container(
                width: double.infinity,
                height: 56,
                margin: const EdgeInsets.only(top: 8),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: () => _hacerLlamada('105'),
                  icon: const Icon(Icons.warning, color: Colors.white),
                  label: const Text(
                    'ALERTA SOS (LLAMAR 105)',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // Barra de navegación inferior
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.map_outlined), label: 'Inicio'),
          BottomNavigationBarItem(icon: Icon(Icons.people_outline), label: 'Comunidad'),
          BottomNavigationBarItem(icon: Icon(Icons.shield_outlined), label: 'Círculo'),
          BottomNavigationBarItem(icon: Icon(Icons.tune), label: 'Ajustes'),
        ],
      ),
    );
  }
}