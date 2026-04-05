import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/medication_provider.dart';
import '../../services/medication_service.dart';
import '../../widgets/medications/week_days_selector.dart';
import '../../widgets/medications/month_days_selector.dart';
import '../../widgets/medications/period_selector.dart';

class MedicationWizard extends StatefulWidget {
  final String patientId;

  const MedicationWizard({super.key, required this.patientId});

  @override
  State<MedicationWizard> createState() => _MedicationWizardState();
}

class _MedicationWizardState extends State<MedicationWizard> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MedicationProvider>(
        context,
        listen: false,
      ).startNewMedication();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _saveAndSync() async {
    final provider = Provider.of<MedicationProvider>(context, listen: false);
    final medication = provider.currentMedication;

    if (medication == null ||
        medication.nombre.isEmpty ||
        medication.horas.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, ingresa el nombre y al menos una hora.'),
        ),
      );
      return;
    }

    try {
      final service = MedicationService();
      await service.saveMedication(widget.patientId, medication);
      if (mounted) {
        Navigator.pop(context); // Close the wizard
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Medicamento guardado con éxito')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo Medicamento'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Basic Progress Indicator
          LinearProgressIndicator(
            value: (_currentPage + 1) / 4,
            backgroundColor: Colors.grey[200],
          ),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics:
                  const NeverScrollableScrollPhysics(), // Prevent manual swipe
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              children: [
                _buildIdentidadScreen(),
                _buildFrecuenciaScreen(),
                _buildTemporizacionScreen(),
                _buildResumenScreen(),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentPage > 0)
                  TextButton(
                    onPressed: _previousPage,
                    child: const Text('ATRÁS'),
                  )
                else
                  const SizedBox(width: 80),

                if (_currentPage < 3)
                  ElevatedButton(
                    onPressed: _nextPage,
                    child: const Text('SIGUIENTE'),
                  )
                else
                  ElevatedButton(
                    onPressed: _saveAndSync,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('GUARDAR'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Screens ---

  // 1. Identidad y Categoría
  Widget _buildIdentidadScreen() {
    return Consumer<MedicationProvider>(
      builder: (context, provider, child) {
        final med = provider.currentMedication;
        if (med == null) return const SizedBox();

        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const Text(
              '¿Qué medicamento tomará?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: med.nombre,
              decoration: const InputDecoration(
                labelText: 'Nombre (ej: Donepezilo)',
              ),
              onChanged: (val) =>
                  provider.updateIdentidad(val, med.descripcion, med.categoria),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: med.descripcion,
              decoration: const InputDecoration(
                labelText: 'Notas (ej: Tomar con comida)',
              ),
              onChanged: (val) =>
                  provider.updateIdentidad(med.nombre, val, med.categoria),
            ),
            const SizedBox(height: 24),
            const Text('Categoría:', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 8),
            Column(
              children: ['Pastilla', 'Jarabe', 'Inyección', 'Inhalador'].map((
                cat,
              ) {
                final isSelected = med.categoria == cat;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isSelected
                            ? Theme.of(context).primaryColor
                            : Colors.grey[200],
                        foregroundColor: isSelected
                            ? Colors.white
                            : Colors.black87,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: isSelected ? 2 : 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: () {
                        provider.updateIdentidad(
                          med.nombre,
                          med.descripcion,
                          cat,
                        );
                      },
                      child: Text(
                        cat,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  // 2. Frecuencia
  Widget _buildFrecuenciaScreen() {
    return Consumer<MedicationProvider>(
      builder: (context, provider, child) {
        final med = provider.currentMedication;
        if (med == null) return const SizedBox();

        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const Text(
              '¿Con qué frecuencia?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: med.frecuenciaTipo,
              decoration: const InputDecoration(
                labelText: 'Tipo de Frecuencia',
              ),
              items: ['Diario', 'Días de la semana', 'Días del mes', 'Por periodo', 'Intervalo'].map(
                (String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                },
              ).toList(),
              onChanged: (newValue) {
                if (newValue != null) {
                  provider.updateFrecuencia(newValue);
                }
              },
            ),
            const SizedBox(height: 24),
            if (med.frecuenciaTipo == 'Días de la semana')
              WeekDaysSelector(
                initialDays: med.diasEspecificos ?? [],
                onChanged: (days) => provider.updateFrecuencia(
                  med.frecuenciaTipo,
                  diasEspecificos: days,
                  diasMes: med.diasMes,
                  intervaloDias: med.intervaloDias,
                  periodoCantidad: med.periodoCantidad,
                  periodoUnidad: med.periodoUnidad,
                ),
              ),
            if (med.frecuenciaTipo == 'Días del mes')
              MonthDaysSelector(
                initialDays: med.diasMes ?? [],
                onChanged: (days) => provider.updateFrecuencia(
                  med.frecuenciaTipo,
                  diasEspecificos: med.diasEspecificos,
                  diasMes: days,
                  intervaloDias: med.intervaloDias,
                  periodoCantidad: med.periodoCantidad,
                  periodoUnidad: med.periodoUnidad,
                ),
              ),
            if (med.frecuenciaTipo == 'Por periodo')
              PeriodSelector(
                initialCantidad: med.periodoCantidad,
                initialUnidad: med.periodoUnidad,
                onChanged: (cantidad, unidad) => provider.updateFrecuencia(
                  med.frecuenciaTipo,
                  diasEspecificos: med.diasEspecificos,
                  diasMes: med.diasMes,
                  intervaloDias: med.intervaloDias,
                  periodoCantidad: cantidad,
                  periodoUnidad: unidad,
                ),
              ),
            if (med.frecuenciaTipo == 'Intervalo')
              const Text('Cada X días (Por implementar detalle)'),
            if (med.frecuenciaTipo == 'Diario')
              const Text(
                'Se programará para todos los días.',
                style: TextStyle(color: Colors.grey),
              ),
          ],
        );
      },
    );
  }

  // 3. Temporización y Vigencia
  Widget _buildTemporizacionScreen() {
    return Consumer<MedicationProvider>(
      builder: (context, provider, child) {
        final med = provider.currentMedication;
        if (med == null) return const SizedBox();

        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const Text(
              '¿A qué hora?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            // Horas seleccionadas
            Wrap(
              spacing: 8.0,
              children: med.horas
                  .map(
                    (h) => Chip(
                      label: Text(h),
                      onDeleted: () {
                        final newHoras = List<String>.from(med.horas)
                          ..remove(h);
                        provider.updateTemporizacion(
                          newHoras,
                          med.fechaInicio,
                          med.fechaFin,
                        );
                      },
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.add_alarm),
              label: const Text('Agregar Hora'),
              onPressed: () async {
                final TimeOfDay? time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (time != null) {
                  final hr =
                      '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                  if (!med.horas.contains(hr)) {
                    final newHoras = List<String>.from(med.horas)..add(hr);
                    provider.updateTemporizacion(
                      newHoras,
                      med.fechaInicio,
                      med.fechaFin,
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  // 4. Resumen
  Widget _buildResumenScreen() {
    return Consumer<MedicationProvider>(
      builder: (context, provider, child) {
        final med = provider.currentMedication;
        if (med == null) return const SizedBox();

        return ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            const Text(
              'Resumen',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: Text('Medicamento: ${med.nombre}'),
              subtitle: Text(med.categoria),
              leading: const Icon(Icons.medical_services_outlined),
            ),
            ListTile(
              title: Text('Frecuencia: ${med.frecuenciaTipo}'),
              subtitle: Text('Horas: ${med.horas.join(', ')}'),
              leading: const Icon(Icons.update),
            ),
            if (med.descripcion.isNotEmpty)
              ListTile(
                title: const Text('Notas'),
                subtitle: Text(med.descripcion),
                leading: const Icon(Icons.note),
              ),
          ],
        );
      },
    );
  }
}
