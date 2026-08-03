import 'package:flutter/material.dart';

import '../../widgets/home_action_card.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 18,
          ),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              // ==========================
              // HEADER
              // ==========================

              const SizedBox(height: 8),

              Center(
                child: Image.asset(
                  "assets/images/paayo_logo.png",
                  width: 205,
                ),
              ),

              const SizedBox(height: 6),

              const Center(
                child: Text(
                  "Report & Maintenance Monitoring",
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    color: Color(0xff64748B),
                    letterSpacing: .2,
                  ),
                ),
              ),

              const SizedBox(height: 28),

              // ==========================
              // REPORT CARD
              // ==========================

              HomeActionCard(
                image: "assets/images/report.png",
                title: "Submit Report",
                description:
                    "Report broken or faulty equipment to request repairs or replacements.",
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    "/report",
                  );
                },
              ),

              const SizedBox(height: 18),

              // ==========================
              // QR CARD
              // ==========================

              HomeActionCard(
                image: "assets/images/scan.png",
                title: "Manage Equipment",
                description:
                    "Track and monitor maintenance using QR codes.",
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    "/scanner",
                  );
                },
              ),

              const SizedBox(height: 30),

              const Center(
                child: Text(
                  "STI College Ormoc",
                  style: TextStyle(
                    fontSize: 13,
                    letterSpacing: 1,
                    color: Color(0xff94A3B8),
                  ),
                ),
              ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}