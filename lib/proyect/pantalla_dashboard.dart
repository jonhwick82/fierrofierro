import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
///import 'package:intl/intl.dart';

/// Un modelo simple para agrupar las estadísticas calculadas.
class DashboardStats {
  final int totalReservasMes;
  final double ocupacionPromedio;
  final String canchaMasUtilizada;
  final String horarioMasDemandado;
  final Map<int, int> ocupacionSemanal;
  final Map<String, int> usoPorCancha;

  DashboardStats({
    required this.totalReservasMes,
    required this.ocupacionPromedio,
    required this.canchaMasUtilizada,
    required this.horarioMasDemandado,
    required this.ocupacionSemanal,
    required this.usoPorCancha,
  });
}

class PantallaDashboard extends StatefulWidget {
  const PantallaDashboard({super.key});

  @override
  State<PantallaDashboard> createState() => _PantallaDashboardState();
}

class _PantallaDashboardState extends State<PantallaDashboard> {
  late Future<DashboardStats> _statsFuture;

  // Estas listas deben ser consistentes con las usadas en la pantalla de reservas.
  final List<String> todosLosHorarios = [
    '09:00', '10:00', '11:00', '12:00', '13:00', '14:00', '15:00',
    '16:00', '17:00', '18:00', '19:00', '20:00', '21:00', '22:00'
  ];
  final List<String> todasLasCanchas = [
    'Cancha 1 - Fútbol 5', 'Cancha 2 - Fútbol 8', 'Cancha 3 - Fútbol 11'
  ];

  @override
  void initState() {
    super.initState();
    _statsFuture = _calcularEstadisticas();
  }

  /// Obtiene todas las reservas y calcula las estadísticas necesarias para el dashboard.
  Future<DashboardStats> _calcularEstadisticas() async {
    // Obtener todas las reservas. En una app real, esto podría paginarse o limitarse por fecha.
    final snapshot = await FirebaseFirestore.instance.collection('reservas').get();
    final reservas = snapshot.docs;

    final ahora = DateTime.now();

    // --- 1. Estadísticas del mes actual ---
    final reservasDelMes = reservas.where((doc) {
      final fecha = (doc['fecha'] as Timestamp).toDate();
      return fecha.year == ahora.year && fecha.month == ahora.month;
    }).toList();

    // --- 2. Ocupación semanal (últimos 7 días) ---
    final Map<int, int> ocupacionSemanal = { for (var i = 0; i < 7; i++) DateTime.now().subtract(Duration(days: i)).weekday: 0 };
    final hace7Dias = ahora.subtract(const Duration(days: 7));
    
    reservas.where((doc) {
      final fecha = (doc['fecha'] as Timestamp).toDate();
      return fecha.isAfter(hace7Dias);
    }).forEach((doc) {
      final fecha = (doc['fecha'] as Timestamp).toDate();
      ocupacionSemanal.update(fecha.weekday, (value) => value + 1, ifAbsent: () => 1);
    });

    // --- 3. Uso por Cancha y Cancha más utilizada ---
    final Map<String, int> usoPorCancha = {};
    for (var doc in reservasDelMes) {
      final cancha = doc['cancha'] as String;
      usoPorCancha.update(cancha, (value) => value + 1, ifAbsent: () => 1);
    }
    String canchaMasUtilizada = "N/A";
    if (usoPorCancha.isNotEmpty) {
      canchaMasUtilizada = usoPorCancha.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    }

    // --- 4. Horarios más demandados ---
    final Map<String, int> usoPorHorario = {};
    for (var doc in reservasDelMes) {
      final hora = doc['hora'] as String;
      usoPorHorario.update(hora, (value) => value + 1, ifAbsent: () => 1);
    }
    String horarioMasDemandado = "N/A";
    if (usoPorHorario.isNotEmpty) {
      horarioMasDemandado = usoPorHorario.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    }

    // --- 5. Porcentaje de ocupación promedio del mes ---
    final diasEnMes = DateTime(ahora.year, ahora.month + 1, 0).day;
    final totalSlotsDisponibles = todasLasCanchas.length * todosLosHorarios.length * diasEnMes;
    final double ocupacionPromedio = totalSlotsDisponibles > 0 ? (reservasDelMes.length / totalSlotsDisponibles) * 100 : 0.0;

    return DashboardStats(
      totalReservasMes: reservasDelMes.length,
      ocupacionPromedio: ocupacionPromedio,
      canchaMasUtilizada: canchaMasUtilizada,
      horarioMasDemandado: '$horarioMasDemandado hs',
      ocupacionSemanal: ocupacionSemanal,
      usoPorCancha: usoPorCancha,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard Administrador'),
        backgroundColor: const Color(0xFF1B5E20),
      ),
      body: FutureBuilder<DashboardStats>(
        future: _statsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar datos: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('No hay datos disponibles.'));
          }

