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
// PANTALLA PRINCIPAL (TARJETAS VERDES DE EMERGENCIA EN CUADRÍCULA 2X2)
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
      {'nombre': 'Bomberos', 'numero': '116', 'sub': 'Incendios'},
      {'nombre': 'Seguridad Ciudadana', 'numero': '044298734', 'sub': 'Serenazgo'},
      {'nombre': 'Policía Nacional', 'numero': '105', 'sub': 'PNP'},
      {'nombre': 'SAMU', 'numero': '106', 'sub': 'Médica urgencia'},
    ];

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabecera con Nombre de Usuario
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
              const SizedBox(height: 20),

              const Text(
                'Contactos de Emergencia Rápida',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              const Text(
                'Toca una tarjeta para llamar inmediatamente:',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),

              // Cuadrícula (Grid) de 2 columnas por línea con tarjetas flotantes verdes
              Expanded(
                child: GridView.builder(
                  itemCount: emergencias.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, // 2 por línea
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.15, // Proporción rectangular horizontal
                  ),
                  itemBuilder: (context, index) {
                    final e = emergencias[index];
                    return InkWell(
                      onTap: () => _hacerLlamada(e['numero']!),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.25),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Icon(Icons.phone_in_talk, color: Colors.white, size: 22),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    e['numero']!,
                                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  e['nombre']!,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  e['sub']!,
                                  style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 10),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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