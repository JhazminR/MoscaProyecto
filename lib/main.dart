import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'login.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://pvdidrqekdsnvrjtylrq.supabase.co', // ← Reemplaza
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB2ZGlkcnFla2RzbnZyanR5bHJxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTIwMjA3NzksImV4cCI6MjEwNzU5Njc3OX0.E8ZoR_LYreYPra8svV9X7e7FfjHQ2mf7j0QHbxu04Hk',
  );

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
// PANTALLA PRINCIPAL (CONTACTOS + BOTÓN SOS CON PRESIÓN DE 3 SEGUNDOS)
// -----------------------------------------------------------------------------
class HomeScreen extends StatefulWidget {
  final String userName;

  const HomeScreen({super.key, required this.userName});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _sosTimer;
  double _sosProgress = 0.0;
  bool _enviandoSOS = false;

  @override
  void dispose() {
    _sosTimer?.cancel();
    super.dispose();
  }

  // ============ LLAMADAS TELEFÓNICAS ============
  Future<void> _hacerLlamada(String numero) async {
    final Uri url = Uri(scheme: 'tel', path: numero);
    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    }
  }

  // ============ LÓGICA DEL BOTÓN SOS ============
  void _iniciarPresionSOS() {
    if (_enviandoSOS) return;

    setState(() => _sosProgress = 0.0);

    const int duracionMs = 3000;
    const int pasoMs = 50;
    int elapsed = 0;

    _sosTimer?.cancel();
    _sosTimer = Timer.periodic(const Duration(milliseconds: pasoMs), (timer) {
      elapsed += pasoMs;
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _sosProgress = elapsed / duracionMs);

      if (elapsed >= duracionMs) {
        timer.cancel();
        _activarSOS();
      }
    });
  }

  void _cancelarPresionSOS() {
    _sosTimer?.cancel();
    if (!_enviandoSOS) {
      setState(() => _sosProgress = 0.0);
    }
  }

  Future<void> _activarSOS() async {
    setState(() {
      _enviandoSOS = true;
      _sosProgress = 1.0;
    });

    try {
      // 1. Obtener ubicación (si tienes el paquete geolocator)
      // Por ahora simulamos una ubicación de Trujillo
      const double latitud = -8.11599;
      const double longitud = -79.02998;

      // 2. Obtener usuario actual
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('No hay sesión activa');

      // 3. Registrar la alerta en Supabase
      final alerta = await Supabase.instance.client
          .from('alerts')
          .insert({
            'user_id': user.id,
            'latitude': latitud,
            'longitude': longitud,
            'status': 'active',
          })
          .select()
          .single();

      // 4. Llamar a la Edge Function que envía el WhatsApp masivo
      try {
        await Supabase.instance.client.functions.invoke(
          'broadcast_sos',
          body: {
            'alert_id': alerta['id'],
            'user_name': widget.userName,
            'latitude': latitud,
            'longitude': longitud,
          },
        );
      } catch (e) {
        // Si la Edge Function aún no existe, no rompemos el flujo
        print('⚠️ Edge Function broadcast_sos no disponible: $e');
      }

      if (!mounted) return;

      // 5. Mostrar confirmación
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: const [
              Icon(Icons.check_circle, color: Color(0xFF25D366), size: 28),
              SizedBox(width: 8),
              Text('¡Alerta enviada!'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Se envió tu ubicación y mensaje de ayuda a tus contactos de confianza.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F4F1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Color(0xFF007A78),
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Lat: $latitud  ·  Lng: $longitud',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _enviandoSOS = false;
                  _sosProgress = 0.0;
                });
              },
              child: const Text(
                'Estoy a salvo',
                style: TextStyle(
                  color: Color(0xFF007A78),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _enviandoSOS = false;
        _sosProgress = 0.0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al enviar SOS: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF007A78);

    // Lista de contactos con su entidad e ícono
    final List<Map<String, dynamic>> emergencias = [
      {
        'nombre': 'Bomberos',
        'sub': 'Incendios y rescates',
        'numero': '116',
        'icono': Icons.local_fire_department,
        'color': const Color(0xFFDC2626),
      },
      {
        'nombre': 'Policía Nacional',
        'sub': 'PNP · Seguridad',
        'numero': '105',
        'icono': Icons.local_police,
        'color': const Color(0xFF1E40AF),
      },
      {
        'nombre': 'Ambulancia (SAMU)',
        'sub': 'Emergencia médica',
        'numero': '106',
        'icono': Icons.local_hospital,
        'color': const Color(0xFF059669),
      },
      {
        'nombre': 'Seguridad Ciudadana',
        'sub': 'Serenazgo Trujillo',
        'numero': '044298734',
        'icono': Icons.shield,
        'color': const Color(0xFF7C3AED),
      },
      {
        'nombre': 'Defensa Civil',
        'sub': 'INDECI',
        'numero': '115',
        'icono': Icons.emergency,
        'color': const Color(0xFFEA580C),
      },
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ============ CABECERA ============
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 20.0,
                vertical: 16.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TRUJILLO · PERÚ',
                        style: TextStyle(
                          fontSize: 11,
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Hola, ${widget.userName}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  CircleAvatar(
                    backgroundColor: const Color(0xFFE6F4F1),
                    child: Text(
                      widget.userName.isNotEmpty
                          ? widget.userName[0].toUpperCase()
                          : 'U',
                      style: const TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ============ LISTA DE CONTACTOS ============
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Contactos de Emergencia',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Toca un rectángulo para llamar inmediatamente:',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),

                    // Lista de rectángulos verdes verticales
                    ...emergencias.map(
                      (e) => _buildBotonEmergencia(e, primaryColor),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // ============ BOTÓN SOS ============
            _buildBotonSOS(primaryColor),
          ],
        ),
      ),
    );
  }

  // ============ WIDGET: Rectángulo verde con logo a la derecha ============
  Widget _buildBotonEmergencia(Map<String, dynamic> e, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => _hacerLlamada(e['numero'] as String),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
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
          child: Row(
            children: [
              // Info a la izquierda
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e['nombre'] as String,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      e['sub'] as String,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'N° ${e['numero']}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),

              // Logo a la DERECHA
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  e['icono'] as IconData,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============ WIDGET: Botón SOS con presión de 3 segundos ============
  Widget _buildBotonSOS(Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: GestureDetector(
        onTapDown: (_) => _iniciarPresionSOS(),
        onTapUp: (_) => _cancelarPresionSOS(),
        onTapCancel: _cancelarPresionSOS,
        child: Container(
          width: double.infinity,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFFDC2626),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFDC2626).withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Barra de progreso de fondo
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _sosProgress,
                    child: Container(color: Colors.white.withOpacity(0.25)),
                  ),
                ),
              ),
              // Contenido centrado
              Center(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _enviandoSOS
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                    const SizedBox(width: 12),
                    Text(
                      _enviandoSOS
                          ? 'ENVIANDO ALERTA...'
                          : _sosProgress > 0
                          ? 'MANTÉN PRESIONADO...'
                          : 'SOS · Mantén 3 seg',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
