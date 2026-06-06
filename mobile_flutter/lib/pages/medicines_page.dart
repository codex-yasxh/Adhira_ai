import 'package:flutter/material.dart';

import '../core/medicine_store.dart';
import 'food_conflict_page.dart';

class MedicinesPage extends StatefulWidget {
  const MedicinesPage({super.key});

  @override
  State<MedicinesPage> createState() => _MedicinesPageState();
}

class _MedicinesPageState extends State<MedicinesPage> {
  final List<_Medicine> _medicines = <_Medicine>[
    const _Medicine(id: 1, name: 'Paracetamol', dosage: '500mg', frequency: 'Twice daily', time: 'Morning & Evening'),
    const _Medicine(id: 2, name: 'Vitamin D', dosage: '1000IU', frequency: 'Once daily', time: 'Morning'),
    const _Medicine(id: 3, name: 'Aspirin', dosage: '75mg', frequency: 'Once daily', time: 'After breakfast'),
    const _Medicine(id: 4, name: 'Metformin', dosage: '500mg', frequency: 'Twice daily', time: 'With meals'),
    const _Medicine(id: 5, name: 'Amoxicillin', dosage: '250mg', frequency: 'Thrice daily', time: 'Every 8 hours'),
  ];

  void _syncStore() {
    MedicineStore.instance.names
      ..clear()
      ..addAll(_medicines.map((m) => m.name));
  }

  bool _expanded = false;
  static const int _previewCount = 3;

  @override
  void initState() {
    super.initState();
    _syncStore();
  }

  Future<void> _openAddMedicineSheet() async {
    final _MedicineFormResult? result = await showModalBottomSheet<_MedicineFormResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddMedicineSheet(),
    );
    if (result == null) return;
    setState(() {
      _medicines.add(_Medicine(
        id: DateTime.now().millisecondsSinceEpoch,
        name: result.name,
        dosage: result.dosage,
        frequency: result.frequency,
        time: result.time,
      ));
      _syncStore();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool hasMore = _medicines.length > _previewCount;
    final List<_Medicine> visible = _expanded ? _medicines : _medicines.take(_previewCount).toList();

    return Scaffold(
      backgroundColor: const Color(0xFF050510),
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
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // ── Header ──
                    Row(
                      children: <Widget>[
                        const Expanded(
                          child: Text(
                            'My Medications',
                            style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: _openAddMedicineSheet,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.add_rounded, size: 16),
                          label: const Text('Add', style: TextStyle(fontSize: 13)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Track prescriptions and review potential food interactions.',
                      style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                    ),
                    const SizedBox(height: 14),

                    // ── Medicines Section ──
                    Container(
                      decoration: BoxDecoration(
                        color: const Color(0xAA141420),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFF2A2A3E)),
                      ),
                      child: Column(
                        children: <Widget>[
                          // Section header row
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
                            child: Row(
                              children: <Widget>[
                                const Icon(Icons.medication_rounded, size: 16, color: Color(0xFF60A5FA)),
                                const SizedBox(width: 6),
                                Text(
                                  '${_medicines.length} Medicine${_medicines.length == 1 ? '' : 's'}',
                                  style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12.5),
                                ),
                                const Spacer(),
                                if (hasMore)
                                  GestureDetector(
                                    onTap: () => setState(() => _expanded = !_expanded),
                                    child: Text(
                                      _expanded ? 'Show Less' : 'View More',
                                      style: const TextStyle(
                                        color: Color(0xFF60A5FA),
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                const SizedBox(width: 6),
                              ],
                            ),
                          ),

                          const Divider(height: 1, color: Color(0xFF2A2A3E)),

                          // Scrollable list section
                          AnimatedSize(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: _expanded ? double.infinity : (_medicines.isEmpty ? 60 : _previewCount * 64.0),
                              ),
                              child: _medicines.isEmpty
                                  ? const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: Text(
                                        'No medications added yet. Tap Add to get started.',
                                        style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 13),
                                      ),
                                    )
                                  : ListView.separated(
                                      shrinkWrap: true,
                                      physics: _expanded
                                          ? const NeverScrollableScrollPhysics()
                                          : const ClampingScrollPhysics(),
                                      itemCount: visible.length,
                                      separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF2A2A3E)),
                                      itemBuilder: (_, int i) => _MedicineRow(
                                        medicine: visible[i],
                                        onDelete: () => setState(() { _medicines.remove(visible[i]); _syncStore(); }),
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ── Conflict CTA ──
                    _ConflictCtaCard(
                      medicines: _medicines,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => FoodConflictPage(
                            medicineNames: _medicines.map((m) => m.name).toList(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Compact medicine row ──────────────────────────────────────────────────────

class _MedicineRow extends StatelessWidget {
  const _MedicineRow({required this.medicine, required this.onDelete});

  final _Medicine medicine;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0x222563EB),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.medication_rounded, size: 18, color: Color(0xFF60A5FA)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        medicine.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0x332563EB),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        medicine.dosage,
                        style: const TextStyle(color: Color(0xFFBFDBFE), fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '${medicine.frequency} · ${medicine.time}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onDelete,
            child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF4B5563)),
          ),
        ],
      ),
    );
  }
}

// ── Conflict CTA ─────────────────────────────────────────────────────────────

class _ConflictCtaCard extends StatelessWidget {
  const _ConflictCtaCard({required this.medicines, required this.onTap});

  final List<_Medicine> medicines;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xAA141420),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF2A2A3E)),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0x332563EB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.restaurant_menu_rounded, color: Color(0xFF93C5FD), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Food-Medication Conflict Checker',
                    style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${medicines.length} medicine(s) · Tap to detect conflicts',
                    style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}

