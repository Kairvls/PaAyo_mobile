import 'dart:async';

import 'package:flutter/material.dart';
import '../home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {

    super.initState();

    Timer(

      const Duration(milliseconds: 2500),

      () {

        Navigator.of(context).pushReplacement(

          PageRouteBuilder(

            transitionDuration:

                const Duration(milliseconds: 700),

            pageBuilder:

                (

                  context,

                  animation,

                  secondaryAnimation,

                ) => const HomeScreen(),

            transitionsBuilder:

                (

                  context,

                  animation,

                  secondaryAnimation,

                  child,

                ) {

              return FadeTransition(

                opacity: animation,

                child: child,

              );

            },

          ),

        );

      },

    );

  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: const Color(0xFFF7F9FC),

      body: SafeArea(

        child: Stack(

          children: [

            Center(

              child: Transform.translate(
                offset: const Offset(0, -55),
                child: Column(

                  mainAxisSize: MainAxisSize.min,

                  children: [

                    Image.asset(

                      "assets/images/paayo_logo.png",

                      width: 165,

                    ),

                    Transform.translate(
                      offset: const Offset(0, -40),
                      child: Column(
                        children: [

                          const Text(
                            "Damage Reporting & Maintenance Monitoring",
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xff64748B),
                            ),
                          ),

                          const SizedBox(height: 14),

                          Container(
                            width: 180,
                            height: 6,
                            decoration: BoxDecoration(
                              color: const Color(0xffE2E8F0),
                              borderRadius: BorderRadius.circular(50),
                            ),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(
                                begin: 0,
                                end: 1,
                              ),
                              duration: const Duration(
                                milliseconds: 2500,
                              ),
                              builder: (context, value, child) {

                                return Align(
                                  alignment: Alignment.centerLeft,
                                  child: Container(
                                    width: 180 * value,
                                    decoration: BoxDecoration(
                                      color: const Color(0xff2563EB),
                                      borderRadius: BorderRadius.circular(50),
                                    ),
                                  ),
                                );

                              },
                            ),
                          ),

                        ],
                      ),
                    ),

                  ],

                ),

              ),

            ),

            const Positioned(

              left: 0,

              right: 0,

              bottom: 28,

              child: Text(

                "STI College Ormoc",

                textAlign: TextAlign.center,

                style: TextStyle(

                  fontSize: 13,

                  letterSpacing: 1.2,

                  color: Color(0xff94A3B8),

                ),

              ),

            ),

          ],

        ),

      ),

    );

  }

}