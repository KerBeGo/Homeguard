import 'package:flutter/material.dart';

class MonthDaysSelector extends StatefulWidget {
  final List<int> initialDays;
  final ValueChanged<List<int>> onChanged;

  const MonthDaysSelector({
    super.key,
    required this.initialDays,
    required this.onChanged,
  });

  @override
  State<MonthDaysSelector> createState() => _MonthDaysSelectorState();
}

class _MonthDaysSelectorState extends State<MonthDaysSelector> {
  late Set<int> _selectedDays;

  @override
  void initState() {
    super.initState();
    _selectedDays = Set.from(widget.initialDays);
  }

  void _toggleDay(int day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
      } else {
        _selectedDays.add(day);
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
          'Selecciona los días del mes',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: 31,
          itemBuilder: (context, index) {
            final day = index + 1;
            final isSelected = _selectedDays.contains(day);

            return InkWell(
              onTap: () => _toggleDay(day),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Colors.transparent,
                  border: Border.all(
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.grey.shade300,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  day.toString(),
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        const Text(
          'Nota: Si eliges días como 31, se omitirán en los meses que no tengan esos días.',
          style: TextStyle(fontSize: 12, color: Colors.grey, fontStyle: FontStyle.italic),
        ),
      ],
    );
  }
}
