import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/network/api_client.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  late List<_MetricItem> _metrics;
  bool _showStats = false;
  bool _isLoading = true;
  DateTime _lastUpdated = DateTime.now();
  final ApiClient _apiClient = ApiClient();
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Map [_MetricItem.title] → backend DB column name
  static const Map<String, String> _titleToField = <String, String>{
    'Blood Pressure': 'blood_pressure',
    'Blood Sugar': 'blood_sugar',
    'Heart Rate': 'heart_rate',
    'Sleep Hours': 'sleep_hours',
    'Steps': 'steps',
    'Body Temperature': 'body_temp',
    'SpO2': 'spo2',
    'Respiratory Rate': 'resp_rate',
    'Weight': 'weight',
    'BMI': 'bmi',
  };

  @override
  void initState() {
    super.initState();
    _metrics = _buildDefaultMetrics();
    _fetchMetrics();
  }

  List<_MetricItem> _buildDefaultMetrics() {
    return <_MetricItem>[
      _MetricItem(
        title: 'Blood Pressure',
        value: '120/80',
        unit: 'mmHg',
        status: _MetricStatus.normal,
        trend: _MetricTrend.up,
        change: '+2',
        icon: Icons.favorite_rounded,
        iconColor: const Color(0xFFEF4444),
      ),
      _MetricItem(
        title: 'Blood Sugar',
        value: '95',
        unit: 'mg/dL',
        status: _MetricStatus.normal,
        trend: _MetricTrend.down,
        change: '-5',
        icon: Icons.water_drop_rounded,
        iconColor: const Color(0xFF60A5FA),
      ),
      _MetricItem(
        title: 'Heart Rate',
        value: '72',
        unit: 'bpm',
        status: _MetricStatus.normal,
        trend: _MetricTrend.stable,
        change: '0',
        icon: Icons.monitor_heart_rounded,
        iconColor: const Color(0xFFF87171),
      ),
      _MetricItem(
        title: 'Sleep Hours',
        value: '7',
        unit: 'hours',
        status: _MetricStatus.normal,
        trend: _MetricTrend.stable,
        change: '0',
        icon: Icons.bedtime_rounded,
        iconColor: const Color(0xFFFBBF24),
      ),
      _MetricItem(
        title: 'Steps',
        value: '10000',
        unit: 'steps',
        status: _MetricStatus.normal,
        trend: _MetricTrend.up,
        change: '+1000',
        icon: Icons.directions_walk_rounded,
        iconColor: const Color(0xFF4ADE80),
      ),
      _MetricItem(
        title: 'Body Temperature',
        value: '98.6',
        unit: 'F',
        status: _MetricStatus.normal,
        trend: _MetricTrend.stable,
        change: '0',
        icon: Icons.device_thermostat_rounded,
        iconColor: const Color(0xFF22D3EE),
      ),
      _MetricItem(
        title: 'SpO2',
        value: '98',
        unit: '%',
        status: _MetricStatus.normal,
        trend: _MetricTrend.stable,
        change: '0',
        icon: Icons.bubble_chart_rounded,
        iconColor: const Color(0xFF60A5FA),
      ),
      _MetricItem(
        title: 'Respiratory Rate',
        value: '16',
        unit: 'br/min',
        status: _MetricStatus.normal,
        trend: _MetricTrend.stable,
        change: '0',
        icon: Icons.air_rounded,
        iconColor: const Color(0xFF34D399),
      ),
      _MetricItem(
        title: 'Weight',
        value: '68',
        unit: 'kg',
        status: _MetricStatus.normal,
        trend: _MetricTrend.down,
        change: '-1',
        icon: Icons.monitor_weight_rounded,
        iconColor: const Color(0xFFA78BFA),
      ),
      _MetricItem(
        title: 'BMI',
        value: '22.4',
        unit: '',
        status: _MetricStatus.normal,
        trend: _MetricTrend.stable,
        change: '0',
        icon: Icons.straighten_rounded,
        iconColor: const Color(0xFFF59E0B),
      ),
    ];
  }

  Future<void> _fetchMetrics() async {
    final String? userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await _apiClient.getJson(
        '/health/metrics',
        queryParams: <String, String>{'user_id': userId},
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> envelope =
            jsonDecode(response.body) as Map<String, dynamic>;
        // Backend returns { "status": "ok", "data": { ...metrics... } }
        final dynamic rawData = envelope['data'];
        if (rawData is Map<String, dynamic> && rawData.isNotEmpty) {
          // Parse updated_at if present
          final String? updatedAtStr = rawData['updated_at'] as String?;
          DateTime? updatedAt;
          if (updatedAtStr != null) {
            updatedAt = DateTime.tryParse(updatedAtStr);
          }

          if (mounted) {
            setState(() {
              _metrics = _applyBackendData(rawData);
              if (updatedAt != null) _lastUpdated = updatedAt.toLocal();
              _isLoading = false;
            });
          }
          return;
        }
      }
    } catch (e) {
      debugPrint('Dashboard: failed to fetch metrics — $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  List<_MetricItem> _applyBackendData(Map<String, dynamic> data) {
    return _metrics.map((item) {
      final String? field = _titleToField[item.title];
      if (field == null || data[field] == null) return item;
      final String backendValue = data[field].toString().trim();
      if (backendValue.isEmpty) return item;
      final ({_MetricStatus status, _MetricTrend trend, String change}) eval =
          _evaluate(item.title, backendValue);
      return item.copyWith(
        value: backendValue,
        status: eval.status,
        trend: eval.trend,
        change: eval.change,
      );
    }).toList();
  }

  /// Derives status + trend label purely from value and clinical ranges.
  /// No backend needed — all logic lives here.
  static ({_MetricStatus status, _MetricTrend trend, String change}) _evaluate(
      String title, String raw) {
    _MetricStatus st = _MetricStatus.normal;
    _MetricTrend tr = _MetricTrend.stable;
    String ch = 'Stable';

    switch (title) {
      case 'Blood Pressure':
        final parts = raw.split('/');
        final sys = double.tryParse(parts.firstOrNull ?? '') ?? 120;
        final dia = double.tryParse(parts.length > 1 ? parts[1] : '') ?? 80;
        if (sys >= 180 || dia >= 120) {
          st = _MetricStatus.danger; tr = _MetricTrend.up; ch = 'Crisis';
        } else if (sys >= 140 || dia >= 90) {
          st = _MetricStatus.warning; tr = _MetricTrend.up; ch = 'High';
        } else if (sys >= 130 || dia >= 80) {
          st = _MetricStatus.warning; tr = _MetricTrend.up; ch = 'Elevated';
        } else if (sys < 90 || dia < 60) {
          st = _MetricStatus.warning; tr = _MetricTrend.down; ch = 'Low';
        }

      case 'Blood Sugar':
        final v = double.tryParse(raw) ?? 95;
        if (v >= 200)       { st = _MetricStatus.danger;  tr = _MetricTrend.up;   ch = 'Very High'; }
        else if (v >= 126)  { st = _MetricStatus.warning; tr = _MetricTrend.up;   ch = 'High'; }
        else if (v >= 100)  { st = _MetricStatus.warning; tr = _MetricTrend.up;   ch = 'Pre-diabetic'; }
        else if (v < 70)    { st = _MetricStatus.danger;  tr = _MetricTrend.down; ch = 'Low'; }

      case 'Heart Rate':
        final v = double.tryParse(raw) ?? 72;
        if (v >= 130)       { st = _MetricStatus.danger;  tr = _MetricTrend.up;   ch = 'Very High'; }
        else if (v >= 100)  { st = _MetricStatus.warning; tr = _MetricTrend.up;   ch = 'High'; }
        else if (v < 40)    { st = _MetricStatus.danger;  tr = _MetricTrend.down; ch = 'Very Low'; }
        else if (v < 60)    { st = _MetricStatus.warning; tr = _MetricTrend.down; ch = 'Low'; }

      case 'Sleep Hours':
        final v = double.tryParse(raw) ?? 7;
        if (v < 4)          { st = _MetricStatus.danger;  tr = _MetricTrend.down; ch = 'Critical'; }
        else if (v < 6)     { st = _MetricStatus.warning; tr = _MetricTrend.down; ch = 'Low'; }
        else if (v > 10)    { st = _MetricStatus.warning; tr = _MetricTrend.up;   ch = 'Excess'; }

      case 'Steps':
        final v = double.tryParse(raw) ?? 10000;
        if (v < 2000)       { st = _MetricStatus.danger;  tr = _MetricTrend.down; ch = 'Very Low'; }
        else if (v < 5000)  { st = _MetricStatus.warning; tr = _MetricTrend.down; ch = 'Low'; }
        else if (v >= 5000) { tr = _MetricTrend.up; ch = '+${v.toInt()}'; }

      case 'Body Temperature':
        final v = double.tryParse(raw) ?? 98.6;
        if (v >= 103)       { st = _MetricStatus.danger;  tr = _MetricTrend.up;   ch = 'High Fever'; }
        else if (v >= 100.4){ st = _MetricStatus.warning; tr = _MetricTrend.up;   ch = 'Fever'; }
        else if (v < 96)    { st = _MetricStatus.danger;  tr = _MetricTrend.down; ch = 'Hypothermia'; }
        else if (v < 97)    { st = _MetricStatus.warning; tr = _MetricTrend.down; ch = 'Low'; }

      case 'SpO2':
        final v = double.tryParse(raw) ?? 98;
        if (v < 90)         { st = _MetricStatus.danger;  tr = _MetricTrend.down; ch = 'Critical'; }
        else if (v < 95)    { st = _MetricStatus.warning; tr = _MetricTrend.down; ch = 'Low'; }

      case 'Respiratory Rate':
        final v = double.tryParse(raw) ?? 16;
        if (v >= 30)        { st = _MetricStatus.danger;  tr = _MetricTrend.up;   ch = 'Very High'; }
        else if (v >= 25)   { st = _MetricStatus.warning; tr = _MetricTrend.up;   ch = 'High'; }
        else if (v < 8)     { st = _MetricStatus.danger;  tr = _MetricTrend.down; ch = 'Very Low'; }
        else if (v < 12)    { st = _MetricStatus.warning; tr = _MetricTrend.down; ch = 'Low'; }

      case 'BMI':
        final v = double.tryParse(raw) ?? 22.4;
        if (v >= 40)        { st = _MetricStatus.danger;  tr = _MetricTrend.up;   ch = 'Obese III'; }
        else if (v >= 35)   { st = _MetricStatus.warning; tr = _MetricTrend.up;   ch = 'Obese II'; }
        else if (v >= 30)   { st = _MetricStatus.warning; tr = _MetricTrend.up;   ch = 'Obese I'; }
        else if (v >= 25)   { st = _MetricStatus.warning; tr = _MetricTrend.up;   ch = 'Overweight'; }
        else if (v < 16)    { st = _MetricStatus.danger;  tr = _MetricTrend.down; ch = 'Severe Thin'; }
        else if (v < 18.5)  { st = _MetricStatus.warning; tr = _MetricTrend.down; ch = 'Underweight'; }
    }

    return (status: st, trend: tr, change: ch);
  }

  Future<void> _saveMetricsToBackend() async {
    final String? userId = _supabase.auth.currentUser?.id;
    if (userId == null) {
      debugPrint('Dashboard: no user logged in — skipping save');
      return;
    }

    try {
      final Map<String, dynamic> body = <String, dynamic>{'user_id': userId};
      for (final _MetricItem item in _metrics) {
        final String? field = _titleToField[item.title];
        if (field != null) {
          body[field] = item.value;
        }
      }

      final response = await _apiClient.postJson(
        '/health/update',
        body: body,
      );

      if (response.statusCode == 200) {
        debugPrint('Dashboard: metrics saved successfully');
      } else {
        debugPrint('Dashboard: save returned ${response.statusCode}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Saved locally — will sync on next open'),
              backgroundColor: Color(0xFF1E293B),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Dashboard: failed to save metrics — $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Saved locally — will sync on next open'),
            backgroundColor: Color(0xFF1E293B),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _openEditSheet() async {
    final List<String>? updatedValues = await showModalBottomSheet<List<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditMetricsSheet(metrics: _metrics),
    );
    if (updatedValues == null) return;

    setState(() {
      _metrics = _metrics.asMap().entries.map((entry) {
        final int index = entry.key;
        final _MetricItem item = entry.value;
        final String newValue = updatedValues[index];
        final eval = _evaluate(item.title, newValue);
        return item.copyWith(
          value: newValue,
          status: eval.status,
          trend: eval.trend,
          change: eval.change,
        );
      }).toList();
      _lastUpdated = DateTime.now();
    });

    // Persist to backend in background
    _saveMetricsToBackend();
  }

  int _gridCount(double width) {
    if (width >= 1080) return 3;
    return 2;
  }

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    final int crossAxisCount = _gridCount(width);

    return Scaffold(
      backgroundColor: const Color(0xFF050510),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: <Color>[
                Color(0xFF050510),
                Color(0xFF040713),
                Color(0xFF050510),
              ],
              stops: <double>[0.0, 0.45, 1.0],
            ),
          ),
          child: Stack(
            children: <Widget>[
              Positioned(
                top: -90,
                right: -70,
                child: Container(
                  width: 260,
                  height: 260,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: <Color>[Color(0x332A6BFF), Color(0x00102440)],
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF3B82F6),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 14),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 980),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                _DashboardHeader(
                                  onEditTap: _openEditSheet,
                                  lastUpdated: _lastUpdated,
                                ),
                                const SizedBox(height: 8),
                                GridView.builder(
                                  itemCount: _metrics.length,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    crossAxisSpacing: 8,
                                    mainAxisSpacing: 8,
                                    childAspectRatio: width < 390 ? 1.55 : 1.72,
                                  ),
                                  itemBuilder: (_, int index) => _HealthMetricCard(metric: _metrics[index]),
                                ),
                                const SizedBox(height: 32),
                                Align(
                                  child: _StatsToggleButton(
                                    isExpanded: _showStats,
                                    onTap: () => setState(() => _showStats = !_showStats),
                                  ),
                                ),
                                if (_showStats) ...<Widget>[
                                  const SizedBox(height: 12),
                                  _HealthStatsPanel(metrics: _metrics),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.onEditTap,
    required this.lastUpdated,
  });

  final VoidCallback onEditTap;
  final DateTime lastUpdated;

  @override
  Widget build(BuildContext context) {
    final bool compact = MediaQuery.sizeOf(context).width < 440;
    final String stamp =
        '${_month(lastUpdated.month)} ${lastUpdated.day}, ${_hh(lastUpdated.hour)}:${_hh(lastUpdated.minute)}';

    return Container(
      padding: EdgeInsets.fromLTRB(compact ? 11 : 12, 10, compact ? 11 : 12, 9),
      decoration: BoxDecoration(
        color: const Color(0xAA141420),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A3E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const <Widget>[
                    Text(
                      'Health Dashboard',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 21.5,
                        fontWeight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    SizedBox(height: 2),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onEditTap,
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFD7DEEA),
                  backgroundColor: const Color(0xFF1B2335),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('Edit', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  'Monitor your health metrics',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12.5),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.schedule_rounded, size: 11.5, color: Color(0xFF6B7280)),
              const SizedBox(width: 3),
              Text(
                'Last updated $stamp',
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 11.3),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _month(int m) {
    const List<String> names = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return names[m - 1];
  }

  static String _hh(int v) => v.toString().padLeft(2, '0');
}

class _HealthMetricCard extends StatelessWidget {
  const _HealthMetricCard({required this.metric});

  final _MetricItem metric;

  @override
  Widget build(BuildContext context) {
    final ({Color bg, Color border}) style = _statusStyle(metric.status);
    final ({IconData icon, Color color, String label}) trend = _trendStyle(metric.trend, metric.change);

    return Container(
      decoration: BoxDecoration(
        color: style.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: style.border),
      ),
      padding: const EdgeInsets.all(9),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  metric.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
                ),
              ),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: const Color(0x1AFFFFFF),
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Icon(metric.icon, color: metric.iconColor, size: 14.5),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Flexible(
                child: Text(
                  metric.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18.5,
                    fontWeight: FontWeight.w700,
                    height: 0.95,
                  ),
                ),
              ),
              const SizedBox(width: 3),
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Text(
                  metric.unit,
                  style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: <Widget>[
              Icon(trend.icon, size: 11.5, color: trend.color),
              const SizedBox(width: 3),
              Text(
                trend.label,
                style: TextStyle(color: trend.color, fontSize: 10.3, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static ({Color bg, Color border}) _statusStyle(_MetricStatus status) {
    switch (status) {
      case _MetricStatus.warning:
        return (bg: const Color(0x1AF59E0B), border: const Color(0x66F59E0B));
      case _MetricStatus.danger:
        return (bg: const Color(0x1AEF4444), border: const Color(0x66EF4444));
      case _MetricStatus.normal:
        return (bg: const Color(0xAA141420), border: const Color(0xFF2A2A3E));
    }
  }

  static ({IconData icon, Color color, String label}) _trendStyle(_MetricTrend trend, String change) {
    switch (trend) {
      case _MetricTrend.up:
        return (icon: Icons.trending_up_rounded, color: const Color(0xFF4ADE80), label: change);
      case _MetricTrend.down:
        return (icon: Icons.trending_down_rounded, color: const Color(0xFFF87171), label: change);
      case _MetricTrend.stable:
        return (icon: Icons.remove_rounded, color: const Color(0xFF9CA3AF), label: 'Stable');
    }
  }
}

class _StatsToggleButton extends StatelessWidget {
  const _StatsToggleButton({required this.isExpanded, required this.onTap});

  final bool isExpanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.query_stats_rounded, size: 18),
      label: Text(isExpanded ? 'Hide Health Stats' : 'Get Health Stats'),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF1D4ED8),
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
    );
  }
}

class _HealthStatsPanel extends StatelessWidget {
  const _HealthStatsPanel({required this.metrics});

  final List<_MetricItem> metrics;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        color: const Color(0xAA141420),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF2A2A3E)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Health Metrics Overview',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text(
            'Relative normalized distribution (0 - 100)',
            style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 12),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: CustomPaint(
              painter: _RadarPainter(
                values: metrics.map((m) => _normalizeMetric(m)).toList(),
                labels: metrics.map((m) => m.title).toList(),
              ),
              child: Center(
                child: Text(
                  'RADAR',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.18),
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.8,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static double _normalizeMetric(_MetricItem metric) {
    final String v = metric.value.trim();
    switch (metric.title) {
      case 'Blood Pressure':
        final List<String> parts = v.split('/');
        final double systolic = parts.isNotEmpty ? (double.tryParse(parts.first) ?? 0) : 0;
        final double diastolic = parts.length > 1 ? (double.tryParse(parts[1]) ?? 0) : 0;
        final double sScore = _scoreTargetBand(systolic, 110, 130, min: 80, max: 200);
        final double dScore = _scoreTargetBand(diastolic, 70, 85, min: 50, max: 130);
        return ((sScore + dScore) / 2).clamp(0, 100);
      case 'Heart Rate':
        return _scoreTargetBand(double.tryParse(v) ?? 0, 60, 100, min: 35, max: 200);
      case 'Blood Sugar':
        return _scoreTargetBand(double.tryParse(v) ?? 0, 70, 140, min: 40, max: 350);
      case 'Sleep Hours':
        return _scoreTargetBand(double.tryParse(v) ?? 0, 7, 9, min: 0, max: 14);
      case 'Steps':
        final double steps = double.tryParse(v) ?? 0;
        if (steps <= 0) return 0;
        if (steps < 4000) return (steps / 4000) * 45;
        if (steps <= 12000) return 80 + ((steps - 4000) / 8000) * 20;
        if (steps <= 18000) return 100 - ((steps - 12000) / 6000) * 20;
        return 80 - ((steps - 18000) / 12000) * 40;
      case 'Body Temperature':
        return _scoreTargetBand(double.tryParse(v) ?? 0, 97.0, 99.2, min: 94, max: 104);
      case 'SpO2':
        return _scoreTargetBand(double.tryParse(v) ?? 0, 95, 100, min: 70, max: 100);
      case 'Respiratory Rate':
        return _scoreTargetBand(double.tryParse(v) ?? 0, 12, 20, min: 6, max: 40);
      case 'Weight':
        return _scoreTargetBand(double.tryParse(v) ?? 0, 50, 80, min: 30, max: 160);
      case 'BMI':
        return _scoreTargetBand(double.tryParse(v) ?? 0, 18.5, 24.9, min: 12, max: 45);
      default:
        return (double.tryParse(v) ?? 0).clamp(0, 100);
    }
  }

  static double _scoreTargetBand(
    double value,
    double idealLow,
    double idealHigh, {
    required double min,
    required double max,
  }) {
    if (value.isNaN || value <= 0) return 0;
    if (value >= idealLow && value <= idealHigh) return 100;

    if (value < idealLow) {
      final double span = idealLow - min;
      if (span <= 0) return 0;
      return ((value - min) / span * 100).clamp(0, 100);
    }

    final double span = max - idealHigh;
    if (span <= 0) return 0;
    return ((max - value) / span * 100).clamp(0, 100);
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({required this.values, required this.labels});

  final List<double> values;
  final List<String> labels;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final Offset center = Offset(size.width / 2, size.height / 2);
    final double maxR = math.min(size.width, size.height) * 0.37;

    final Paint grid = Paint()
      ..color = const Color(0xFF2A3348)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int layer = 1; layer <= 4; layer++) {
      final double r = maxR * layer / 4;
      final Path p = Path();
      for (int i = 0; i < values.length; i++) {
        final double angle = -math.pi / 2 + (2 * math.pi * i / values.length);
        final Offset pt = center + Offset(math.cos(angle) * r, math.sin(angle) * r);
        if (i == 0) {
          p.moveTo(pt.dx, pt.dy);
        } else {
          p.lineTo(pt.dx, pt.dy);
        }
      }
      p.close();
      canvas.drawPath(p, grid);
    }

    final Path data = Path();
    for (int i = 0; i < values.length; i++) {
      final double angle = -math.pi / 2 + (2 * math.pi * i / values.length);
      final double r = maxR * (values[i] / 100);
      final Offset pt = center + Offset(math.cos(angle) * r, math.sin(angle) * r);
      if (i == 0) {
        data.moveTo(pt.dx, pt.dy);
      } else {
        data.lineTo(pt.dx, pt.dy);
      }
    }
    data.close();

    canvas.drawPath(
      data,
      Paint()
        ..color = const Color(0x663B82F6)
        ..style = PaintingStyle.fill,
    );

    canvas.drawPath(
      data,
      Paint()
        ..color = const Color(0xFF3B82F6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final TextPainter tp = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 1,
    );
    final int len = math.min(labels.length, values.length);
    for (int i = 0; i < len; i++) {
      final double angle = -math.pi / 2 + (2 * math.pi * i / values.length);
      final Offset anchor =
          center + Offset(math.cos(angle) * (maxR + 18), math.sin(angle) * (maxR + 18));
      final String label = _shortLabel(labels[i]);
      tp.text = TextSpan(
        text: label,
        style: const TextStyle(
          color: Color(0xFF9CA3AF),
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      );
      tp.layout();
      tp.paint(canvas, Offset(anchor.dx - tp.width / 2, anchor.dy - tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.labels != labels;
  }

  static String _shortLabel(String label) {
    const Map<String, String> map = <String, String>{
      'Blood Pressure': 'BP',
      'Blood Sugar': 'Sugar',
      'Heart Rate': 'Heart',
      'Sleep Hours': 'Sleep',
      'Body Temperature': 'Temp',
      'Respiratory Rate': 'Resp',
    };
    return map[label] ?? label;
  }
}

class _EditMetricsSheet extends StatefulWidget {
  const _EditMetricsSheet({required this.metrics});

  final List<_MetricItem> metrics;

  @override
  State<_EditMetricsSheet> createState() => _EditMetricsSheetState();
}

class _EditMetricsSheetState extends State<_EditMetricsSheet> {
  late final List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = widget.metrics.map((m) => TextEditingController(text: m.value)).toList();
  }

  @override
  void dispose() {
    for (final TextEditingController c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF101521),
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      padding: EdgeInsets.only(
        left: 14,
        right: 14,
        top: 14,
        bottom: 14 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text(
              'Edit Health Metrics',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: widget.metrics.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, int index) {
                  final _MetricItem m = widget.metrics[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        m.title,
                        style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 12.5),
                      ),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _controllers[index],
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: InputDecoration(
                          isDense: true,
                          filled: true,
                          fillColor: const Color(0xFF151B2A),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF2A2A3E)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(color: Color(0xFF2A2A3E)),
                          ),
                          suffixText: m.unit,
                          suffixStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF2A2A3E)),
                      foregroundColor: const Color(0xFFD1D5DB),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop(_controllers.map((c) => c.text.trim()).toList());
                    },
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _MetricStatus { normal, warning, danger }

enum _MetricTrend { up, down, stable }

class _MetricItem {
  const _MetricItem({
    required this.title,
    required this.value,
    required this.unit,
    required this.status,
    required this.trend,
    required this.change,
    required this.icon,
    required this.iconColor,
  });

  final String title;
  final String value;
  final String unit;
  final _MetricStatus status;
  final _MetricTrend trend;
  final String change;
  final IconData icon;
  final Color iconColor;

  _MetricItem copyWith({
    String? title,
    String? value,
    String? unit,
    _MetricStatus? status,
    _MetricTrend? trend,
    String? change,
    IconData? icon,
    Color? iconColor,
  }) {
    return _MetricItem(
      title: title ?? this.title,
      value: value ?? this.value,
      unit: unit ?? this.unit,
      status: status ?? this.status,
      trend: trend ?? this.trend,
      change: change ?? this.change,
      icon: icon ?? this.icon,
      iconColor: iconColor ?? this.iconColor,
    );
  }
}