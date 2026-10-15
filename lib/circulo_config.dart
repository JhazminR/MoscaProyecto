import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';

import 'package:permission_handler/permission_handler.dart';

import 'main.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

class CirculoConfigScreen extends StatefulWidget {
  final String userName;
  const CirculoConfigScreen({super.key, required this.userName});

  @override
  State<CirculoConfigScreen> createState() => _CirculoConfigScreenState();
}

class _CirculoConfigScreenState extends State<CirculoConfigScreen> {
  List<Map<String, dynamic>> _contactos = [];
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  bool _cargandoBot = false;
  bool _cargandoLista = true;

  RealtimeChannel? _contactsChannel;

  @override
  void initState() {
    super.initState();
    _cargarContactos();
    _suscribirCambiosRealtime();
  }

  @override
  void dispose() {
    _contactsChannel?.unsubscribe();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // 🔥 Suscripción en tiempo real a cambios en la tabla contacts
  void _suscribirCambiosRealtime() {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _contactsChannel = Supabase.instance.client
        .channel('contacts_changes_${user.id}')
        .onPostgresChanges(
          event: PostgresChangeEvent.all, // INSERT, UPDATE, DELETE
          schema: 'public',
          table: 'contacts',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: user.id,
          ),
          callback: (payload) {
            print('🔄 Cambio detectado en contacts: ${payload.eventType}');
            print('   Nuevo estado: ${payload.newRecord}');
            // Recargar la lista cuando hay cualquier cambio
            _cargarContactos();
          },
        )
        .subscribe((status, error) {
          print('📡 Realtime status: $status | Error: $error');
        });
  }

  Future<void> _cargarContactos() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final data = await Supabase.instance.client
          .from('contacts')
          .select()
          .eq('user_id', user.id)
          .order('created_at', ascending: true);

      if (mounted) {
        setState(() {
          _contactos = List<Map<String, dynamic>>.from(data);
          _cargandoLista = false;
        });
      }
    } catch (e) {
      print('Error al cargar contactos: $e');
      if (mounted) setState(() => _cargandoLista = false);
    }
  }

  // Función para ordenar al Bot enviar la autorización por WhatsApp
  Future<void> _solicitarAutorizacionBot(
    String telefono,
    String contactoNombre,
  ) async {
    setState(() => _cargandoBot = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('No hay sesión activa');

      // 1. Guardar el contacto en Supabase con estado 'pending'
      final inserted = await Supabase.instance.client
          .from('contacts')
          .insert({
            'user_id': user.id,
            'contact_name': contactoNombre,
            'contact_phone': '+51$telefono',
            'status': 'pending',
          })
          .select()
          .single();

      // 2. Llamar a la Edge Function que dispara el mensaje por Zavu
      // (La Edge Function 'send_invitation' la crearemos después)
      await Supabase.instance.client.functions.invoke(
        'send_invitation',
        body: {
          'contact_id': inserted['id'],
          'contact_name': contactoNombre,
          'contact_phone': '+51$telefono',
          'user_name': widget.userName,
        },
      );

      // 3. Recargar lista
      await _cargarContactos();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '🤖 Bot de Mosca envió solicitud a $contactoNombre por WhatsApp.',
            ),
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
            const Text(
              'Invita a tu persona de confianza',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'El Bot Oficial de Mosca le enviará un mensaje por WhatsApp. El contacto solo debe responder "SÍ" para activar el permiso.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre del contacto',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
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
                  if (_nameController.text.isNotEmpty &&
                      _phoneController.text.isNotEmpty) {
                    final String nombre = _nameController.text;
                    final String telefono = _phoneController.text;

                    _solicitarAutorizacionBot(telefono, nombre);

                    _nameController.clear();
                    _phoneController.clear();
                    Navigator.pop(context);
                  }
                },
                label: const Text(
                  'Enviar Solicitud con Bot Mosca',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Simulación de la recepción del "SÍ" del familiar para pruebas en el prototipo
  Future<void> _simularRespuestaBot(int index) async {
    final contacto = _contactos[index];

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Respuesta de ${contacto['contact_name']}'),
        content: const Text('¿El contacto respondió "SÍ" al Bot de WhatsApp?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Sí, aceptó',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await Supabase.instance.client
          .from('contacts')
          .update({'status': 'accepted'})
          .eq('id', contacto['id']);
      await _cargarContactos();
    }
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
            content: const Text(
              'Mosca necesita acceso a tu ubicación para compartir coordenadas con tu círculo en emergencias.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF007A78);
    final int aceptadosCount = _contactos
        .where((c) => c['status'] == 'accepted')
        .length;

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
            // ============ CABECERA ============
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
                  Text(
                    'Hola, ${widget.userName}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'El Bot de Mosca se encargará de pedir la autorización por WhatsApp a tus contactos.',
                    style: TextStyle(fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _cargandoBot ? null : _agregarContactoModal,
                      child: _cargandoBot
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Agregar contacto con Bot',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // ============ LISTA DE CONTACTOS ============
            Text(
              'Tus contactos (${_contactos.length} de 5)',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 12),

            // 1° Nivel: Cargando
            _cargandoLista
                ? const Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                // 2° Nivel: Lista vacía
                : _contactos.isEmpty
                ? Container(
                    padding: const EdgeInsets.all(20),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: const Text(
                      'Aún no has enviado solicitudes con el Bot.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  )
                // 3° Nivel: Mostrar contactos
                : ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _contactos.length,
                    itemBuilder: (context, index) {
                      final c = _contactos[index];
                      final String status = c['status'] ?? 'pending';
                      final bool esAceptado = status == 'accepted';
                      final bool esRechazado = status == 'rejected';

                      return InkWell(
                        onTap: () => _simularRespuestaBot(index),
                        borderRadius: BorderRadius.circular(12),
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
                              // Avatar + Info
                              Expanded(
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: esAceptado
                                          ? primaryColor
                                          : esRechazado
                                          ? Colors.red
                                          : Colors.orange,
                                      child: Text(
                                        (c['contact_name'] ?? '?')[0]
                                            .toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            c['contact_name'] ?? '',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
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
                                  ],
                                ),
                              ),
                              // Badge de estado
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: esAceptado
                                      ? Colors.green.shade50
                                      : esRechazado
                                      ? Colors.red.shade50
                                      : Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      esAceptado
                                          ? Icons.check_circle
                                          : esRechazado
                                          ? Icons.cancel
                                          : Icons.access_time,
                                      size: 14,
                                      color: esAceptado
                                          ? Colors.green
                                          : esRechazado
                                          ? Colors.red
                                          : Colors.orange.shade800,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      esAceptado
                                          ? 'Aceptó'
                                          : esRechazado
                                          ? 'No aceptó'
                                          : 'Pendiente',
                                      style: TextStyle(
                                        color: esAceptado
                                            ? Colors.green
                                            : esRechazado
                                            ? Colors.red
                                            : Colors.orange.shade800,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
            const SizedBox(height: 32),

            // ============ BOTÓN CONTINUAR ============
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: aceptadosCount == 0
                      ? Colors.grey
                      : primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: aceptadosCount == 0
                    ? null
                    : _solicitarPermisosYContinuar,
                child: Text(
                  aceptadosCount == 0
                      ? 'Esperando respuesta "SÍ" en el Bot...'
                      : 'Activar mi círculo e ingresar',
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
