import 'package:flutter/material.dart';

class DoctorBottomNav extends StatelessWidget {
  const DoctorBottomNav({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Text(
          'Doctor Home',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
