import 'package:flutter/material.dart';

class FoodConflictPage extends StatefulWidget {
  const FoodConflictPage({
    super.key,
    this.medicineNames = const <String>[],
  });

  final List<String> medicineNames;

  @override
  State<FoodConflictPage> createState() => _FoodConflictPageState();
}

class _FoodConflictPageState extends State<FoodConflictPage> {
  final Set<String> _selectedFoods = <String>{};
  List<_ConflictResult>? _results;

  static const Map<String, List<String>> _foodCategories = <String, List<String>>{
    'Citrus': <String>['Orange', 'Lemon', 'Lime', 'Grapefruit', 'Tangerine'],
    'Caffeine': <String>['Coffee', 'Tea', 'Cola', 'Energy drinks', 'Chocolate'],
    'Dairy': <String>['Milk', 'Cheese', 'Yogurt', 'Paneer', 'Butter'],
    'Alcohol': <String>['Beer', 'Wine', 'Whiskey', 'Vodka', 'Rum'],
    'Leafy Greens': <String>['Spinach', 'Kale', 'Lettuce', 'Broccoli', 'Cabbage'],
    'High Fat': <String>['Burgers', 'Pizza', 'Fried chicken', 'Chips'],
    'High Sugar': <String>['Chocolates', 'Sweets', 'Candy', 'Cakes'],
    'Spicy': <String>['Chilli', 'Hot sauces', 'Spicy curries'],
    'High Sodium': <String>['Papad', 'Pickles', 'Instant noodles'],
  };

  static const Map<String, _ConflictConfig> _medicationConflicts = <String, _ConflictConfig>{
    'Paracetamol': _ConflictConfig(
      conflicts: <String>['Alcohol', 'Caffeine'],
      message: 'Avoid alcohol and excess caffeine due to liver and side-effect risk.',
    ),
    'Ibuprofen': _ConflictConfig(
      conflicts: <String>['Alcohol', 'Caffeine', 'Spicy'],
      message: 'Can increase gastric irritation and bleeding risk.',
    ),
    'Amoxicillin': _ConflictConfig(
      conflicts: <String>['Dairy', 'Citrus', 'Caffeine'],
      message: 'Can reduce absorption and affect effectiveness.',
    ),
    'Metformin': _ConflictConfig(
      conflicts: <String>['Alcohol', 'High Sugar'],
      message: 'Can worsen glucose control and increase risk profile.',
    ),
  };

  static const Map<String, String> _medicationMap = <String, String>{
    'Paracetamol': 'Paracetamol',
    'Ibuprofen': 'Ibuprofen',
    'Aspirin': 'Ibuprofen',
    'Amoxicillin': 'Amoxicillin',
    'Azithromycin': 'Amoxicillin',
    'Metformin': 'Metformin',
    'Glucophage': 'Metformin',
  };

  void _detect() {
    final List<_ConflictResult> conflicts = <_ConflictResult>[];

    for (final String medName in widget.medicineNames) {
      final String? mapped = _medicationMap[medName];
      if (mapped == null) continue;
      final _ConflictConfig? config = _medicationConflicts[mapped];
      if (config == null) continue;

      for (final String selectedFood in _selectedFoods) {
        for (final MapEntry<String, List<String>> entry in _foodCategories.entries) {
          if (!entry.value.contains(selectedFood)) continue;
          if (!config.conflicts.contains(entry.key)) continue;
          conflicts.add(
            _ConflictResult(
              medication: medName,
              food: selectedFood,
              category: entry.key,
              message: config.message,
            ),
          );
        }
      }
    }

    setState(() => _results = conflicts);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050510),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Food-Medication Conflicts'),
      ),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[Color(0xFF050510), Color(0xFF040713), Color(0xFF050510)],
              stops: <double>[0.0, 0.45, 1.0],
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xAA141420),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2A2A3E)),
                  ),
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: widget.medicineNames.isEmpty
                        ? const <Widget>[
                            Text('No medicines available', style: TextStyle(color: Color(0xFF9CA3AF))),
                          ]
                        : widget.medicineNames
                            .map(
                              (String med) => Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0x332563EB),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(med, style: const TextStyle(color: Color(0xFFBFDBFE), fontSize: 12.5)),
                              ),
                            )
                            .toList(),
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Select foods you plan to eat',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                ..._foodCategories.entries.map((MapEntry<String, List<String>> entry) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(entry.key, style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 13)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: entry.value.map((String food) {
                            final bool isSelected = _selectedFoods.contains(food);
                            return FilterChip(
                              selected: isSelected,
                              onSelected: (_) {
                                setState(() {
                                  if (isSelected) {
                                    _selectedFoods.remove(food);
                                  } else {
                                    _selectedFoods.add(food);
                                  }
                                });
                              },
                              label: Text(food),
                              labelStyle: TextStyle(
                                color: isSelected ? Colors.white : const Color(0xFFD1D5DB),
                                fontSize: 12,
                              ),
                              selectedColor: const Color(0xFF16A34A),
                              backgroundColor: const Color(0xFF1A1F2D),
                              side: const BorderSide(color: Color(0xFF2A2A3E)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 4),
                FilledButton(
                  onPressed: widget.medicineNames.isEmpty || _selectedFoods.isEmpty ? null : _detect,
                  child: const Text('Detect Conflicts'),
                ),
                if (_results != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xAA141420),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2A2A3E)),
                    ),
                    child: _results!.isEmpty
                        ? const Row(
                            children: <Widget>[
                              Icon(Icons.check_circle_rounded, color: Color(0xFF4ADE80), size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'No conflicts found. These foods appear safe with your current medications.',
                                  style: TextStyle(color: Color(0xFF86EFAC)),
                                ),
                              ),
                            ],
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Text(
                                'Potential Conflicts Found',
                                style: TextStyle(color: Color(0xFFF87171), fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              ..._results!.map((r) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: <Widget>[
                                      const Padding(
                                        padding: EdgeInsets.only(top: 2),
                                        child: Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFF87171)),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '${r.medication} + ${r.food} (${r.category}): ${r.message}',
                                          style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12.5),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConflictConfig {
  const _ConflictConfig({required this.conflicts, required this.message});

  final List<String> conflicts;
  final String message;
}

class _ConflictResult {
  const _ConflictResult({
    required this.medication,
    required this.food,
    required this.category,
    required this.message,
  });

  final String medication;
  final String food;
  final String category;
  final String message;
}