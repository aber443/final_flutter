import 'dart:convert';

import 'package:flutter/material.dart';

import 'ActivityReportScreen.dart';
import 'ComprehensiveHealthReportScreen.dart';
import 'MedicalExamsReportScreen.dart';
import 'services/report_service.dart';

class SavedReportsScreen extends StatefulWidget {
  final int childId;
  final String childName;
  final bool showSavedMessage;

  const SavedReportsScreen({
    super.key,
    required this.childId,
    required this.childName,
    this.showSavedMessage = false,
  });

  @override
  State<SavedReportsScreen> createState() =>
      _SavedReportsScreenState();
}

class _SavedReportsScreenState extends State<SavedReportsScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _reports = [];

  static const Color primary = Color(0xff60C5C2);
  static const Color darkText = Color(0xff2C4A5A);
  static const Color secondaryText = Color(0xff78909A);
  static const Color border = Color(0xffE2EEEE);

  @override
  void initState() {
    super.initState();
    _loadReports();

    if (widget.showSavedMessage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showMessage('تم حفظ التقرير بنجاح.');
      });
    }
  }

  // =====================================
  // تحميل التقارير المحفوظة
  // =====================================

  Future<void> _loadReports() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final reports = await ReportService.getSavedReports(
        childId: widget.childId,
      );

      final normalizedReports =
      reports.map(_normalizeReport).toList();

      if (!mounted) return;

      setState(() {
        _reports = normalizedReports;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage =
            error.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  // =====================================
  // تجهيز بيانات التقرير
  // =====================================

  Map<String, dynamic> _normalizeReport(
      Map<String, dynamic> source,
      ) {
    final String type =
        source['report_type']?.toString() ?? '';

    final DateTime now = DateTime.now();

    final DateTime startDate =
        DateTime.tryParse(
          source['start_date']?.toString() ?? '',
        ) ??
            now;

    final DateTime endDate =
        DateTime.tryParse(
          source['end_date']?.toString() ?? '',
        ) ??
            now;

    dynamic rawData = source['report_data'];
    Map<String, dynamic> reportData = {};

    if (rawData is Map) {
      reportData = Map<String, dynamic>.from(rawData);
    } else if (rawData is String &&
        rawData.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawData);

        if (decoded is Map) {
          reportData = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        reportData = {};
      }
    }

    final child = source['child'] is Map
        ? Map<String, dynamic>.from(source['child'])
        : <String, dynamic>{};

    return {
      'reportId': source['report_id'],
      'title':
      source['title']?.toString() ?? _titleForType(type),
      'type': type,
      'icon': _iconForType(type),
      'startDate': startDate,
      'endDate': endDate,
      'summary': source['summary']?.toString() ?? '',
      'generatedAt': source['generated_at']?.toString(),
      'reportData': reportData,
      'childName':
      child['name']?.toString() ?? widget.childName,
    };
  }

  // =====================================
  // أنواع التقارير
  // =====================================

  String _titleForType(String type) {
    switch (type) {
      case 'comprehensive':
        return 'التقرير الصحي الشامل';

      case 'activity':
        return 'تقرير النشاط البدني';

      case 'medical_exams':
      case 'exams':
        return 'تقرير الفحوصات الطبية';

      default:
        return 'تقرير صحي';
    }
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'comprehensive':
        return Icons.health_and_safety_outlined;

      case 'activity':
        return Icons.directions_run_rounded;

      case 'medical_exams':
      case 'exams':
        return Icons.medical_information_outlined;

      default:
        return Icons.description_outlined;
    }
  }

  // =====================================
  // تنسيق التاريخ
  // =====================================

  String _formatDate(DateTime date) {
    final String day = date.day.toString().padLeft(2, '0');
    final String month = date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  // =====================================
  // تحويل السجلات
  // =====================================

  List<Map<String, dynamic>> _records(dynamic value) {
    if (value is! List) return [];

    return value
        .whereType<Map>()
        .map(
          (item) => Map<String, dynamic>.from(item),
    )
        .toList();
  }

  // =====================================
  // عرض الرسائل
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
      ),
    );
  }

  // =====================================
  // فتح التقرير المحفوظ
  // =====================================

  void _openReport(Map<String, dynamic> savedReport) {
    final DateTime startDate =
    savedReport['startDate'] as DateTime;

    final DateTime endDate =
    savedReport['endDate'] as DateTime;

    final Map<String, dynamic> data =
    Map<String, dynamic>.from(
      savedReport['reportData'] as Map,
    );

    final String type =
        savedReport['type']?.toString() ?? '';

    late final Widget screen;

    switch (type) {
      case 'comprehensive':
        screen = ComprehensiveHealthReportScreen(
          childId: widget.childId,
          childName: widget.childName,
          startDate: startDate,
          endDate: endDate,
          report: {
            'child': {
              'child_id': widget.childId,
              'name': widget.childName,
            },
            'data': data,
          },
        );
        break;

      case 'activity':
        screen = ActivityReportScreen(
          childName: widget.childName,
          startDate: startDate,
          endDate: endDate,
          activities: _records(data['activities']),
        );
        break;

      case 'medical_exams':
      case 'exams':
        screen = MedicalExamsReportScreen(
          childName: widget.childName,
          startDate: startDate,
          endDate: endDate,
          medicalExams: _records(
            data['medical_exams'] ?? data['exams'],
          ),
        );
        break;

      default:
        _showMessage(
          'نوع التقرير المحفوظ غير مدعوم حاليًا.',
        );
        return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
  }

  // =====================================
  // واجهة الصفحة
  // =====================================

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final bool isDark =
        theme.brightness == Brightness.dark;

    final Color primaryColor = primary;

    final Color textColor =
    isDark ? Colors.white : darkText;

    final Color secondaryTextColor = isDark
        ? Colors.white.withOpacity(0.60)
        : secondaryText;

    final Color cardColor = isDark
        ? const Color(0xff1D292D)
        : Colors.white;

    final Color borderColor = isDark
        ? Colors.white.withOpacity(0.12)
        : border;

    return Scaffold(
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool isTablet =
                  constraints.maxWidth >= 600;

              final double horizontalPadding =
              constraints.maxWidth < 390
                  ? 14
                  : isTablet
                  ? 36
                  : 20;

              return SingleChildScrollView(
                physics:
                const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 18,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints:
                    const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        // =====================================
                        // عنوان الصفحة
                        // =====================================

                        SizedBox(
                          height: 48,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Center(
                                child: Text(
                                  'التقارير المحفوظة',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize:
                                    isTablet ? 29 : 24,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                              ),

                              Align(
                                alignment:
                                AlignmentDirectional.centerStart,
                                child: IconButton(
                                  onPressed: () =>
                                      Navigator.pop(context),
                                  icon: Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    color: textColor,
                                  ),
                                ),
                              ),

                              Align(
                                alignment:
                                AlignmentDirectional.centerEnd,
                                child: IconButton(
                                  onPressed: _loadReports,
                                  tooltip: 'تحديث التقارير',
                                  icon: Icon(
                                    Icons.refresh_rounded,
                                    color: primaryColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // =====================================
                        // اسم الطفل
                        // =====================================

                        Text(
                          'تقارير الطفل: ${widget.childName}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: secondaryTextColor,
                          ),
                        ),

                        const SizedBox(height: 20),

                        // =====================================
                        // حالات التحميل
                        // =====================================

                        if (_isLoading)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 65,
                            ),
                            child: Center(
                              child: CircularProgressIndicator(
                                color: primaryColor,
                              ),
                            ),
                          )
                        else if (_errorMessage != null)
                          _buildErrorState(
                            primaryColor: primaryColor,
                            cardColor: cardColor,
                            borderColor: borderColor,
                            textColor: textColor,
                            secondaryTextColor:
                            secondaryTextColor,
                          )
                        else if (_reports.isEmpty)
                            _buildEmptyState(
                              primaryColor: primaryColor,
                              cardColor: cardColor,
                              borderColor: borderColor,
                              textColor: textColor,
                              secondaryTextColor:
                              secondaryTextColor,
                            )
                          else ...[
                              Text(
                                'عدد التقارير المحفوظة: ${_reports.length}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: secondaryTextColor,
                                ),
                              ),

                              const SizedBox(height: 12),

                              ..._reports.map((report) {
                                return Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: 12,
                                  ),
                                  child: _buildReportCard(
                                    context: context,
                                    report: report,
                                    primaryColor: primaryColor,
                                    cardColor: cardColor,
                                    borderColor: borderColor,
                                    textColor: textColor,
                                    secondaryTextColor:
                                    secondaryTextColor,
                                  ),
                                );
                              }),
                            ],
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
  // بطاقة التقرير - التصميم الجديد
  // =====================================

  Widget _buildReportCard({
    required BuildContext context,
    required Map<String, dynamic> report,
    required Color primaryColor,
    required Color cardColor,
    required Color borderColor,
    required Color textColor,
    required Color secondaryTextColor,
  }) {
    final DateTime startDate =
    report['startDate'] as DateTime;

    final DateTime endDate =
    report['endDate'] as DateTime;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 16,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // =====================================
          // المعلومات على اليمين والزر على اليسار
          // =====================================

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // أيقونة التقرير
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  report['icon'] as IconData,
                  color: primaryColor,
                  size: 23,
                ),
              ),

              const SizedBox(width: 9),

              // اسم التقرير والتاريخ
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      report['title']?.toString() ??
                          'تقرير صحي',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      '${_formatDate(startDate)} - ${_formatDate(endDate)}',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.5,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 9),

              // =====================================
              // زر فتح التقرير على اليسار
              // =====================================

              SizedBox(
                width: 115,
                height: 37,
                child: OutlinedButton.icon(
                  onPressed: () => _openReport(report),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryColor,
                    side: BorderSide(
                      color: primaryColor.withOpacity(0.65),
                      width: 1.1,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                      BorderRadius.circular(11),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                    ),
                  ),
                  icon: const Icon(
                    Icons.visibility_outlined,
                    size: 15,
                  ),
                  label: const Text(
                    'فتح التقرير',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),

          // =====================================
          // ملخص التقرير إن وجد
          // =====================================

          if ((report['summary'] ?? '')
              .toString()
              .trim()
              .isNotEmpty) ...[
            const SizedBox(height: 12),

            Text(
              report['summary'].toString(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: secondaryTextColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // =====================================
  // حالة الخطأ
  // =====================================

  Widget _buildErrorState({
    required Color primaryColor,
    required Color cardColor,
    required Color borderColor,
    required Color textColor,
    required Color secondaryTextColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 30,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 52,
            color: primaryColor,
          ),

          const SizedBox(height: 14),

          Text(
            'تعذر تحميل التقارير المحفوظة',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            _errorMessage ?? 'حدث خطأ غير متوقع.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.6,
              color: secondaryTextColor,
            ),
          ),

          const SizedBox(height: 15),

          ElevatedButton.icon(
            onPressed: _loadReports,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // =====================================
  // حالة عدم وجود تقارير
  // =====================================

  Widget _buildEmptyState({
    required Color primaryColor,
    required Color cardColor,
    required Color borderColor,
    required Color textColor,
    required Color secondaryTextColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 34,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Icon(
            Icons.folder_off_outlined,
            size: 58,
            color: primaryColor,
          ),

          const SizedBox(height: 16),

          Text(
            'لا توجد تقارير محفوظة',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'ستظهر هنا التقارير التي تحفظينها لهذا الطفل.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.7,
              color: secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }
}