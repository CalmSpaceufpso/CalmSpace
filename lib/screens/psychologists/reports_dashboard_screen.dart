import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

enum DateRange { thisWeek, thisMonth, last3Months, allTime }

class ReportsDashboardScreen extends StatefulWidget {
  final String psychologistId;

  const ReportsDashboardScreen({super.key, required this.psychologistId});

  @override
  State<ReportsDashboardScreen> createState() => _ReportsDashboardScreenState();
}

class _ReportsDashboardScreenState extends State<ReportsDashboardScreen> {
  DateRange _selectedRange = DateRange.thisMonth;
  bool _loading = true;

  int _totalAppointments = 0;
  int _completedAppointments = 0;
  int _cancelledAppointments = 0;
  int _scheduledAppointments = 0;
  int _noShowAppointments = 0;
  double _pricePerSession = 50000;

  // Constants
  static const Color _primary = Color(0xFF2B5BFF);
  static const Color _bg = Color(0xFFF4F6FB);
  static const Color _completedColor = Color(0xFF10B981); // Green
  static const Color _cancelledColor = Color(0xFFEF4444); // Red
  static const Color _scheduledColor = Color(0xFF3B82F6); // Blue
  static const Color _noShowColor    = Color(0xFFF59E0B); // Amber
  static const Color _textMain = Color(0xFF0D1B3E);
  static const Color _textSub = Color(0xFF8A94A6);

