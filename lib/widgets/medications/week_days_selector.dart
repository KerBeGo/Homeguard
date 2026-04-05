import 'package:flutter/material.dart';

class WeekDaysSelector extends StatefulWidget {
  final List<int> initialDays;
  final ValueChanged<List<int>> onChanged;

  const WeekDaysSelector({
    super.key,
    required this.initialDays,
    required this.onChanged,
  });

  @override
  State<WeekDaysSelector> createState() => _WeekDaysSelectorState();
}

class _WeekDaysSelectorState extends State<WeekDaysSelector> {
  late Set<int> _selectedDays;

  final List<Map<String, dynamic>> _daysOfWeek = [
    {'name': 'Lunes', 'value': 1},
    {'name': 'Martes', 'value': 2},
    {'name': 'Miércoles', 'value': 3},
    {'name': 'Jueves', 'value': 4},
    {'name': 'Viernes', 'value': 5},
    {'name': 'Sábado', 'value': 6},
    {'name': 'Domingo', 'value': 7},
  ];

  @override
  void initState() {
    super.initState();
    _selectedDays = Set.from(widget.initialDays);
  }

  void _toggleDay(int dayValue, bool? isSelected) {
    setState(() {
      if (isSelected == true) {
        _selectedDays.add(dayValue);
      } else {
        _selectedDays.remove(dayValue);
      }
    });
    widget.onChanged(_selectedDays.toList()..sort());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Selecciona los días',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ..._daysOfWeek.map((day) {
          return CheckboxListTile(
            title: Text(day['name']),
            dense: true,
            visualDensity: VisualDensity.compact,
            value: _selectedDays.contains(day['value']),
            onChanged: (bool? value) => _toggleDay(day['value'], value),
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: Theme.of(context).primaryColor,
          );
        }).toList(),
      ],
    );
  }
}
