import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class ExpensePage extends StatefulWidget {
  const ExpensePage({Key? key}) : super(key: key);

  @override
  State<ExpensePage> createState() => _ExpensePageState();
}

class _ExpensePageState extends State<ExpensePage> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late AnimationController _animationController;
  
  bool isLoading = true;
  List<Map<String, dynamic>> expenseList = [];
  List<Map<String, dynamic>> filteredExpenseList = [];
  double totalExpense = 0;
  double monthlyBudget = 10000; // Default budget, should be user-configurable
  Map<String, double> categoryExpenses = {};
  String selectedFilter = "All";
  final NumberFormat rupeesFormat = NumberFormat.currency(
    symbol: '₹',
    locale: 'hi_IN',
    decimalDigits: 2,
  );

  final List<String> categories = [
    "All",
    "Food",
    "Rent",
    "Shopping",
    "Transport",
    "Entertainment",
    "Utilities",
    "Healthcare",
    "Education",
    "Others"
  ];

  // Color map for categories
  final Map<String, Color> categoryColors = {
    "Food": Colors.red,
    "Rent": Colors.blue,
    "Shopping": Colors.purple,
    "Transport": Colors.orange,
    "Entertainment": Colors.pink,
    "Utilities": Colors.teal,
    "Healthcare": Colors.green,
    "Education": Colors.indigo,
    "Others": Colors.grey,
  };

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _loadExpenseData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadExpenseData() async {
    try {
      setState(() {
        isLoading = true;
      });

      String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      
      QuerySnapshot querySnapshot = await FirebaseFirestore.instance
          .collection('expenses')
          .where('userId', isEqualTo: userId)
          .get();

      List<Map<String, dynamic>> expenses = querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return {
          'id': doc.id,
          'amount': data['amount'] is int ? (data['amount'] as int).toDouble() : data['amount'] ?? 0.0,
          'category': data['category'] ?? '',
          'date': (data['date'] as Timestamp).toDate(),
          'createdAt': (data['createdAt'] as Timestamp).toDate(),
          'description': data['description'] ?? '',
          'userId': data['userId'] ?? '',
        };
      }).toList();

      // Sort by createdAt timestamp
      expenses.sort((a, b) => (b['createdAt'] as DateTime).compareTo(a['createdAt'] as DateTime));

      // Calculate total expense
      double total = expenses.fold(0, (sum, expense) => sum + (expense['amount'] as double));

      // Calculate category-wise expenses
      Map<String, double> catExpenses = {};
      for (var expense in expenses) {
        String category = expense['category'] as String;
        catExpenses[category] = (catExpenses[category] ?? 0) + (expense['amount'] as double);
      }

      setState(() {
        expenseList = expenses;
        filteredExpenseList = expenses;
        totalExpense = total;
        categoryExpenses = catExpenses;
        isLoading = false;
      });

      // Check for budget alert
      _checkBudgetAlert();

    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading expense data: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _checkBudgetAlert() {
    if (totalExpense > monthlyBudget) {
      // Calculate how much over budget
      double overBudget = totalExpense - monthlyBudget;
      String overBudgetText = rupeesFormat.format(overBudget);
      
      // Show alert
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.red),
                    SizedBox(width: 10),
                    Text('Budget Alert!'),
                  ],
                ),
                content: Text(
                  'You have exceeded your monthly budget by $overBudgetText. Consider reducing your expenses.',
                  style: TextStyle(fontSize: 16),
                ),
                actions: [
                  TextButton(
                    child: Text('OK'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  TextButton(
                    child: Text('Adjust Budget'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      _showBudgetModal();
                    },
                  ),
                ],
              );
            },
          );
        }
      });
    }
  }

  void _showBudgetModal() {
    TextEditingController budgetController = TextEditingController(text: monthlyBudget.toString());
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Set Monthly Budget',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: budgetController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Monthly Budget (₹)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.currency_rupee),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      double newBudget = double.tryParse(budgetController.text) ?? monthlyBudget;
                      setState(() {
                        monthlyBudget = newBudget;
                      });
                      _saveBudget(newBudget);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Save Budget'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveBudget(double budget) async {
    try {
      String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set({
            'monthlyExpenseBudget': budget,
          }, SetOptions(merge: true));
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Budget updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Check budget again
      _checkBudgetAlert();
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving budget: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _filterExpenses(String category) {
    setState(() {
      selectedFilter = category;
      if (category == "All") {
        filteredExpenseList = expenseList;
      } else {
        filteredExpenseList = expenseList
            .where((expense) => expense['category'] == category)
            .toList();
      }
    });
  }

  void _showAddExpenseModal() {
    final TextEditingController amountController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    String selectedCategory = categories[1];
    DateTime selectedDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Container(
                height: MediaQuery.of(context).size.height * 0.75,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Add New Expense',
                          style: TextStyle(
                            fontSize: 20,
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: selectedCategory,
                              icon: const Icon(Icons.arrow_drop_down),
                              items: categories.where((c) => c != "All").map((String category) {
                                return DropdownMenuItem<String>(
                                  value: category,
                                  child: Text(category),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                setModalState(() {
                                  selectedCategory = newValue!;
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: () async {
                            final DateTime? pickedDate = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (pickedDate != null && pickedDate != selectedDate) {
                              setModalState(() {
                                selectedDate = pickedDate;
                              });
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  DateFormat('dd MMMM, yyyy').format(selectedDate),
                                  style: TextStyle(fontSize: 16),
                                ),
                                Icon(Icons.calendar_today),
                              ],
                            ),
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
                          maxLines: 3,
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () {
                              if (amountController.text.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please enter an amount'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              double amount = double.tryParse(amountController.text) ?? 0;
                              if (amount <= 0) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Amount must be greater than zero'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              Map<String, dynamic> expenseData = {
                                'amount': amount,
                                'category': selectedCategory,
                                'date': selectedDate,
                                'description': descriptionController.text,
                              };

                              _addExpense(expenseData);
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 15),
                            ),
                            child: const Text('Add Expense'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _addExpense(Map<String, dynamic> expenseData) async {
    try {
      String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
      
      // Add timestamps and userId
      expenseData['createdAt'] = FieldValue.serverTimestamp();
      expenseData['userId'] = userId;
      
      await FirebaseFirestore.instance
          .collection('expenses')
          .add(expenseData);

      await _loadExpenseData();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Expense added successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding expense: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showEditExpenseModal(Map<String, dynamic> expense) {
    final TextEditingController amountController = TextEditingController(text: expense['amount'].toString());
    final TextEditingController descriptionController = TextEditingController(text: expense['description']);
    String selectedCategory = expense['category'];
    DateTime selectedDate = expense['date'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                  left: 16,
                  right: 16,
                  top: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Edit Expense',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete),
                          color: Colors.red,
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  title: const Text('Delete Expense'),
                                  content: const Text('Are you sure you want to delete this expense?'),
                                  actions: [
                                    TextButton(
                                      child: const Text('Cancel'),
                                      onPressed: () => Navigator.of(context).pop(),
                                    ),
                                    TextButton(
                                      child: const Text(
                                        'Delete',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                      onPressed: () {
                                        Navigator.of(context).pop(); // Close dialog
                                        Navigator.of(context).pop(); // Close modal
                                        _deleteExpense(expense['id']);
                                      },
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                        ),
                      ],
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
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          isExpanded: true,
                          value: selectedCategory,
                          icon: const Icon(Icons.arrow_drop_down),
                          items: categories.where((c) => c != "All").map((String category) {
                            return DropdownMenuItem<String>(
                              value: category,
                              child: Text(category),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            setModalState(() {
                              selectedCategory = newValue!;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    InkWell(
                      onTap: () async {
                        final DateTime? pickedDate = await showDatePicker(
                          context: context,
                          initialDate: selectedDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                        );
                        if (pickedDate != null && pickedDate != selectedDate) {
                          setModalState(() {
                            selectedDate = pickedDate;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('dd MMMM, yyyy').format(selectedDate),
                              style: TextStyle(fontSize: 16),
                            ),
                            Icon(Icons.calendar_today),
                          ],
                        ),
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
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          if (amountController.text.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter an amount'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          double amount = double.tryParse(amountController.text) ?? 0;
                          if (amount <= 0) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Amount must be greater than zero'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          Map<String, dynamic> expenseData = {
                            'amount': amount,
                            'category': selectedCategory,
                            'date': selectedDate,
                            'description': descriptionController.text,
                          };

                          _updateExpense(expense['id'], expenseData);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        child: const Text('Update Expense'),
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

  Future<void> _updateExpense(String expenseId, Map<String, dynamic> expenseData) async {
    try {
      await FirebaseFirestore.instance
          .collection('expenses')
          .doc(expenseId)
          .update(expenseData);

      await _loadExpenseData();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Expense updated successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating expense: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteExpense(String expenseId) async {
    try {
      await FirebaseFirestore.instance
          .collection('expenses')
          .doc(expenseId)
          .delete();

      await _loadExpenseData();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Expense deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting expense: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadExpenseData,
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
                          'Expenses',
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
                          onPressed: _loadExpenseData,
                        ),
                        IconButton(
                          icon: const Icon(Icons.account_balance_wallet, color: Colors.white),
                          onPressed: _showBudgetModal,
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
                                      "Your Total Expenses",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      rupeesFormat.format(totalExpense),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 28,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Text(
                                          "Monthly Budget: ${rupeesFormat.format(monthlyBudget)}",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        totalExpense > monthlyBudget
                                            ? const Icon(
                                                Icons.warning_amber_rounded,
                                                color: Colors.amber,
                                                size: 18,
                                              )
                                            : const Icon(
                                                Icons.check_circle,
                                                color: Colors.green,
                                                size: 18,
                                              ),
                                      ],
                                    ),
                                    const SizedBox(height: 20),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: _showAddExpenseModal,
                                        icon: const Icon(Icons.add),
                                        label: const Text("Add Expense"),
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
                              "Expense Breakdown",
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 290,
                              child: _buildExpenseChart(),
                            ),
                            const SizedBox(height: 24),
                            
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Expense List",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: selectedFilter,
                                      isDense: true,
                                      icon: const Icon(Icons.filter_list, size: 18),
                                      items: categories.map((String category) {
                                        return DropdownMenuItem<String>(
                                          value: category,
                                          child: Text(category),
                                        );
                                      }).toList(),
                                      onChanged: (String? newValue) {
                                        _filterExpenses(newValue!);
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.all(16.0),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (filteredExpenseList.isEmpty) {
                              return Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(height: 40),
                                  Icon(Icons.receipt_long_outlined, size: 70, color: Colors.grey.shade300),
                                  const SizedBox(height: 16),
                                  Text(
                                    selectedFilter == "All" 
                                        ? "No expense transactions yet" 
                                        : "No $selectedFilter expenses yet",
                                    style: TextStyle(color: Colors.grey.shade600),
                                  ),
                                ],
                              );
                            }

                            final expense = filteredExpenseList[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: InkWell(
                                onTap: () => _showEditExpenseModal(expense),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withOpacity(0.1),
                                        spreadRadius: 1,
                                        blurRadius: 5,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: (categoryColors[expense['category']] ?? Colors.grey).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Center(
                                            child: Icon(
                                              _getCategoryIcon(expense['category']),
                                              color: categoryColors[expense['category']] ?? Colors.grey,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                expense['description'] ?? '',
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: (categoryColors[expense['category']] ?? Colors.grey).withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      expense['category'] ?? '',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color: categoryColors[expense['category']] ?? Colors.grey,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Text(
                                                    DateFormat('dd MMM, yyyy').format(expense['date']),
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.grey.shade600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          rupeesFormat.format(expense['amount']),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Theme.of(context).primaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                          childCount: filteredExpenseList.isEmpty ? 1 : filteredExpenseList.length,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddExpenseModal,
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildExpenseChart() {
    if (categoryExpenses.isEmpty) {
      return const Center(child: Text("No expense data available"));
    }
    
    List<PieChartSectionData> sections = [];
    
    categoryExpenses.forEach((category, amount) {
      double percentage = (amount / totalExpense) * 100;
      sections.add(
        PieChartSectionData(
          color: categoryColors[category] ?? Colors.grey,
          value: amount,
          title: '${percentage.toStringAsFixed(0)}%',
          radius: 70,
          titleStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 10,
          ),
        ),
      );
    });
    
    return Container(
      padding: const EdgeInsets.all(12),
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
        children: [
          Expanded(
            flex: 2,
            child: PieChart(
              PieChartData(
                sections: sections,
                sectionsSpace: 1,
                centerSpaceRadius: 20,
                startDegreeOffset: -90,
                borderData: FlBorderData(show: false),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            flex: 1,
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 10.0,
                runSpacing: 6.0,
                alignment: WrapAlignment.center,
                children: categoryExpenses.keys.map((category) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: categoryColors[category] ?? Colors.grey,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$category: ${rupeesFormat.format(categoryExpenses[category])}',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCategoryIcon(String category) {
    // Implementation of _getCategoryIcon method
    // This method should return the appropriate icon for the given category
    // For example, you can use a switch statement to return the correct icon based on the category
    switch (category) {
      case "Food":
        return Icons.fastfood;
      case "Rent":
        return Icons.house;
      case "Shopping":
        return Icons.shopping_cart;
      case "Transport":
        return Icons.directions_car;
      case "Entertainment":
        return Icons.movie;
      case "Utilities":
        return Icons.electric_bolt;
      case "Healthcare":
        return Icons.health_and_safety;
      case "Education":
        return Icons.school;
      default:
        return Icons.category;
    }
  }
} 