import 'package:flutter/material.dart';
import 'ChildStore.dart';
import 'ReportGenerationScreen.dart';
import 'SavedReportsScreen.dart';

class ReportsScreen extends StatelessWidget {
  final String childName;

  // نحتفظ بهذه المعاملات للتوافق مع الملفات الأخرى
  final DateTime birthDate;
  final String gender;
  final String? childImagePath;

  const ReportsScreen({
    super.key,
    required this.childName,
    required this.birthDate,
    required this.gender,
    this.childImagePath,
  });

  @override
  Widget build(BuildContext context) {

    // الحصول على معرف الطفل الحقيقي من ChildStore
    final int? childId =
        ChildStore.instance.selectedChild?.id;

    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color primaryColor = theme.primaryColor;

    final Color textColor =
    isDark ? Colors.white : const Color(0xff2C4A5A);

    final Color secondaryTextColor = isDark
        ? Colors.white.withOpacity(0.60)
        : const Color(0xff78909A);

    final Color cardColor =
    isDark ? const Color(0xff1D292D) : Colors.white;

    final Color borderColor = isDark
        ? Colors.white.withOpacity(0.12)
        : const Color(0xffE2EEEE);

    // التحقق من معرف الطفل قبل فتح أي تقرير
    void openReportScreen(Widget screen) {
      if (childId == null || childId <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تعذر تحديد الطفل. يرجى اختيار الطفل أولاً.',
            ),
          ),
        );
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => screen,
        ),
      );
    }

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
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [

                        // =====================================
                        // Header
                        // =====================================

                        SizedBox(
                          height: 48,
                          child: Center(
                            child: Text(
                              'التقارير',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: isTablet ? 31 : 27,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 10),

                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                          ),
                          child: Text(
                            'متابعة وتحليل البيانات الصحية',
                            style: TextStyle(
                              fontSize: 14,
                              color: secondaryTextColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),

                        const SizedBox(height: 26),

                        // =====================================
                        // Reports Overview
                        // =====================================

                        _sectionCard(
                          cardColor: cardColor,
                          borderColor: borderColor,
                          child: Row(
                            children: [
                              _iconContainer(
                                icon: Icons.bar_chart_rounded,
                                primaryColor: primaryColor,
                              ),

                              const SizedBox(width: 14),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'نظرة عامة على التقارير',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),

                                    const SizedBox(height: 7),

                                    Text(
                                      'يمكنك إنشاء ومراجعة تقارير الصحة والمتابعة للطفل.',
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.6,
                                        color: secondaryTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // =====================================
                        // Create Report Button
                        // =====================================

                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              if (childId == null || childId <= 0) {
                                openReportScreen(
                                  const SizedBox.shrink(),
                                );
                                return;
                              }

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      ReportGenerationScreen(
                                        childId: childId,
                                        childName: childName,
                                      ),
                                ),
                              );
                            },

                            icon: const Icon(
                              Icons.add_chart_rounded,
                            ),

                            label: const Text(
                              'إنشاء تقرير',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // =====================================
                        // Saved Reports Button
                        // =====================================

                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: () {
                              if (childId == null ||
                                  childId <= 0) {
                                openReportScreen(
                                  const SizedBox.shrink(),
                                );
                                return;
                              }

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      SavedReportsScreen(
                                        childId: childId,
                                        childName: childName,
                                      ),
                                ),
                              );
                            },

                            icon: const Icon(
                              Icons.folder_open_outlined,
                            ),

                            label: const Text(
                              'عرض التقارير المحفوظة',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 20),
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

  // =====================================
  // Section Card
  // =====================================

  Widget _sectionCard({
    required Color cardColor,
    required Color borderColor,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: child,
    );
  }

  // =====================================
  // Icon Container
  // =====================================

  Widget _iconContainer({
    required IconData icon,
    required Color primaryColor,
  }) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(
        icon,
        color: primaryColor,
        size: 30,
      ),
    );
  }
}