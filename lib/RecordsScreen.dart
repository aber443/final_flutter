import 'package:flutter/material.dart';

import 'GlucoseRecordsScreen.dart';
import 'MealRecordsScreen.dart';
import 'ActivityRecordsScreen.dart';
import 'MedicationRecordsScreen.dart';
import 'MedicalExamRecordsScreen.dart';

class RecordsScreen extends StatelessWidget {
  const RecordsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final bool isDark =
        theme.brightness == Brightness.dark;

    final Color primaryColor = theme.primaryColor;

    final Color textColor = isDark
        ? Colors.white
        : const Color(0xff2C4A5A);

    final Color secondaryTextColor = isDark
        ? Colors.white.withOpacity(0.60)
        : const Color(0xff78909A);

    return Scaffold(
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double width = constraints.maxWidth;

              final bool isVerySmall = width < 390;
              final bool isTablet = width >= 600;

              final double horizontalPadding = isVerySmall
                  ? 14
                  : isTablet
                  ? 36
                  : 20;

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 18,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 760,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 48,
                          child: Center(
                            child: Text(
                              'السجلات',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: isTablet ? 31 : 27,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                          ),
                          child: Text(
                            'عرض ومتابعة السجلات السابقة',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: secondaryTextColor,
                            ),
                          ),
                        ),

                        const SizedBox(height: 26),

                        // قراءات السكر
                        _recordCard(
                          context,
                          icon: Icons.water_drop_rounded,
                          title: 'قراءات السكر',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                const GlucoseRecordsScreen(),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 12),

                        // الوجبات
                        _recordCard(
                          context,
                          icon: Icons.restaurant_rounded,
                          title: 'الوجبات',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                const MealRecordsScreen(),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 12),

                        // الأنشطة
                        _recordCard(
                          context,
                          icon: Icons.directions_run_rounded,
                          title: 'الأنشطة',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                const ActivityRecordsScreen(),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 12),

                        // الأدوية
                        _recordCard(
                          context,
                          icon: Icons.medication_rounded,
                          title: 'الأدوية',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                const MedicationRecordsScreen(),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 12),

                        // الفحوصات الطبية
                        _recordCard(
                          context,
                          icon: Icons.health_and_safety_rounded,
                          title: 'الفحوصات',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                const MedicalExamRecordsScreen(),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // بطاقة السجل
  Widget _recordCard(
      BuildContext context, {
        required IconData icon,
        required String title,
        required VoidCallback onTap,
      }) {
    final ThemeData theme = Theme.of(context);

    final bool isDark =
        theme.brightness == Brightness.dark;

    final Color primaryColor = theme.primaryColor;

    final Color textColor = isDark
        ? Colors.white
        : const Color(0xff2C4A5A);

    final Color secondaryTextColor = isDark
        ? Colors.white.withOpacity(0.60)
        : const Color(0xff78909A);

    final Color cardColor = isDark
        ? const Color(0xff1D292D)
        : Colors.white;

    final Color borderColor = isDark
        ? Colors.white.withOpacity(0.12)
        : const Color(0xffE2EEEE);

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: borderColor,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(
                    isDark ? 0.14 : 0.10,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: primaryColor,
                  size: 24,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),


                  ],
                ),
              ),

              const SizedBox(width: 10),

              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: textColor.withOpacity(0.40),
              ),
            ],
          ),
        ),
      ),
    );
  }
}