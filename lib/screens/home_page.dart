import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../widgets/navigation/bottom_navbar.dart';
import 'income_page.dart'; // Make sure this import is present
import 'expense_page.dart'; // Add this import
import 'savings_page.dart';
import 'report_page.dart'; 
import 'settings_page.dart';// Add this import

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeInAnimation;
  late Animation<Offset> _slideAnimation;
  
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  double totalIncome = 0.0;
  double totalExpenses = 0.0;
  double remainingBalance = 0.0;
  List<Map<String, dynamic>> recentTransactions = [];
  bool isLoading = true;
  String userName = "";

  // Pages placeholder
  final List<Widget> _pages = [
    Container(), // Current page (will be replaced with content)
    const Scaffold(body: Center(child: Text('Income Page'))),
    const Scaffold(body: Center(child: Text('Expenses Page'))),
    const Scaffold(body: Center(child: Text('Savings Page'))),
    const ReportPage(),
  const SettingsPage(), 
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    
    _fadeInAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    
    // Check if user is logged in
    FirebaseAuth.instance.authStateChanges().listen((User? user) {
      if (user == null && mounted) {
        Navigator.pushReplacementNamed(context, '/');
      }
    });
    
    _loadUserData();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    setState(() {
      isLoading = true;
    });

    try {
      // Get current user
      final User? user = _auth.currentUser;
      if (user != null) {
        // Get user details
        final userDoc = await _firestore.collection('users').doc(user.email).get();
        if (userDoc.exists) {
          userName = userDoc.data()?['name'] ?? 'User';
        }
        
        // Calculate total income
        final incomeQuery = await _firestore
            .collection('incomes')
            .where('userId', isEqualTo: user.uid)
            .get();
        
        totalIncome = 0;
        for (var doc in incomeQuery.docs) {
          totalIncome += (doc.data()['amount'] as num).toDouble();
        }
        
        // Calculate total expenses
        final expenseQuery = await _firestore
            .collection('expenses')
            .where('userId', isEqualTo: user.uid)
            .get();
        
        totalExpenses = 0;
        for (var doc in expenseQuery.docs) {
          totalExpenses += (doc.data()['amount'] as num).toDouble();
        }
        
        // Calculate remaining balance
        remainingBalance = totalIncome - totalExpenses;
        
        // Get recent transactions
        recentTransactions = [];
        
        // Add income transactions
        for (var doc in incomeQuery.docs) {
          recentTransactions.add({
            'id': doc.id,
            'amount': (doc.data()['amount'] as num).toDouble(),
            'description': doc.data()['description'] as String,
            'date': (doc.data()['date'] as Timestamp).toDate(),
            'type': 'income',
            'category': doc.data()['category'] as String,
          });
        }
        
        // Add expense transactions
        for (var doc in expenseQuery.docs) {
          recentTransactions.add({
            'id': doc.id,
            'amount': (doc.data()['amount'] as num).toDouble(),
            'description': doc.data()['description'] as String,
            'date': (doc.data()['date'] as Timestamp).toDate(),
            'type': 'expense',
            'category': doc.data()['category'] as String,
          });
        }
        
        // Sort by date (most recent first)
        recentTransactions.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));
        
        // Take only most recent 5
        if (recentTransactions.length > 5) {
          recentTransactions = recentTransactions.sublist(0, 5);
        }
      }
    } catch (e) {
      print("Error loading data: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _getPage(_currentIndex),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
    );
  }
