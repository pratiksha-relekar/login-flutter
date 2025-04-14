import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

class ReportPage extends StatefulWidget {
  const ReportPage({Key? key}) : super(key: key);

  @override
  State<ReportPage> createState() => _ReportPageState();
}

class _ReportPageState extends State<ReportPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool isLoading = true;
  Map<String, double> monthlyIncome = {};
  Map<String, double> monthlyExpenses = {};
  double totalIncome = 0;
  double totalExpenses = 0;

  final NumberFormat rupeesFormat = NumberFormat.currency(
    symbol: '₹',
    locale: 'hi_IN',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // Load income data
      final incomeQuery = await _firestore
          .collection('incomes')
          .where('userId', isEqualTo: user.uid)
          .get();

      // Load expense data
      final expenseQuery = await _firestore
          .collection('expenses')
          .where('userId', isEqualTo: user.uid)
          .get();

      Map<String, double> incomeByMonth = {};
      Map<String, double> expensesByMonth = {};
      double incomeTotal = 0;
      double expenseTotal = 0;

      // Process income data
      for (var doc in incomeQuery.docs) {
        double amount = (doc.data()['amount'] as num).toDouble();
        DateTime date = (doc.data()['date'] as Timestamp).toDate();
        String monthYear = DateFormat('MMM yyyy').format(date);
        
        incomeByMonth[monthYear] = (incomeByMonth[monthYear] ?? 0) + amount;
        incomeTotal += amount;
      }

      // Process expense data
      for (var doc in expenseQuery.docs) {
        double amount = (doc.data()['amount'] as num).toDouble();
        DateTime date = (doc.data()['date'] as Timestamp).toDate();
        String monthYear = DateFormat('MMM yyyy').format(date);
        
        expensesByMonth[monthYear] = (expensesByMonth[monthYear] ?? 0) + amount;
        expenseTotal += amount;
      }

      setState(() {
        monthlyIncome = incomeByMonth;
        monthlyExpenses = expensesByMonth;
        totalIncome = incomeTotal;
        totalExpenses = expenseTotal;
        isLoading = false;
      });
    } catch (e) {
      print('Error loading report data: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget _buildComparativeChart() {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Income vs Expenses",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: totalIncome > totalExpenses ? totalIncome * 1.2 : totalExpenses * 1.2,
                barTouchData: BarTouchData(enabled: false),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            value == 0 ? 'Income' : 'Expenses',
                            style: const TextStyle(fontSize: 12),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          rupeesFormat.format(value),
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                      reservedSize: 60,
                    ),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(show: false),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(
                        toY: totalIncome,
                        color: Colors.green,
                        width: 20,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: [
                      BarChartRodData(
                        toY: totalExpenses,
                        color: Colors.red,
                        width: 20,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyTrendsChart() {
    // Get all months sorted
    Set<String> allMonths = {...monthlyIncome.keys, ...monthlyExpenses.keys};
    List<String> sortedMonths = allMonths.toList()
      ..sort((a, b) => DateFormat('MMM yyyy').parse(a).compareTo(
          DateFormat('MMM yyyy').parse(b)));

    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Monthly Trends",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 && value.toInt() < sortedMonths.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: RotatedBox(
                              quarterTurns: 1,
                              child: Text(
                                sortedMonths[value.toInt()],
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                      reservedSize: 30,
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          rupeesFormat.format(value),
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                      reservedSize: 60,
                    ),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  // Income line
                  LineChartBarData(
                    spots: List.generate(sortedMonths.length, (index) {
                      return FlSpot(
                        index.toDouble(),
                        monthlyIncome[sortedMonths[index]] ?? 0,
                      );
                    }),
                    isCurved: true,
                    color: Colors.green,
                    barWidth: 3,
                    dotData: FlDotData(show: false),
                  ),
                  // Expense line
                  LineChartBarData(
                    spots: List.generate(sortedMonths.length, (index) {
                      return FlSpot(
                        index.toDouble(),
                        monthlyExpenses[sortedMonths[index]] ?? 0,
                      );
                    }),
                    isCurved: true,
                    color: Colors.red,
                    barWidth: 3,
                    dotData: FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('Income'),
                ],
              ),
              const SizedBox(width: 16),
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('Expenses'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadReportData,
                child: CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      expandedHeight: 120,
                      pinned: true,
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                        onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
                      ),
                      flexibleSpace: FlexibleSpaceBar(
                        title: const Text(
                          'Financial Reports & Insights',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        background: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Theme.of(context).primaryColor,
                                Theme.of(context).primaryColor.withOpacity(0.7),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            _buildComparativeChart(),
                            const SizedBox(height: 24),
                            _buildMonthlyTrendsChart(),
                          ],
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