  List<Map<String, dynamic>> _allAppointments = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _loading = true);
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.psychologistId)
          .get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        _pricePerSession = (data['pricePerSession'] as num?)?.toDouble() ?? 50000;
      }

      final snap = await FirebaseFirestore.instance
          .collection('appointments')
          .where('psychologistId', isEqualTo: widget.psychologistId)
          .get();

      _allAppointments = snap.docs.map((e) => e.data()).toList();
      _calculateMetrics();
    } catch (e) {
      print('Error fetching reports: $e');
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _calculateMetrics() {
    final now = DateTime.now();
    DateTime startDate;

    switch (_selectedRange) {
      case DateRange.thisWeek:
        startDate = now.subtract(Duration(days: now.weekday - 1));
        break;
      case DateRange.thisMonth:
        startDate = DateTime(now.year, now.month, 1);
        break;
      case DateRange.last3Months:
        startDate = DateTime(now.year, now.month - 3, 1);
        break;
      case DateRange.allTime:
        startDate = DateTime(2000);
        break;
    }
    
    _totalAppointments = 0;
    _completedAppointments = 0;
    _cancelledAppointments = 0;
    _scheduledAppointments = 0;
    _noShowAppointments = 0;

    for (var apt in _allAppointments) {
      final dateStr = apt['date'] as String? ?? '';
      final timeStr = apt['startTime'] as String? ?? '00:00';
      if (dateStr.isEmpty) continue;

      final dt = DateTime.tryParse('$dateStr $timeStr:00') ?? DateTime(2000);

      // Filter by date
      if (dt.isAfter(startDate.subtract(const Duration(days: 1))) && 
          dt.isBefore(now.add(const Duration(days: 30)))) { // Include future scheduled
        
        // Count
        _totalAppointments++;
        final status = apt['status'] as String? ?? '';
        
        // Also we should consider past 'scheduled' as completed if we don't update them, 
        // but for now let's rely strictly on the status field.
        if (status == 'completed') {
          _completedAppointments++;
        } else if (status == 'cancelled' || status == 'canceled') {
          _cancelledAppointments++;
        } else if (status == 'no_show') {
          _noShowAppointments++;
        } else {
          _scheduledAppointments++;
        }
      }
    }

    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text('Reportes de Citas', style: TextStyle(color: _textMain, fontWeight: FontWeight.bold, fontSize: 17)),
        iconTheme: const IconThemeData(color: _textMain),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : RefreshIndicator(
              onRefresh: _fetchData,
              color: _primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildRangeSelector(),
                    const SizedBox(height: 24),
                    _buildKPIs(),
                    const SizedBox(height: 32),
                    if (_totalAppointments > 0) ...[
                      const Text('Distribución de Citas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textMain)),
                      const SizedBox(height: 16),
                      _buildChart(),
                      const SizedBox(height: 32),
                    ],
                    const Text('Ingresos Estimados', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _textMain)),
                    const SizedBox(height: 16),
                    _buildEarningsCard(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildRangeSelector() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildSegmentButton('Semana', DateRange.thisWeek),
            _buildSegmentButton('Mes', DateRange.thisMonth),
            _buildSegmentButton('3 Meses', DateRange.last3Months),
            _buildSegmentButton('Todo', DateRange.allTime),
          ],
        ),
      ),
    );
  }

  Widget _buildSegmentButton(String label, DateRange range) {
    final isSelected = _selectedRange == range;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedRange = range;
        });
        _calculateMetrics();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(
          color: isSelected ? _primary : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : _textSub,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildKPIs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _KPICard(
          title: 'Total Citas',
          value: _totalAppointments.toString(),
          icon: Icons.calendar_month_rounded,
          color: _primary,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _KPICard(
                title: 'Completadas',
                value: _completedAppointments.toString(),
                icon: Icons.check_circle_outline_rounded,
                color: _completedColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _KPICard(
                title: 'Pendientes',
                value: _scheduledAppointments.toString(),
                icon: Icons.schedule_rounded,
                color: _scheduledColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _KPICard(
                title: 'Ausencias',
                value: _noShowAppointments.toString(),
                icon: Icons.person_off_rounded,
                color: _noShowColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _KPICard(
                title: 'Canceladas',
                value: _cancelledAppointments.toString(),
                icon: Icons.cancel_outlined,
                color: _cancelledColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildChart() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 50,
                sections: _getChartSections(),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 12,
            children: [
              _LegendItem('Pendientes', _scheduledColor),
              _LegendItem('Completadas', _completedColor),
              _LegendItem('Ausencias', _noShowColor),
              _LegendItem('Canceladas', _cancelledColor),
            ],
          )
        ],
      ),
    );
  }

  List<PieChartSectionData> _getChartSections() {
    final double total = _totalAppointments.toDouble();
    if (total == 0) return [];

    return [
      if (_completedAppointments > 0)
        PieChartSectionData(
          color: _completedColor,
          value: _completedAppointments.toDouble(),
          title: '${((_completedAppointments / total) * 100).toStringAsFixed(0)}%',
          radius: 50,
          titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      if (_cancelledAppointments > 0)
        PieChartSectionData(
          color: _cancelledColor,
          value: _cancelledAppointments.toDouble(),
          title: '${((_cancelledAppointments / total) * 100).toStringAsFixed(0)}%',
          radius: 45,
          titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      if (_scheduledAppointments > 0)
        PieChartSectionData(
          color: _scheduledColor,
          value: _scheduledAppointments.toDouble(),
          title: '${((_scheduledAppointments / total) * 100).toStringAsFixed(0)}%',
          radius: 40,
          titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      if (_noShowAppointments > 0)
        PieChartSectionData(
          color: _noShowColor,
          value: _noShowAppointments.toDouble(),
          title: '${((_noShowAppointments / total) * 100).toStringAsFixed(0)}%',
          radius: 35,
          titleStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
        ),
    ];
  }

  Widget _buildEarningsCard() {
    final earnings = _completedAppointments * _pricePerSession;
    final formatter = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final shortPriceFormatter = NumberFormat.compactCurrency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_primary, Color(0xFF1D35B4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Ganancias (Estimado)', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w500)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('+ ${shortPriceFormatter.format(_pricePerSession)}/cita', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            formatter.format(earnings),
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900, letterSpacing: -1),
          ),
          const SizedBox(height: 4),
          Text(
            'Basado en $_completedAppointments citas a ${formatter.format(_pricePerSession)} c/u',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _KPICard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _KPICard({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF0D1B3E))),
          const SizedBox(height: 4),
          Text(title, style: const TextStyle(fontSize: 13, color: Color(0xFF8A94A6), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final String label;
  final Color color;
  const _LegendItem(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF8A94A6), fontWeight: FontWeight.w600)),
      ],
    );
  }
}
