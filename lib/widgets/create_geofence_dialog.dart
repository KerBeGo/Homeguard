import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Diálogo para crear una nueva geocerca
///
/// Solicita al usuario el radio de la geocerca en metros
class CreateGeofenceDialog extends StatefulWidget {
  final Function(double radiusMeters) onCreateGeofence;

  const CreateGeofenceDialog({super.key, required this.onCreateGeofence});

  @override
  State<CreateGeofenceDialog> createState() => _CreateGeofenceDialogState();
}

class _CreateGeofenceDialogState extends State<CreateGeofenceDialog> {
  final TextEditingController _radiusController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isCreating = false;

  @override
  void dispose() {
    _radiusController.dispose();
    super.dispose();
  }

  void _handleCreate() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isCreating = true;
      });

      try {
        double radius = double.parse(_radiusController.text);
        widget.onCreateGeofence(radius);

        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        setState(() {
          _isCreating = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al crear geocerca: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(
        children: [
          Icon(
            Icons.add_location_alt,
            color: Theme.of(context).primaryColor,
            size: 28,
          ),
          const SizedBox(width: 12),
          const Text(
            'Crear Geocerca',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Descripción
            Text(
              'La geocerca se creará en la ubicación actual del paciente.',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            const SizedBox(height: 20),

            // Campo de entrada para el radio
            TextFormField(
              controller: _radiusController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Radio (metros)',
                hintText: 'Ej: 100',
                prefixIcon: const Icon(Icons.straighten),
                suffixText: 'm',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Por favor ingrese un radio';
                }

                double? radius = double.tryParse(value);
                if (radius == null) {
                  return 'Ingrese un número válido';
                }

                if (radius < 10) {
                  return 'El radio debe ser al menos 10 metros';
                }

                if (radius > 10000) {
                  return 'El radio no puede exceder 10,000 metros';
                }

                return null;
              },
              autofocus: true,
            ),

            const SizedBox(height: 12),

            // Ayuda visual
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Valores sugeridos:\n50m - Casa\n100m - Vecindario\n500m - Zona amplia',
                      style: TextStyle(fontSize: 12, color: Colors.blue[900]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        // Botón Cancelar
        TextButton(
          onPressed: _isCreating
              ? null
              : () {
                  Navigator.of(context).pop();
                },
          child: Text(
            'Cancelar',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ),

        // Botón Crear
        ElevatedButton(
          onPressed: _isCreating ? null : _handleCreate,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: _isCreating
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  'Crear',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
        ),
      ],
    );
  }
}
