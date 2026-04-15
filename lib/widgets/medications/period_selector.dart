import 'package:flutter/material.dart';

class PeriodSelector extends StatefulWidget {
  final int? initialCantidad;
  final String? initialUnidad;
  final void Function(int cantidad, String unidad) onChanged;

  const PeriodSelector({
    super.key,
    this.initialCantidad,
    this.initialUnidad,
    required this.onChanged,
  });

  @override
  State<PeriodSelector> createState() => _PeriodSelectorState();
}

class _PeriodSelectorState extends State<PeriodSelector> {
  late TextEditingController _cantidadController;
  late String _selectedUnidad;

  final List<String> _unidades = ['semana', 'mes', 'año'];

  @override
  void initState() {
    super.initState();
    _cantidadController = TextEditingController(
      text: widget.initialCantidad != null ? widget.initialCantidad.toString() : '',
    );
    _selectedUnidad = widget.initialUnidad ?? 'semana';
    
    // Ensure the initial unit is within our valid list
    if (!_unidades.contains(_selectedUnidad)) {
      _selectedUnidad = 'semana';
    }
  }

  @override
  void dispose() {
    _cantidadController.dispose();
    super.dispose();
  }

  void _notifyChange() {
    final cantidadText = _cantidadController.text;
    final cantidad = int.tryParse(cantidadText) ?? 0;
    if(cantidad > 0) {
        widget.onChanged(cantidad, _selectedUnidad);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Frecuencia',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Text Input for number
            SizedBox(
              width: 80,
              child: TextFormField(
                controller: _cantidadController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                  hintText: 'Ej: 3',
                ),
                onChanged: (value) => _notifyChange(),
              ),
            ),
            const SizedBox(width: 16),
            const Text(
              'veces por',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(width: 16),
            // Dropdown for period
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _selectedUnidad,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                ),
                items: _unidades.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedUnidad = newValue;
                    });
                    _notifyChange();
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}
