import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'main.dart'; // Para navegar a la pantalla principal tras registrarse

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _dniController = TextEditingController();
  final _namesController = TextEditingController();
  final _lastNamesController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoadingDni = false;
  bool _dniVerified = false;
  DateTime? _selectedBirthDate;
  bool _isAdult = false;

  // Consulta API Gratuita DNI (apis.net.pe)
  Future<void> _fetchDniInfo(String dni) async {
    if (dni.length != 8) return;

    setState(() => _isLoadingDni = true);

    try {
      final url = Uri.parse('https://api.apis.net.pe/v1/dni?numero=$dni');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        final String nombres = data['nombres'] ?? '';
        final String apellidoPaterno = data['apellidoPaterno'] ?? '';
        final String apellidoMaterno = data['apellidoMaterno'] ?? '';

        setState(() {
          _namesController.text = nombres;
          _lastNamesController.text = '$apellidoPaterno $apellidoMaterno'.trim();
          _dniVerified = true;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('DNI verificado correctamente.')),
          );
        }
      } else {
        _showDialog('Atención', 'No se encontraron datos para el DNI ingresado.');
      }
    } catch (e) {
      _showDialog('Error de Conexión', 'No se pudo consultar el servicio de DNI.');
    } finally {
      setState(() => _isLoadingDni = false);
    }
  }

  // Selector de Fecha de Nacimiento y Validación de Mayoría de Edad
  Future<void> _selectBirthDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2005, 1, 1),
      firstDate: DateTime(1930),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      final age = _calculateAge(picked);
      setState(() {
        _selectedBirthDate = picked;
        _isAdult = age >= 18;
      });

      if (!_isAdult) {
        _showDialog('Edad Insuficiente', 'Debes ser mayor de 18 años para poder registrarte en Mosca.');
      }
    }
  }

  int _calculateAge(DateTime birthDate) {
    DateTime today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month ||
        (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    return age;
  }

  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _submitRegister() {
    if (_formKey.currentState!.validate()) {
      if (!_isAdult) {
        _showDialog('Registro no permitido', 'Para continuar debes tener al menos 18 años.');
        return;
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => HomeScreen(userName: _namesController.text.split(' ')[0]),
        ),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF007A78);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro de Usuario'),
        backgroundColor: Colors.white,
        foregroundColor: primaryColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Crea tu cuenta',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: primaryColor),
              ),
              const SizedBox(height: 6),
              const Text('Ingresa tu DNI para autocompletar tus nombres y verificar tu identidad.'),
              const SizedBox(height: 24),

              // Campo DNI
              TextFormField(
                controller: _dniController,
                keyboardType: TextInputType.number,
                maxLength: 8,
                decoration: InputDecoration(
                  labelText: 'DNI (Perú)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  counterText: '',
                  suffixIcon: _isLoadingDni
                      ? const Padding(
                          padding: EdgeInsets.all(12.0),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          icon: const Icon(Icons.search, color: primaryColor),
                          onPressed: () => _fetchDniInfo(_dniController.text),
                        ),
                ),
                validator: (val) {
                  if (val == null || val.length != 8) return 'Ingresa un DNI de 8 dígitos';
                  return null;
                },
                onChanged: (val) {
                  if (val.length == 8) _fetchDniInfo(val);
                },
              ),
              const SizedBox(height: 16),

              // Nombres
              TextFormField(
                controller: _namesController,
                readOnly: _dniVerified,
                decoration: InputDecoration(
                  labelText: 'Nombres',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) => val!.isEmpty ? 'Campo obligatorio' : null,
              ),
              const SizedBox(height: 16),

              // Apellidos
              TextFormField(
                controller: _lastNamesController,
                readOnly: _dniVerified,
                decoration: InputDecoration(
                  labelText: 'Apellidos',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) => val!.isEmpty ? 'Campo obligatorio' : null,
              ),
              const SizedBox(height: 16),

              // Selector Fecha de Nacimiento
              InkWell(
                onTap: _selectBirthDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Fecha de Nacimiento',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    suffixIcon: const Icon(Icons.calendar_today, color: primaryColor),
                  ),
                  child: Text(
                    _selectedBirthDate == null
                        ? 'Selecciona tu fecha de nacimiento'
                        : '${_selectedBirthDate!.day}/${_selectedBirthDate!.month}/${_selectedBirthDate!.year} (${_calculateAge(_selectedBirthDate!)} años)',
                    style: TextStyle(
                      color: _selectedBirthDate == null ? Colors.grey[600] : Colors.black,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Celular
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Celular (+51)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) => val!.isEmpty ? 'Ingresa tu número celular' : null,
              ),
              const SizedBox(height: 16),

              // Contraseña
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) => val!.length < 6 ? 'Mínimo 6 caracteres' : null,
              ),
              const SizedBox(height: 28),

              // Botón Registrarse
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _submitRegister,
                  child: const Text('Registrarse', style: TextStyle(color: Colors.white, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}