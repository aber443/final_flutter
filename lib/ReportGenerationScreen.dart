import 'package:flutter/material.dart';

import 'ComprehensiveHealthReportScreen.dart';
import 'services/report_service.dart';

class ReportGenerationScreen extends StatefulWidget {
  final int childId;
  final String childName;

  const ReportGenerationScreen({
    super.key,
    required this.childId,
    required this.childName,
  });

  @override
  State<ReportGenerationScreen> createState() =>
      _ReportGenerationScreenState();
}

class _ReportGenerationScreenState
    extends State<ReportGenerationScreen> {
  DateTime? startDate;
  DateTime? endDate;

  bool isGenerating = false;

  String? startDateError;
  String? endDateError;

  // =====================================
  // Date Formatter
  // =====================================

  String formatDate(DateTime? date) {
    if (date == null) return '';

    final String day =
    date.day.toString().padLeft(2, '0');

    final String month =
    date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  // =====================================
  // Start Date
  // =====================================

  Future<void> selectStartDate() async {
    final DateTime now = DateTime.now();

    final DateTime today =
    DateTime(now.year, now.month, now.day);

    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: startDate ?? today,
      firstDate: DateTime(2020),
      lastDate: today,
      helpText: 'اختاري تاريخ البداية',
      cancelText: 'إلغاء',
      confirmText: 'اختيار',
    );

    if (selectedDate == null || !mounted) return;

    setState(() {
      startDate = selectedDate;
      startDateError = null;

      if (endDate != null &&
          endDate!.isBefore(selectedDate)) {
        endDate = null;
        endDateError = 'اختاري تاريخ النهاية من جديد';
      }
    });
  }

  // =====================================
  // End Date
  // =====================================

  Future<void> selectEndDate() async {
    if (startDate == null) {
      setState(() {
        startDateError = 'اختاري تاريخ البداية أولاً';
      });

      return;
    }

    final DateTime now = DateTime.now();

    final DateTime today =
    DateTime(now.year, now.month, now.day);

    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: endDate ?? today,
      firstDate: startDate!,
      lastDate: today,
      helpText: 'اختاري تاريخ النهاية',
      cancelText: 'إلغاء',
      confirmText: 'اختيار',
    );

    if (selectedDate == null || !mounted) return;

    setState(() {
      endDate = selectedDate;
      endDateError = null;
    });
  }

  // =====================================
  // Message
  // =====================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // =====================================
  // Validate Inputs
  // =====================================

  bool _validateInputs() {
    bool hasError = false;

    setState(() {
      startDateError = null;
      endDateError = null;

      if (startDate == null) {
        startDateError = 'يجب اختيار تاريخ البداية';
        hasError = true;
      }

      if (endDate == null) {
        endDateError = 'يجب اختيار تاريخ النهاية';
        hasError = true;
      }

      if (startDate != null &&
          endDate != null &&
          endDate!.isBefore(startDate!)) {
        endDateError =
        'تاريخ النهاية يجب أن يكون مساويًا لتاريخ البداية أو بعده';

        hasError = true;
      }
    });

    return !hasError;
  }

  // =====================================
  // Generate Comprehensive Health Report
  // =====================================

  Future<void> generateReport() async {
    FocusScope.of(context).unfocus();

    if (isGenerating) return;

    if (!_validateInputs()) return;

    if (widget.childId <= 0) {
      _showMessage('لم يتم تحديد الطفل بشكل صحيح.');
      return;
    }

    final DateTime reportStartDate = startDate!;
    final DateTime reportEndDate = endDate!;

    // نوع التقرير ثابت
    const String reportType = 'comprehensive';

    setState(() {
      isGenerating = true;
    });

    try {
      // =====================================
      // إنشاء التقرير من Laravel
      // =====================================

      final Map<String, dynamic> report =
      await ReportService.generateReport(
        childId: widget.childId,
        reportType: reportType,
        startDate: reportStartDate,
        endDate: reportEndDate,
      );

      if (!mounted) return;

      if (report.isEmpty) {
        _showMessage('لم تصل بيانات التقرير من الخادم.');
        return;
      }

      // =====================================
      // جلب التحليل الصحي الشامل
      // =====================================

      final Map<String, dynamic> healthAnalysis =
      await ReportService.getHealthAnalysis(
        childId: widget.childId,
        startDate: reportStartDate,
        endDate: reportEndDate,
      );

      if (!mounted) return;

      // إضافة التحليل إلى بيانات التقرير
      report['health_analysis'] = healthAnalysis;

      // =====================================
      // التحقق من بيانات التقرير
      // =====================================

      final dynamic reportData = report['data'];

      if (reportData is! Map) {
        _showMessage('بيانات التقرير غير مكتملة.');
        return;
      }

      // =====================================
      // فتح التقرير الصحي الشامل
      // =====================================

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ComprehensiveHealthReportScreen(
                childId: widget.childId,
                childName: widget.childName,
                startDate: reportStartDate,
                endDate: reportEndDate,
                report: report,
              ),
        ),
      );
    } catch (e) {
      if (mounted) {
        _showMessage(
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isGenerating = false;
        });
      }
    }
  }

  // =====================================
  // Build
  // =====================================

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

    final Color cardColor = isDark
        ? const Color(0xff1D292D)
        : Colors.white;

    final Color borderColor = isDark
        ? Colors.white.withOpacity(0.12)
        : const Color(0xffD7E7E7);

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
                      maxWidth: 700,
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
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Center(
                                child: Text(
                                  'إنشاء تقرير',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize:
                                    isTablet ? 31 : 27,
                                    fontWeight:
                                    FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                              ),

                              Align(
                                alignment: AlignmentDirectional
                                    .centerStart,
                                child: IconButton(
                                  onPressed: isGenerating
                                      ? null
                                      : () => Navigator.pop(
                                    context,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints:
                                  const BoxConstraints(
                                    minWidth: 44,
                                    minHeight: 44,
                                  ),
                                  splashRadius: 22,
                                  icon: Icon(
                                    Icons
                                        .arrow_back_ios_new_rounded,
                                    color: textColor,
                                    size: 22,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // =====================================
                        // Selected Child
                        // =====================================

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius:
                            BorderRadius.circular(18),
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
                                  color: primaryColor
                                      .withOpacity(0.12),
                                  borderRadius:
                                  BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  Icons.child_care_rounded,
                                  color: primaryColor,
                                  size: 27,
                                ),
                              ),

                              const SizedBox(width: 12),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 5),

                                    Text(
                                      widget.childName,
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight:
                                        FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),

                        // =====================================
                        // Report Details - One Box
                        // =====================================

                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius:
                            BorderRadius.circular(20),
                            border: Border.all(
                              color: borderColor,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              // =====================================
                              // Fixed Report Type
                              // =====================================

                              Text(
                                'نوع التقرير',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight:
                                  FontWeight.bold,
                                  color: textColor,
                                ),
                              ),

                              const SizedBox(height: 12),

                              InputDecorator(
                                decoration: _inputDecoration(
                                  context,
                                  icon: Icons
                                      .description_outlined,
                                  cardColor: cardColor,
                                  borderColor: borderColor,
                                  primaryColor: primaryColor,
                                  secondaryTextColor:
                                  secondaryTextColor,
                                ),
                                child: Text(
                                  'التقرير الصحي الشامل',
                                  textAlign: TextAlign.right,
                                  textDirection:
                                  TextDirection.rtl,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: textColor,
                                    fontWeight:
                                    FontWeight.w500,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // =====================================
                              // Start Date
                              // =====================================

                              Text(
                                'من تاريخ',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight:
                                  FontWeight.w600,
                                  color: textColor,
                                ),
                              ),

                              const SizedBox(height: 10),

                              InkWell(
                                onTap: isGenerating
                                    ? null
                                    : selectStartDate,
                                borderRadius:
                                BorderRadius.circular(14),
                                child: InputDecorator(
                                  decoration:
                                  _inputDecoration(
                                    context,
                                    icon: Icons
                                        .calendar_month_outlined,
                                    errorText:
                                    startDateError,
                                    cardColor: cardColor,
                                    borderColor: borderColor,
                                    primaryColor:
                                    primaryColor,
                                    secondaryTextColor:
                                    secondaryTextColor,
                                  ),
                                  child: Text(
                                    startDate == null
                                        ? 'اختاري تاريخ البداية'
                                        : formatDate(startDate),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: startDate == null
                                          ? secondaryTextColor
                                          : textColor,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 20),

                              // =====================================
                              // End Date
                              // =====================================

                              Text(
                                'إلى تاريخ',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight:
                                  FontWeight.w600,
                                  color: textColor,
                                ),
                              ),

                              const SizedBox(height: 10),

                              InkWell(
                                onTap: isGenerating
                                    ? null
                                    : selectEndDate,
                                borderRadius:
                                BorderRadius.circular(14),
                                child: InputDecorator(
                                  decoration:
                                  _inputDecoration(
                                    context,
                                    icon: Icons
                                        .event_available_outlined,
                                    errorText: endDateError,
                                    cardColor: cardColor,
                                    borderColor: borderColor,
                                    primaryColor:
                                    primaryColor,
                                    secondaryTextColor:
                                    secondaryTextColor,
                                  ),
                                  child: Text(
                                    endDate == null
                                        ? 'اختاري تاريخ النهاية'
                                        : formatDate(endDate),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: endDate == null
                                          ? secondaryTextColor
                                          : textColor,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // =====================================
                        // Generate Button
                        // =====================================

                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            onPressed: isGenerating
                                ? null
                                : generateReport,
                            icon: isGenerating
                                ? const SizedBox(
                              width: 21,
                              height: 21,
                              child:
                              CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                                : const Icon(
                              Icons.bar_chart_rounded,
                            ),
                            label: Text(
                              isGenerating
                                  ? 'جاري إنشاء التقرير...'
                                  : 'إنشاء التقرير',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight:
                                FontWeight.bold,
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
  // Input Decoration
  // =====================================

  InputDecoration _inputDecoration(
      BuildContext context, {
        required IconData icon,
        required Color cardColor,
        required Color borderColor,
        required Color primaryColor,
        required Color secondaryTextColor,
        String? errorText,
      }) {
    final bool isDark =
        Theme.of(context).brightness == Brightness.dark;

    return InputDecoration(
      prefixIcon: Icon(
        icon,
        color: primaryColor,
      ),
      filled: true,
      fillColor: cardColor,
      errorText: errorText,
      errorStyle: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: Colors.red,
      ),
      hintStyle: TextStyle(
        color: secondaryTextColor,
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 16,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: borderColor,
          width: 1.2,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: primaryColor,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 1.2,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 2,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark
              ? Colors.white.withOpacity(0.08)
              : borderColor,
        ),
      ),
    );
  }
}