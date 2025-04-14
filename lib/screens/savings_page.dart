import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:percent_indicator/linear_percent_indicator.dart';

class SavingsPage extends StatefulWidget {
  const SavingsPage({Key? key}) : super(key: key);

  @override
  State<SavingsPage> createState() => _SavingsPageState();
}

class _SavingsPageState extends State<SavingsPage> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late AnimationController _animationController;
  
  bool isLoading = true;
  double totalSavings = 0;
  double currentGoalAmount = 0;
  double targetAmount = 0;
  String goalPurpose = '';
  DateTime? targetDate;
  double autoSavePercentage = 0;
  List<Map<String, dynamic>> savingsTransactions = [];
  
  final NumberFormat rupeesFormat = NumberFormat.currency(
    symbol: '₹',
    locale: 'hi_IN',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadSavingsData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadSavingsData() async {
    try {
      setState(() {
        isLoading = true;
      });

      String userId = _auth.currentUser?.uid ?? '';
      
      // Remove orderBy to fix the index error
      QuerySnapshot transactionsSnapshot = await _firestore
          .collection('savings_transactions')
          .where('userId', isEqualTo: userId)
          .get();

      savingsTransactions = transactionsSnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'amount': (data['amount'] is int) 
              ? (data['amount'] as int).toDouble() 
              : data['amount'] ?? 0.0,
          'date': (data['date'] as Timestamp).toDate(),
          'description': data['description'] ?? '',
          'userId': data['userId'] ?? '',
        };
      }).toList();

      // Sort the transactions in memory instead
      savingsTransactions.sort((a, b) => 
        (b['date'] as DateTime).compareTo(a['date'] as DateTime));

      // Calculate total savings
      totalSavings = savingsTransactions.fold(
        0, (sum, transaction) => sum + (transaction['amount'] as num));
      currentGoalAmount = totalSavings;

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      _showErrorSnackBar('Error loading savings data: $e');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSetGoalModal() {
    final TextEditingController amountController = TextEditingController(
      text: targetAmount > 0 ? targetAmount.toString() : ''
    );
    final TextEditingController purposeController = TextEditingController(
      text: goalPurpose
    );
    DateTime selectedDate = targetDate ?? DateTime.now().add(const Duration(days: 30));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Set Savings Goal',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: 'Target Amount (₹)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.currency_rupee),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: purposeController,
                      decoration: InputDecoration(
                        labelText: 'Purpose',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.category),
                      ),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (picked != null) {
                          setModalState(() {
                            selectedDate = picked;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.calendar_today),
                            const SizedBox(width: 8),
                            Text(
                              'Target Date: ${DateFormat('dd MMM, yyyy').format(selectedDate)}',
                              style: TextStyle(fontSize: 16),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Auto-Save Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Slider(
                      value: autoSavePercentage,
                      min: 0,
                      max: 50,
                      divisions: 50,
                      label: '${autoSavePercentage.round()}%',
                      onChanged: (value) {
                        setModalState(() {
                          autoSavePercentage = value;
                        });
                      },
                    ),
                    Text(
                      'Auto-save ${autoSavePercentage.round()}% of income',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (amountController.text.isEmpty) {
                            _showErrorSnackBar('Please enter a target amount');
                            return;
                          }
                          double amount = double.tryParse(amountController.text) ?? 0;
                          if (amount <= 0) {
                            _showErrorSnackBar('Please enter a valid amount');
                            return;
                          }
                          _saveGoal(
                            amount,
                            purposeController.text,
                            selectedDate,
                            autoSavePercentage,
                          );
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: const Text(
                          'Save Goal',
                          style: TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveGoal(
    double amount,
    String purpose,
    DateTime date,
    double autoSave,
  ) async {
    try {
      String userId = _auth.currentUser?.uid ?? '';
      await _firestore.collection('savings_goals').doc(userId).set({
        'targetAmount': amount,
        'purpose': purpose,
        'targetDate': date,
        'autoSavePercentage': autoSave,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      setState(() {
        targetAmount = amount;
        goalPurpose = purpose;
        targetDate = date;
        autoSavePercentage = autoSave;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Savings goal updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showErrorSnackBar('Error saving goal: $e');
    }
  }

  void _showAddSavingsModal() {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Savings',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Amount (₹)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.currency_rupee),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (amountController.text.isEmpty) {
                      _showErrorSnackBar('Please enter an amount');
                      return;
                    }
                    double amount = double.tryParse(amountController.text) ?? 0;
                    if (amount <= 0) {
                      _showErrorSnackBar('Please enter a valid amount');
                      return;
                    }
                    _addSavings(amount, descriptionController.text);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text(
                    'Add Savings',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _addSavings(double amount, String description) async {
    try {
      String userId = _auth.currentUser?.uid ?? '';
      await _firestore.collection('savings_transactions').add({
        'userId': userId,
        'amount': amount,
        'description': description,
        'date': Timestamp.now(), // Store as Timestamp directly
      });

      await _loadSavingsData();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Savings added successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      _showErrorSnackBar('Error adding savings: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadSavingsData,
                child: CustomScrollView(
                  slivers: [
                    SliverAppBar(
                      expandedHeight: 150,
                      pinned: true,
                      leading: IconButton(
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                        onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
                      ),
                      flexibleSpace: FlexibleSpaceBar(
                        title: const Text(
                          'Savings',
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
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.refresh, color: Colors.white),
                          onPressed: _loadSavingsData,
                        ),
                        IconButton(
                          icon: const Icon(Icons.flag, color: Colors.white),
                          onPressed: _showSetGoalModal,
                        ),
                      ],
                    ),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Card(
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Theme.of(context).primaryColor,
                                      Theme.of(context).primaryColor.withOpacity(0.7),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Total Savings",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      rupeesFormat.format(totalSavings),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 32,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    if (targetAmount > 0) ...[
                                      const SizedBox(height: 16),
                                      LinearPercentIndicator(
                                        animation: true,
                                        lineHeight: 20.0,
                                        animationDuration: 1000,
                                        percent: (totalSavings / targetAmount).clamp(0.0, 1.0),
                                        center: Text(
                                          "${((totalSavings / targetAmount) * 100).toStringAsFixed(1)}%",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        barRadius: const Radius.circular(10),
                                        progressColor: Colors.white,
                                        backgroundColor: Colors.white.withOpacity(0.3),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        "Goal: ${rupeesFormat.format(targetAmount)} for $goalPurpose",
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (targetDate != null)
                                        Text(
                                          "Target Date: ${DateFormat('dd MMM, yyyy').format(targetDate!)}",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                        ),
                                    ],
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: _showAddSavingsModal,
                                        icon: const Icon(Icons.add),
                                        label: const Text("Add Savings"),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: Theme.of(context).primaryColor,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          padding: const EdgeInsets.symmetric(vertical: 12),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            const Text(
                              "Recent Transactions",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (savingsTransactions.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(height: 40),
                                  Icon(
                                    Icons.savings_outlined,
                                    size: 70,
                                    color: Colors.grey.shade300,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    "No savings transactions yet",
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                ],
                              ),
                            );
                          }

                          final transaction = savingsTransactions[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListTile(
                                leading: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  child: Icon(
                                    Icons.savings,
                                    color: Theme.of(context).primaryColor,
                                  ),
                                ),
                                title: Text(
                                  transaction['description'] ?? 'Savings Deposit',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  DateFormat('dd MMM, yyyy hh:mm a').format(transaction['date']),
                                ),
                                trailing: Text(
                                  rupeesFormat.format(transaction['amount']),
                                  style: TextStyle(
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: savingsTransactions.isEmpty ? 1 : savingsTransactions.length,
                      ),
                    ),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddSavingsModal,
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
} 