// ── Add Medicine Sheet ────────────────────────────────────────────────────────

class _AddMedicineSheet extends StatefulWidget {
  const _AddMedicineSheet();

  @override
  State<_AddMedicineSheet> createState() => _AddMedicineSheetState();
}

class _AddMedicineSheetState extends State<_AddMedicineSheet> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _dosageCtrl = TextEditingController();
  final TextEditingController _freqCtrl = TextEditingController();
  final TextEditingController _timeCtrl = TextEditingController();

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dosageCtrl.dispose();
    _freqCtrl.dispose();
    _timeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF101521),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      padding: EdgeInsets.fromLTRB(14, 14, 14, 14 + MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Add Medicine',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(child: _field(_nameCtrl, 'Medicine Name')),
                  const SizedBox(width: 8),
                  Expanded(child: _field(_dosageCtrl, 'Dosage')),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(child: _field(_freqCtrl, 'Frequency')),
                  const SizedBox(width: 8),
                  Expanded(child: _field(_timeCtrl, 'Time')),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        if (!_formKey.currentState!.validate()) return;
                        Navigator.of(context).pop(
                          _MedicineFormResult(
                            name: _nameCtrl.text.trim(),
                            dosage: _dosageCtrl.text.trim(),
                            frequency: _freqCtrl.text.trim(),
                            time: _timeCtrl.text.trim(),
                          ),
                        );
                      },
                      child: const Text('Add'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String label) {
    return TextFormField(
      controller: c,
      style: const TextStyle(color: Colors.white, fontSize: 13),
      validator: (String? v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
        filled: true,
        fillColor: const Color(0xFF151B2A),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF2A2A3E)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF2A2A3E)),
        ),
      ),
    );
  }
}

// ── Models ────────────────────────────────────────────────────────────────────

class _Medicine {
  const _Medicine({
    required this.id,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.time,
  });

  final int id;
  final String name;
  final String dosage;
  final String frequency;
  final String time;
}

class _MedicineFormResult {
  const _MedicineFormResult({
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.time,
  });

  final String name;
  final String dosage;
  final String frequency;
  final String time;
}