Widget _getPage(int index) {
  switch (index) {
    case 0:
      return _buildHomePage();
    case 1:
      return const IncomePage();
    case 2:
      return const ExpensePage();
    case 3:
      return const SavingsPage();
    case 4:
      return const ReportPage();
    case 5:
      return const SettingsPage();
    default:
      return _buildHomePage();
  }
}

  Widget _buildHomePage() {
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUserData,
              child: CustomScrollView(
                slivers: [
                  SliverAppBar(
                    expandedHeight: 120.0,
                    floating: false,
                    pinned: true,
                    flexibleSpace: FlexibleSpaceBar(
                      title: Text(
                        "Hello, ${userName.split(' ')[0]}!",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      background: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Theme.of(context).primaryColor,
                              Theme.of(context).primaryColor.withOpacity(0.8),
                            ],
                          ),
                        ),
                      ),
                    ),
                    actions: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white),
                        onPressed: _loadUserData,
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout, color: Colors.white),
                        onPressed: () async {
                          await _auth.signOut();
                          if (mounted) {
                            Navigator.pushReplacementNamed(context, '/');
                          }
                        },
                      ),
                    ],
                  ),
                  SliverToBoxAdapter(
                    child: FadeTransition(
                      opacity: _fadeInAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Balance Overview",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildBalanceOverview(),
                              const SizedBox(height: 24),
                              
                              const Text(
                                "Quick Actions",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildQuickActions(),
                              const SizedBox(height: 24),
                              
                              const Text(
                                "Visual Insights",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildPieChart(),
                              const SizedBox(height: 24),
                              
                              const Text(
                                "Recent Transactions",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),
                              _buildRecentTransactions(),
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildBalanceOverview() {
    return Container(
      decoration: BoxDecoration(
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
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColor.withOpacity(0.8),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Remaining Balance",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  NumberFormat.currency(
                    symbol: '₹',
                    locale: 'hi_IN',
                    decimalDigits: 2,
                  ).format(remainingBalance),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Income",
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        NumberFormat.currency(
                          symbol: '₹',
                          locale: 'hi_IN',
                          decimalDigits: 2,
                        ).format(totalIncome),
                        style: TextStyle(
                          color: Colors.green.shade600,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 40,
                  width: 1,
                  color: Colors.grey.withOpacity(0.3),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Expenses",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          NumberFormat.currency(
                            symbol: '₹',
                            locale: 'hi_IN',
                            decimalDigits: 2,
                          ).format(totalExpenses),
                          style: TextStyle(
                            color: Colors.red.shade600,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () {
              setState(() {
                _currentIndex = 1;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline, 
                      color: Colors.green.shade600, size: 36),
                  const SizedBox(height: 8),
                  Text(
                    "Add Income",
                    style: TextStyle(
                      color: Colors.green.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: InkWell(
            onTap: () {
              setState(() {
                _currentIndex = 2;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.remove_circle_outline, 
                      color: Colors.red.shade600, size: 36),
                  const SizedBox(height: 8),
                  Text(
                    "Add Expense",
                    style: TextStyle(
                      color: Colors.red.shade600,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPieChart() {
    return Container(
      height: 250,
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
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: PieChart(
              PieChartData(
                sectionsSpace: 0,
                centerSpaceRadius: 40,
                sections: [
                  PieChartSectionData(
                    color: Colors.green.shade400,
                    value: totalIncome,
                    title: '',
                    radius: 50,
                  ),
                  PieChartSectionData(
                    color: Colors.red.shade400,
                    value: totalExpenses,
                    title: '',
                    radius: 50,
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.green.shade400,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "Income",
                      style: TextStyle(
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.red.shade400,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "Expenses",
                      style: TextStyle(
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentTransactions() {
    if (recentTransactions.isEmpty) {
      return Center(
        child: Column(
          children: [
            const Icon(Icons.receipt_long, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              "No transactions yet",
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {},
              child: const Text("Add Transaction"),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: recentTransactions.length,
      itemBuilder: (context, index) {
        final transaction = recentTransactions[index];
        final bool isIncome = transaction['type'] == 'income';
        
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.05),
                spreadRadius: 1,
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isIncome 
                    ? Colors.green.withOpacity(0.1)
                    : Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                color: isIncome ? Colors.green : Colors.red,
              ),
            ),
            title: Text(
              transaction['description'],
              style: const TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Text(
              "${transaction['category']} • ${DateFormat.yMMMd().format(transaction['date'])}",
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
            trailing: Text(
              NumberFormat.currency(
                symbol: '₹',
                locale: 'hi_IN',
                decimalDigits: 2,
              ).format(transaction['amount']),
              style: TextStyle(
                color: isIncome ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        );
      },
    );
  }
} 