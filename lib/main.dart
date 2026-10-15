import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'dart:async';

import 'login.dart';
import 'circulo_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://pvdidrqekdsnvrjtylrq.supabase.co',
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

// =============================================================================
// PANTALLA PRINCIPAL CON NAVEGACIÓN INFERIOR (3 SECCIONES)
// =============================================================================
class HomeScreen extends StatefulWidget {
  final String userName;
  const HomeScreen({super.key, required this.userName});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tabActual = 0;

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF007A78);

    final pantallas = [
      PanelPrincipalScreen(userName: widget.userName),
      CirculoScreen(userName: widget.userName),
      AjustesScreen(userName: widget.userName),
    ];

    return Scaffold(
      body: IndexedStack(index: _tabActual, children: pantallas),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _tabActual,
        onTap: (i) => setState(() => _tabActual = i),
        selectedItemColor: primaryColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Panel',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.shield_outlined),
            activeIcon: Icon(Icons.shield),
            label: 'Círculo',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.tune_outlined),
            activeIcon: Icon(Icons.tune),
            label: 'Ajustes',
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// SECCIÓN 1: PANEL PRINCIPAL (SOS arriba + contactos de emergencia)
// =============================================================================
class PanelPrincipalScreen extends StatefulWidget {
  final String userName;
  const PanelPrincipalScreen({super.key, required this.userName});

  @override
  State<PanelPrincipalScreen> createState() => _PanelPrincipalScreenState();
}

class _PanelPrincipalScreenState extends State<PanelPrincipalScreen> {
  Timer? _sosTimer;
  double _sosProgress = 0.0;
  bool _enviandoSOS = false;

  @override
  void dispose() {
    _sosTimer?.cancel();
    super.dispose();
  }

  Future<void> _hacerLlamada(String numero) async {
    final Uri url = Uri(scheme: 'tel', path: numero);
    if (await canLaunchUrl(url)) await launchUrl(url);
  }

  void _iniciarPresionSOS() {
    if (_enviandoSOS) return;
    setState(() => _sosProgress = 0.0);

    const duracionMs = 3000;
    const pasoMs = 50;
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
    if (!_enviandoSOS) setState(() => _sosProgress = 0.0);
  }