          final stats = snapshot.data!;

          return RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _statsFuture = _calcularEstadisticas();
              });
            },
            child: ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildResumenCard(stats),
                const SizedBox(height: 24),
                _buildGraficoOcupacionSemanal(stats.ocupacionSemanal),
                const SizedBox(height: 24),
                _buildGraficoUsoCanchas(stats.usoPorCancha),
              ],
            ),
          );
        },
      ),
    );
  }

  /// Widget para el cuadro resumen con métricas clave.
  Widget _buildResumenCard(DashboardStats stats) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resumen del Mes',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 2.2,
              children: [
                _buildStatItem('Reservas Totales', stats.totalReservasMes.toString(), Icons.event_available),
                _buildStatItem('Ocupación Promedio', '${stats.ocupacionPromedio.toStringAsFixed(1)}%', Icons.pie_chart),
                _buildStatItem('Cancha Más Usada', stats.canchaMasUtilizada, Icons.sports_soccer),
                _buildStatItem('Horario Pico', stats.horarioMasDemandado, Icons.access_time),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Widget para un item individual del cuadro resumen.
  Widget _buildStatItem(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: const Color(0xFF1B5E20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  /// Widget para el gráfico de barras de ocupación semanal.
  Widget _buildGraficoOcupacionSemanal(Map<int, int> data) {
    // Mapea el número del día de la semana a su abreviatura en español.
    final Map<int, String> diasSemana = {
      1: 'Lun', 2: 'Mar', 3: 'Mié', 4: 'Jue', 5: 'Vie', 6: 'Sáb', 7: 'Dom'
    };

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ocupación Semanal (Últimos 7 días)',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  barGroups: data.entries.map((entry) {
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: entry.value.toDouble(),
                          color: const Color(0xFF1B5E20),
                          width: 16,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(diasSemana[value.toInt()] ?? ''),
                          );
                        },
                        reservedSize: 30,
                      ),
                    ),
                    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Widget para el gráfico circular de uso por cancha.
  Widget _buildGraficoUsoCanchas(Map<String, int> data) {
    final total = data.values.fold(0, (sum, item) => sum + item);
    final List<Color> chartColors = [
      Colors.green.shade800,
      Colors.orange.shade700,
      Colors.blue.shade700,
    ];

    // Si no hay datos, muestra un mensaje.
    if (data.isEmpty) {
      return Card(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const SizedBox(
          height: 250,
          child: Center(child: Text('No hay datos de uso de canchas este mes.')),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Uso por Cancha (Mes Actual)',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: data.entries.map((entry) {
                    final index = data.keys.toList().indexOf(entry.key);
                    final percentage = total > 0 ? (entry.value / total) * 100 : 0;
                    return PieChartSectionData(
                      color: chartColors[index % chartColors.length],
                      value: entry.value.toDouble(),
                      title: '${percentage.toStringAsFixed(1)}%',
                      radius: 80,
                      titleStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    );
                  }).toList(),
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Leyenda del gráfico
            Wrap(
              spacing: 16,
              children: data.keys.map((key) {
                final index = data.keys.toList().indexOf(key);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 16, height: 16, color: chartColors[index % chartColors.length]),
                    const SizedBox(width: 8),
                    Text(key),
                  ],
                );
              }).toList(),
            )
          ],
        ),
      ),
    );
  }
}