import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'main.dart'; // Redirección al inicio
import 'registro.dart'; // Redirección al registro
import 'circulo_config.dart';

class LoginScreen extends StatefulWidget {
  final String registeredName;
  const LoginScreen({super.key, this.registeredName = 'Usuario'});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _dniController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final String internalEmail = '${_dniController.text}@gmail.com';

      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: internalEmail,
        password: _passwordController.text,
      );

      if (response.user == null || !mounted) return;

      final user = response.user!;

      // 1. Obtener nombre desde profiles (más confiable)
      String primerNombre = 'Usuario';
      try {
        final profile = await Supabase.instance.client
            .from('profiles')
            .select('nombres')
            .eq('id', user.id)
            .maybeSingle();

        final nombreCompleto = (profile?['nombres'] ?? '').toString().trim();
        if (nombreCompleto.isNotEmpty) {
          primerNombre = nombreCompleto.contains(' ')
              ? nombreCompleto.split(' ').first
              : nombreCompleto;
        }
      } catch (e) {
        print('⚠️ Error leyendo profile: $e');
      }

      // 2. Verificar si tiene contactos registrados
      final contactos = await Supabase.instance.client
          .from('contacts')
          .select('id, status')
          .eq('user_id', user.id);

      final tieneContactos = contactos.isNotEmpty;
      final tieneAlgunoAceptado = contactos.any(
        (c) => c['status'] == 'accepted',
      );

      print(
        '✅ Login OK. Contactos: ${contactos.length}, aceptados: $tieneAlgunoAceptado',
      );

      // 3. Decidir a dónde ir
      if (!mounted) return;

      if (!tieneContactos || !tieneAlgunoAceptado) {
        // No tiene contactos o no tiene ninguno aceptado → configurar círculo
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => CirculoConfigScreen(userName: primerNombre),
          ),
        );
      } else {
        // Ya tiene contactos aceptados → ir directo al panel principal
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomeScreen(userName: primerNombre),
          ),
        );
      }
    } on AuthException catch (e) {
      String mensaje = e.message;
      if (e.message.contains('Invalid login credentials')) {
        mensaje = 'DNI o contraseña incorrectos.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF007A78);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 40.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                // Logo de Mosca
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.shield_outlined, color: Colors.white, size: 32),
                      SizedBox(width: 8),
                      Text(
                        'mosca',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                const Text(
                  'No estás sola.\nEstamos en tu círculo.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 40),

                // Campo DNI
                TextFormField(
                  controller: _dniController,
                  keyboardType: TextInputType.number,
                  maxLength: 8,
                  decoration: InputDecoration(
                    labelText: 'DNI',
                    prefixIcon: const Icon(Icons.badge_outlined, color: primaryColor),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    counterText: '',
                  ),
                  validator: (val) {
                    if (val == null || val.length != 8) {
                      return 'Ingresa un DNI válido de 8 dígitos';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Campo Contraseña
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline, color: primaryColor),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Ingresa tu contraseña';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Botón Iniciar Sesión
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _login,
                    child: const Text(
                      'Iniciar Sesión',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Link para ir a Registro
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('¿No tienes una cuenta? '),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const RegisterScreen()),
                        );
                      },
                      child: const Text(
                        'Regístrate aquí',
                        style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}