  Future<void> _activarSOS() async {
    setState(() {
      _enviandoSOS = true;
      _sosProgress = 1.0;
    });

    try {
      // 1. Verificar permisos de ubicación
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Permisos de ubicación denegados');
      }

      // 2. Obtener ubicación ACTUAL
      final Position posicion = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final double latitud = posicion.latitude;
      final double longitud = posicion.longitude;

      print('📍 Ubicación: $latitud, $longitud');

      // 3. Usuario actual
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('No hay sesión activa');

      // 4. Insertar alerta y guardar la respuesta correctamente
      final dynamic alertaRaw = await Supabase.instance.client
          .from('alerts')
          .insert({
            'user_id': user.id,
            'latitude': latitud,
            'longitude': longitud,
            'status': 'active',
          })
          .select()
          .single();

      // Convertir a Map de forma segura
      final Map<String, dynamic> alerta = Map<String, dynamic>.from(
        alertaRaw as Map,
      );
      final String alertId = alerta['id']?.toString() ?? '';

      print('✅ Alerta creada: $alertId');

      // 5. Enviar WhatsApp masivo vía Edge Function
      try {
        await Supabase.instance.client.functions.invoke(
          'broadcast_sos',
          body: {
            'alert_id': alertId,
            'user_name': widget.userName,
            'latitude': latitud,
            'longitude': longitud,
          },
        );
        print('📤 broadcast_sos invocado');
      } catch (e) {
        print('⚠️ broadcast_sos no disponible: $e');
      }

      if (!mounted) return;

      // 6. Diálogo de confirmación
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
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
                'Se envió tu ubicación y mensaje de ayuda a tus contactos.',
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
                    Expanded(
                      child: Text(
                        'Lat: ${latitud.toStringAsFixed(5)} · Lng: ${longitud.toStringAsFixed(5)}',
                        style: const TextStyle(fontSize: 11),
                      ),
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
      print('❌ Error SOS: $e');
      if (!mounted) return;
      setState(() {
        _enviandoSOS = false;
        _sosProgress = 0.0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF007A78);

    final emergencias = [
      {
        'nombre': 'Bomberos',
        'numero': '116',
        'icono': Icons.local_fire_department,
      },
      {'nombre': 'Policía', 'numero': '105', 'icono': Icons.local_police},
      {'nombre': 'Ambulancia', 'numero': '106', 'icono': Icons.local_hospital},
      {'nombre': 'Serenazgo', 'numero': '044298734', 'icono': Icons.shield},
      {'nombre': 'Defensa Civil', 'numero': '115', 'icono': Icons.emergency},
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ============ CABECERA ============
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                          fontSize: 22,
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

            // ============ TÍTULO CONTACTOS ============
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Contactos de Emergencia',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ============ LISTA DE CONTACTOS (EXPANDE) ============
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: emergencias.length,
                itemBuilder: (context, index) {
                  final e = emergencias[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () => _hacerLlamada(e['numero'] as String),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e['nombre'] as String,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    'N° ${e['numero']}',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.85),
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                e['icono'] as IconData,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // ============ BOTÓN SOS (ABAJO) ============
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: _buildBotonSOS(primaryColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBotonSOS(Color primaryColor) {
      return GestureDetector(
        onTapDown: (_) => _iniciarPresionSOS(),
        onTapUp: (_) => _cancelarPresionSOS(),
        onTapCancel: _cancelarPresionSOS,
        child: Container(
          width: double.infinity,
          height: 68,
          decoration: BoxDecoration(
            color: const Color(0xFFDC2626),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFDC2626).withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: _sosProgress,
                    child: Container(color: Colors.white.withOpacity(0.25)),
                  ),
                ),
              ),
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
                            size: 26,
                          ),
                    const SizedBox(width: 10),
                    Text(
                      _enviandoSOS
                          ? 'ENVIANDO...'
                          : _sosProgress > 0
                          ? 'MANTÉN...'
                          : 'SOS · Mantén 3 seg',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
  }
}

// =============================================================================
// SECCIÓN 2: CÍRCULO (contactos + seguimiento SOS realtime + agregar/eliminar)
// =============================================================================
class CirculoScreen extends StatefulWidget {
  final String userName;
  const CirculoScreen({super.key, required this.userName});

  @override
  State<CirculoScreen> createState() => _CirculoScreenState();
}

class _CirculoScreenState extends State<CirculoScreen> {
  List<Map<String, dynamic>> _contactos = [];
  List<Map<String, dynamic>> _respuestas = [];
  Map<String, dynamic>? _alertaActiva;
  bool _cargando = true;
  bool _cargandoBot = false;

  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  RealtimeChannel? _contactsChannel;
  RealtimeChannel? _alertsChannel;
  RealtimeChannel? _responsesChannel;

  @override
  void initState() {
    super.initState();
    _cargarTodo();
    _suscribir();
  }

  @override
  void dispose() {
    _contactsChannel?.unsubscribe();
    _alertsChannel?.unsubscribe();
    _responsesChannel?.unsubscribe();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  // ============ REALTIME ============
  void _suscribir() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    // Canal 1: contacts
    _contactsChannel = Supabase.instance.client
        .channel('circulo_contacts_${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'contacts',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (_) => _cargarContactos(),
        )
        .subscribe();

    // Canal 2: alerts (para detectar SOS activo)
    _alertsChannel = Supabase.instance.client
        .channel('circulo_alerts_${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'alerts',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (_) => _cargarAlertaYRespuestas(),
        )
        .subscribe();

    // Canal 3: alert_responses (para ver respuestas de contactos en vivo)
    _responsesChannel = Supabase.instance.client
        .channel('circulo_responses_${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'alert_responses',
          callback: (_) => _cargarAlertaYRespuestas(),
        )
        .subscribe();
  }

  // ============ CARGA DE DATOS ============
  Future<void> _cargarTodo() async {
    await Future.wait([_cargarContactos(), _cargarAlertaYRespuestas()]);
    if (mounted) setState(() => _cargando = false);
  }

  Future<void> _cargarContactos() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final data = await Supabase.instance.client
        .from('contacts')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: true);

    if (mounted) {
      setState(() => _contactos = List<Map<String, dynamic>>.from(data));
    }
  }

  Future<void> _cargarAlertaYRespuestas() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final alertas = await Supabase.instance.client
        .from('alerts')
        .select()
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(1);

    if (alertas.isEmpty) {
      if (mounted) {
        setState(() {
          _alertaActiva = null;
          _respuestas = [];
        });
      }
      return;
    }

    final alerta = Map<String, dynamic>.from(alertas.first);
    final respuestas = await Supabase.instance.client
        .from('alert_responses')
        .select()
        .eq('alert_id', alerta['id'])
        .order('created_at', ascending: true);

    if (mounted) {
      setState(() {
        _alertaActiva = alerta;
        _respuestas = List<Map<String, dynamic>>.from(respuestas);
      });
    }
  }

  // ============ AGREGAR CONTACTO ============
  void _agregarContactoModal() {
    if (_contactos.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Máximo 5 contactos permitidos'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

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
            const Text(
              'Invita a tu persona de confianza',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Mínimo 1 y máximo 5 contactos. Llevas ${_contactos.length} de 5.',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre del contacto',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Celular (+51)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007A78),
                ),
                icon: const Icon(Icons.smart_toy_outlined, color: Colors.white),
                onPressed: () {
                  if (_nameCtrl.text.isNotEmpty && _phoneCtrl.text.isNotEmpty) {
                    final nombre = _nameCtrl.text.trim();
                    final telefono = _phoneCtrl.text.trim();
                    _solicitarInvitacion(telefono, nombre);
                    _nameCtrl.clear();
                    _phoneCtrl.clear();
                    Navigator.pop(context);
                  }
                },
                label: const Text(
                  'Enviar invitación por WhatsApp',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _solicitarInvitacion(String telefono, String nombre) async {
    setState(() => _cargandoBot = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('No hay sesión activa');

      final inserted = await Supabase.instance.client
          .from('contacts')
          .insert({
            'user_id': user.id,
            'contact_name': nombre,
            'contact_phone': '+51$telefono',
            'status': 'pending',
          })
          .select()
          .single();

      await Supabase.instance.client.functions.invoke(
        'send_invitation',
        body: {
          'contact_id': inserted['id'],
          'contact_name': nombre,
          'contact_phone': '+51$telefono',
          'user_name': widget.userName,
        },
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🤖 Invitación enviada a $nombre por WhatsApp.'),
            backgroundColor: const Color(0xFF007A78),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _cargandoBot = false);
    }
  }

  // ============ ELIMINAR CONTACTO ============
  Future<void> _eliminarContacto(String id, String nombre) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('¿Eliminar contacto?'),
        content: Text(
          'Se eliminará a "$nombre" de tu círculo de confianza.\n\nEsta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await Supabase.instance.client.from('contacts').delete().eq('id', id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🗑️ Contacto "$nombre" eliminado'),
            backgroundColor: Colors.grey.shade800,
          ),
        );
      }
      // El realtime recargará la lista automáticamente
    }
  }

  // ============ UI HELPERS ============
  String _labelOpcion(int? code) {
    switch (code) {
      case 1:
        return '✅ Ya está con él/ella';
      case 2:
        return '🚗 En camino';
      case 3:
        return '📍 Ubicación recibida, no responde';
      case 4:
        return '❌ No puede ayudar';
      default:
        return '⏳ Esperando respuesta';
    }
  }

  Color _colorOpcion(int? code) {
    switch (code) {
      case 1:
        return Colors.green;
      case 2:
        return Colors.blue;
      case 3:
        return Colors.orange;
      case 4:
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF007A78);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F9),
      appBar: AppBar(
        title: const Text('Mi Círculo de Confianza'),
        backgroundColor: Colors.white,
        foregroundColor: primaryColor,
        elevation: 0,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarTodo,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // ============ CONTACTOS ============
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Personas autorizadas (${_contactos.length}/5)',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (_contactos.length < 5)
                        IconButton(
                          onPressed: _cargandoBot
                              ? null
                              : _agregarContactoModal,
                          icon: _cargandoBot
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(
                                  Icons.add_circle,
                                  color: primaryColor,
                                  size: 28,
                                ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  if (_contactos.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const Center(
                        child: Text(
                          'Aún no has agregado contactos.\nToca + para invitar a tu primera persona de confianza.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ),
                    )
                  else
                    ..._contactos.map((c) {
                      final status = c['status'] ?? 'pending';
                      final esAceptado = status == 'accepted';
                      final esRechazado = status == 'rejected';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: esAceptado
                                  ? primaryColor
                                  : esRechazado
                                  ? Colors.red
                                  : Colors.orange,
                              child: Text(
                                (c['contact_name'] ?? '?')[0].toUpperCase(),
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c['contact_name'] ?? '',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    c['contact_phone'] ?? '',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Badge estado
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: esAceptado
                                    ? Colors.green.shade50
                                    : esRechazado
                                    ? Colors.red.shade50
                                    : Colors.orange.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                esAceptado
                                    ? 'Aceptó'
                                    : esRechazado
                                    ? 'Rechazó'
                                    : 'Pendiente',
                                style: TextStyle(
                                  color: esAceptado
                                      ? Colors.green
                                      : esRechazado
                                      ? Colors.red
                                      : Colors.orange.shade800,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            // Botón eliminar
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.grey,
                                size: 20,
                              ),
                              onPressed: () => _eliminarContacto(
                                c['id'],
                                c['contact_name'] ?? 'contacto',
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: 32),

                  // ============ SEGUIMIENTO SOS EN VIVO ============
                  const Text(
                    'Seguimiento de emergencia',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 12),

                  if (_alertaActiva == null)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.info_outline, color: Color(0xFF007A78)),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Cuando actives el SOS, verás aquí el estado de cada contacto en tiempo real.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    _buildAlertaActiva(primaryColor),
                ],
              ),
            ),
    );
  }

  Widget _buildAlertaActiva(Color primaryColor) {
    final status = _alertaActiva?['status'] ?? 'active';
    final createdAt = _alertaActiva?['created_at'] ?? '';
    final esActiva = status == 'active';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: esActiva ? const Color(0xFFFFF3F3) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: esActiva ? const Color(0xFFDC2626) : Colors.grey.shade200,
          width: esActiva ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: esActiva
                      ? const Color(0xFFDC2626).withOpacity(0.15)
                      : Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  esActiva ? Icons.warning_amber_rounded : Icons.check_circle,
                  color: esActiva ? const Color(0xFFDC2626) : Colors.green,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      esActiva ? '🚨 SOS activo' : '✅ SOS finalizado',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: esActiva
                            ? const Color(0xFFDC2626)
                            : Colors.green,
                      ),
                    ),
                    Text(
                      'Lat ${_alertaActiva?['latitude']?.toStringAsFixed(4) ?? '-'} · '
                      'Lng ${_alertaActiva?['longitude']?.toStringAsFixed(4) ?? '-'}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 12),

          // Respuestas de contactos
          Text(
            'Respuestas (${_respuestas.length}/${_contactos.where((c) => c['status'] == 'accepted').length})',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
          ),
          const SizedBox(height: 8),

          if (_respuestas.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Aún no hay respuestas de tus contactos...',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
            )
          else
            ..._respuestas.map((r) {
              final code = r['response_code'] as int?;
              final phone = r['contact_phone'] ?? '';
              // Buscar nombre del contacto
              final contacto = _contactos.firstWhere(
                (c) => c['contact_phone'] == phone,
                orElse: () => {'contact_name': phone},
              );

              return Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _colorOpcion(code).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _colorOpcion(code).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person, size: 18, color: _colorOpcion(code)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            contacto['contact_name'] ?? 'Contacto',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            _labelOpcion(code),
                            style: TextStyle(
                              fontSize: 11,
                              color: _colorOpcion(code),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

// =============================================================================
// SECCIÓN 3: AJUSTES (perfil read-only + seguridad + ayuda)
// =============================================================================
class AjustesScreen extends StatefulWidget {
  final String userName;
  const AjustesScreen({super.key, required this.userName});

  @override
  State<AjustesScreen> createState() => _AjustesScreenState();
}

class _AjustesScreenState extends State<AjustesScreen> {
  bool _cargando = true;
  String _nombres = '';
  String _apellidos = '';
  String _celular = '';
  String _dni = '';

  @override
  void initState() {
    super.initState();
    _cargarPerfil();
  }

  Future<void> _cargarPerfil() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final data = await Supabase.instance.client
        .from('profiles')
        .select('nombres, apellidos, celular, dni')
        .eq('id', user.id)
        .maybeSingle();

    if (mounted) {
      setState(() {
        _nombres = data?['nombres'] ?? widget.userName;
        _apellidos = data?['apellidos'] ?? '';
        _celular = data?['celular'] ?? '';
        _dni = data?['dni'] ?? user.email?.split('@').first ?? '';
        _cargando = false;
      });
    }
  }

  // ============ CAMBIAR CONTRASEÑA ============
  Future<void> _cambiarPasswordModal() async {
    final nuevaCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Cambiar contraseña'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nuevaCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Nueva contraseña',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirmar nueva',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007A78),
              ),
              onPressed: () async {
                if (nuevaCtrl.text.length < 6) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Mínimo 6 caracteres')),
                  );
                  return;
                }
                if (nuevaCtrl.text != confirmCtrl.text) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Las contraseñas no coinciden'),
                    ),
                  );
                  return;
                }
                try {
                  await Supabase.instance.client.auth.updateUser(
                    UserAttributes(password: nuevaCtrl.text),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Contraseña actualizada'),
                        backgroundColor: Color(0xFF007A78),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text(
                'Guardar',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============ CERRAR SESIÓN ============
  Future<void> _cerrarSesion() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Tendrás que volver a iniciar sesión con tu DNI.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Cerrar sesión',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    await Supabase.instance.client.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  // ============ ACERCA DE ============
  void _acercaDe() {
    showAboutDialog(
      context: context,
      applicationName: 'MOSCA',
      applicationVersion: 'v1.0.0 · MVP',
      applicationIcon: const Icon(
        Icons.shield,
        size: 40,
        color: Color(0xFF007A78),
      ),
      children: [
        const SizedBox(height: 12),
        const Text(
          'Sistema Inteligente de Alerta Temprana y Respuesta Colaborativa ante Situaciones de Inseguridad.',
          style: TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 8),
        const Text(
          'Proyecto de Innovación y Transformación Digital · UTP',
          style: TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  // ============ AYUDA ============
  void _ayuda() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              '¿Cómo funciona MOSCA?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            _AyudaItem(
              titulo: '1. Agrega contactos',
              texto: 'Invita entre 1 y 5 personas de confianza. Ellas aceptarán por WhatsApp.',
            ),
            _AyudaItem(
              titulo: '2. Activa el SOS',
              texto: 'Mantén presionado el botón rojo 3 segundos. Se enviará tu ubicación a todos.',
            ),
            _AyudaItem(
              titulo: '3. Tu círculo responde',
              texto: 'Recibirán un WhatsApp con 4 opciones para indicar cómo te ayudarán.',
            ),
            _AyudaItem(
              titulo: '4. Seguimiento automático',
              texto: 'Si no marcan la opción 1, el bot volverá a escribir en 10 minutos.',
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF007A78);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F9),
      appBar: AppBar(
        title: const Text('Ajustes'),
        backgroundColor: Colors.white,
        foregroundColor: primaryColor,
        elevation: 0,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // ============ PERFIL (SOLO LECTURA) ============
                const _SectionTitle('Mi perfil'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Column(
                    children: [
                      // Avatar
                      CircleAvatar(
                        radius: 38,
                        backgroundColor: primaryColor,
                        child: Text(
                          _nombres.isNotEmpty ? _nombres[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 28,
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Nombre completo
                      Text(
                        '$_nombres $_apellidos'.trim(),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'DNI: $_dni',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(height: 1),
                      const SizedBox(height: 12),

                      // Info read-only
                      _InfoRow(
                        icon: Icons.person_outline,
                        label: 'Nombres',
                        valor: _nombres,
                      ),
                      const SizedBox(height: 10),
                      _InfoRow(
                        icon: Icons.person_outline,
                        label: 'Apellidos',
                        valor: _apellidos,
                      ),
                      const SizedBox(height: 10),
                      _InfoRow(
                        icon: Icons.badge_outlined,
                        label: 'DNI',
                        valor: _dni,
                      ),
                      const SizedBox(height: 10),
                      _InfoRow(
                        icon: Icons.phone_outlined,
                        label: 'Celular',
                        valor: _celular.isNotEmpty ? _celular : 'No registrado',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'Tus datos personales provienen de RENIEC y no pueden editarse.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // ============ SEGURIDAD ============
                const _SectionTitle('Seguridad'),
                const SizedBox(height: 12),
                _OpcionTile(
                  icon: Icons.lock_outline,
                  titulo: 'Cambiar contraseña',
                  subtitulo: 'Actualiza tu clave de acceso',
                  onTap: _cambiarPasswordModal,
                ),

                const SizedBox(height: 32),

                // ============ AYUDA E INFO ============
                const _SectionTitle('Ayuda e información'),
                const SizedBox(height: 12),
                _OpcionTile(
                  icon: Icons.help_outline,
                  titulo: '¿Cómo funciona MOSCA?',
                  subtitulo: 'Guía paso a paso',
                  onTap: _ayuda,
                ),
                _OpcionTile(
                  icon: Icons.info_outline,
                  titulo: 'Acerca de MOSCA',
                  subtitulo: 'Versión 1.0.0 · MVP',
                  onTap: _acercaDe,
                ),

                const SizedBox(height: 40),

                // ============ CERRAR SESIÓN ============
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _cerrarSesion,
                    icon: const Icon(Icons.logout, color: Colors.red),
                    label: const Text(
                      'Cerrar sesión',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
    );
  }
}

// ============ Widgets auxiliares ============
class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Color(0xFF007A78),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String valor;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.valor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF007A78)),
        const SizedBox(width: 10),
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ),
        Expanded(
          child: Text(
            valor,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}

class _OpcionTile extends StatelessWidget {
  final IconData icon;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;

  const _OpcionTile({
    required this.icon,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF007A78)),
        title: Text(
          titulo,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(subtitulo, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          size: 14,
          color: Colors.grey,
        ),
        onTap: onTap,
      ),
    );
  }
}

class _AyudaItem extends StatelessWidget {
  final String titulo;
  final String texto;
  const _AyudaItem({required this.titulo, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline,
            size: 18,
            color: Color(0xFF007A78),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                Text(
                  texto,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
