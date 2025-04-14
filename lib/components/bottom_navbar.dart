import 'package:flutter/material.dart';

class FloatingBottomNavbar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  FloatingBottomNavbar({required this.currentIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(40.0), // Rounded top-left
          topRight: Radius.circular(40.0), // Rounded top-right
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, -5),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(40.0),
          topRight: Radius.circular(40.0),
        ),
        child: BottomNavigationBar(
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.report_problem),
              label: "Lapor Kejadian",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: "Beranda",
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.report_gmailerrorred),
              label: "Lapor Kekerasan Seksual",
            ),
          ],
          currentIndex: currentIndex,
          onTap: onTap,
          selectedItemColor: Colors.blue, // Color for the selected item
          unselectedItemColor: Colors.grey, // Color for unselected items
          backgroundColor:
              Colors.white, // Background color of the navigation bar
        ),
      ),
    );
  }
}
