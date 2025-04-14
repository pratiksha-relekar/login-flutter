import 'package:flutter/material.dart';
import 'package:login/screens/home_page.dart';
import 'package:login/screens/income_page.dart';
import 'package:login/screens/expense_page.dart';
import 'package:login/screens/savings_page.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavBar({
    Key? key,
    required this.currentIndex,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onTap,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Theme.of(context).primaryColor,
      unselectedItemColor: Colors.grey,
      // In lib/widgets/bottom_navbar.dart
items: const [
  BottomNavigationBarItem(
    icon: Icon(Icons.home),
    label: 'Home',
  ),
  BottomNavigationBarItem(
    icon: Icon(Icons.currency_rupee),
    label: 'Income',
  ),
  BottomNavigationBarItem(
    icon: Icon(Icons.account_balance_wallet),
    label: 'Expense',
  ),
  BottomNavigationBarItem(
    icon: Icon(Icons.savings),
    label: 'Savings',
  ),
  BottomNavigationBarItem(
    icon: Icon(Icons.bar_chart),
    label: 'Reports',
  ),
  BottomNavigationBarItem(
    icon: Icon(Icons.settings_outlined),
    activeIcon: Icon(Icons.settings),
    label: 'Settings',
  ),
],
    );
  }
} 