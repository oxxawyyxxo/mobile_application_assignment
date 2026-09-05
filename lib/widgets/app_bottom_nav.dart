import 'package:flutter/material.dart';
import 'package:mobile_application_assignment/screens/buy_sell_screen.dart';
import '../screens/stock_chart_screen.dart';
import '../screens/topup_screen.dart';
import '../screens/portfolio_screen.dart';

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final VoidCallback? onTrade;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    this.onTrade,
  });

  void _onTap(BuildContext context, int index) {
    if (index == 2 && onTrade != null) {
      onTrade!();
      return;
    }

    if (index == currentIndex) return;

    Widget target;
    switch (index) {
      case 0:
        target = const StockChartScreen();
        break;
      case 1:
        target = const TopUpScreen();
        break;
      case 2:
        target = const BuySellScreen();
        break;
      case 3:
        target = const PortfolioScreen();
        break;
      default:
        return;
    }

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => target),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: currentIndex,
      onTap: (index) => _onTap(context, index),
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.search),
          label: 'Search',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.account_balance_wallet_outlined),
          label: 'Top Up',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.swap_horiz),
          label: 'Trade',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.pie_chart_outline),
          label: 'Portfolio',
        ),
      ],
    );
  }
}