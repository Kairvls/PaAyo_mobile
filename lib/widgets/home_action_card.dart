import 'package:flutter/material.dart';

class HomeActionCard extends StatelessWidget {
  final String image;
  final String title;
  final String description;
  final VoidCallback onTap;

  const HomeActionCard({
    super.key,
    required this.image,
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,

      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,

        child: Ink(
          padding: const EdgeInsets.all(22),

          decoration: BoxDecoration(
            color: Colors.white,

            borderRadius: BorderRadius.circular(24),

            border: Border.all(
              color: const Color(0xffE2E8F0),
            ),

            boxShadow: const [
              BoxShadow(
                color: Color.fromRGBO(
                  15,
                  23,
                  42,
                  .05,
                ),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),

          child: Column(
            children: [

              /// ======================
              /// TOP ROW
              /// ======================

              Row(
                children: [

                  Container(
                    width: 54,
                    height: 54,

                    decoration: BoxDecoration(
                      color: const Color(0xffF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                    ),

                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Image.asset(image),
                    ),
                  ),

                  const SizedBox(width: 16),

                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xff0F172A),
                      ),
                    ),
                  ),

                  Container(
                    width: 42,
                    height: 42,

                    decoration: BoxDecoration(
                      color: const Color(0xffEFF6FF),
                      borderRadius: BorderRadius.circular(14),
                    ),

                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Color(0xff2563EB),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              /// ======================
              /// DESCRIPTION
              /// ======================

              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  description,
                  style: const TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: Color(0xff64748B),
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