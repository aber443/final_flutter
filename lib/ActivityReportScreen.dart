import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart' show rootBundle;

class ActivityReportScreen extends StatelessWidget {
  final String childName;
  final DateTime startDate;
  final DateTime endDate;

  // الأنشطة القادمة من Laravel
  final List<Map<String, dynamic>> activities;

  const ActivityReportScreen({
    super.key,
    required this.childName,
    required this.startDate,
    required this.endDate,
    this.activities = const [],
  });

  String formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String formatActivityDate(dynamic value) {
    if (value == null) return 'غير محدد';

    try {
      final date = DateTime.parse(value.toString());
      return formatDate(date);
    } catch (_) {
      return value.toString();
    }
  }

  void _showMessage(BuildContext context, String message) {
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
  // إنشاء ملف PDF بالبيانات الفعلية
  // =====================================

  Future<void> _exportPdf(BuildContext context) async {
    try {
      if (activities.isEmpty) {
        _showMessage(
          context,
          'لا توجد بيانات نشاط لإنشاء التقرير.',
        );
        return;
      }

      _showMessage(context, 'جارٍ تجهيز ملف PDF...');

      final fontData =
      await rootBundle.load('assets/fonts/arial.ttf');

      final arabicFont = pw.Font.ttf(fontData);

      final pdf = pw.Document(
        theme: pw.ThemeData.withFont(
          base: arabicFont,
          bold: arabicFont,
        ),
      );

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(40),
          textDirection: pw.TextDirection.rtl,
          build: (context) {
            return [
              pw.Center(
                child: pw.Text(
                  'TinyGuide',
                  style: pw.TextStyle(
                    fontSize: 25,
                    fontWeight: pw.FontWeight.bold,
                    color: const PdfColor(0.20, 0.66, 0.64),
                  ),
                ),
              ),

              pw.SizedBox(height: 12),

              pw.Center(
                child: pw.Text(
                  'تقرير النشاط',
                  style: pw.TextStyle(
                    fontSize: 20,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),

              pw.SizedBox(height: 25),

              pw.Text('اسم الطفل: $childName'),

              pw.SizedBox(height: 10),

              pw.Text(
                'تاريخ البداية: ${formatDate(startDate)}',
              ),

              pw.SizedBox(height: 10),

              pw.Text(
                'تاريخ النهاية: ${formatDate(endDate)}',
              ),

              pw.SizedBox(height: 20),

              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: const PdfColor(0.82, 0.88, 0.88),
                  ),
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Column(
                  crossAxisAlignment:
                  pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'ملخص النشاط',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),

                    pw.SizedBox(height: 10),

                    pw.Text(
                      'إجمالي الأنشطة المسجلة: ${activities.length}',
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 20),

              pw.Text(
                'تفاصيل الأنشطة',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),

              pw.SizedBox(height: 12),

              ...activities.map((activity) {
                return pw.Container(
                  width: double.infinity,
                  margin: const pw.EdgeInsets.only(bottom: 12),
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                      color: const PdfColor(0.82, 0.88, 0.88),
                    ),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment:
                    pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        activity['activity_name']?.toString() ??
                            'غير محدد',
                        style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),

                      pw.SizedBox(height: 7),

                      pw.Text(
                        'المدة: ${activity['duration'] ?? 'غير محددة'}',
                      ),

                      pw.SizedBox(height: 5),

                      pw.Text(
                        'الشدة: ${activity['intensity'] ?? 'غير محددة'}',
                      ),

                      pw.SizedBox(height: 5),

                      pw.Text(
                        'التاريخ: ${formatActivityDate(activity['activity_date'])}',
                      ),

                      pw.SizedBox(height: 5),

                      pw.Text(
                        'الوقت: ${activity['activity_time'] ?? 'غير محدد'}',
                      ),
                    ],
                  ),
                );
              }),

              pw.SizedBox(height: 15),

              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                    color: const PdfColor(0.82, 0.88, 0.88),
                  ),
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Text(
                  'تنبيه: هذا التقرير مخصص للمتابعة والتنظيم فقط، '
                      'ولا يُعد تقييمًا طبيًا لمستوى نشاط الطفل.',
                  style: const pw.TextStyle(
                    fontSize: 11,
                    lineSpacing: 4,
                  ),
                ),
              ),

              pw.SizedBox(height: 20),

              pw.Divider(),

              pw.Center(
                child: pw.Text(
                  'تم إنشاء هذا التقرير بواسطة TinyGuide',
                  style: const pw.TextStyle(fontSize: 10),
                ),
              ),
            ];
          },
        ),
      );

      await Printing.layoutPdf(
        name: 'TinyGuide_Activity_Report.pdf',
        format: PdfPageFormat.a4,
        onLayout: (format) async => pdf.save(),
      );
    } catch (error) {
      if (!context.mounted) return;

      _showMessage(
        context,
        'تعذر إنشاء ملف PDF. حاولي مرة أخرى.',
      );

      debugPrint('Activity PDF export error: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryColor = theme.primaryColor;

    final textColor = isDark
        ? Colors.white
        : const Color(0xff2C4A5A);

    final secondaryTextColor = isDark
        ? Colors.white.withOpacity(0.60)
        : const Color(0xff78909A);

    final cardColor = isDark
        ? const Color(0xff1D292D)
        : Colors.white;

    final borderColor = isDark
        ? Colors.white.withOpacity(0.12)
        : const Color(0xffE2EEEE);

    return Scaffold(
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isTablet = constraints.maxWidth >= 600;

              final horizontalPadding =
              constraints.maxWidth < 390
                  ? 14.0
                  : isTablet
                  ? 36.0
                  : 20.0;

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
                        // عنوان التقرير
                        SizedBox(
                          height: 48,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Center(
                                child: Text(
                                  'تقرير النشاط',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: isTablet ? 31 : 27,
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
                                    size: 22,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 10),

                        Text(
                          'متابعة نشاط $childName خلال الفترة المحددة',
                          style: TextStyle(
                            fontSize: 14,
                            color: secondaryTextColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // فترة التقرير
                        _card(
                          cardColor,
                          borderColor,
                          Row(
                            children: [
                              _icon(
                                Icons.date_range_rounded,
                                primaryColor,
                              ),

                              const SizedBox(width: 12),

                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                  CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'فترة التقرير',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),

                                    const SizedBox(height: 5),

                                    Text(
                                      '${formatDate(startDate)} - ${formatDate(endDate)}',
                                      style: TextStyle(
                                        fontSize: 13,
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

                        // ملخص النشاط
                        Text(
                          'ملخص النشاط',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),

                        const SizedBox(height: 14),

                        _card(
                          cardColor,
                          borderColor,
                          SizedBox(
                            width: double.infinity,
                            child: Column(
                              children: [
                                Icon(
                                  Icons.directions_run_rounded,
                                  size: 52,
                                  color: primaryColor,
                                ),

                                const SizedBox(height: 12),

                                Text(
                                  'إجمالي الأنشطة المسجلة',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),

                                const SizedBox(height: 8),

                                Text(
                                  '${activities.length}',
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),

                                Text(
                                  'نشاط',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: secondaryTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // تفاصيل النشاط
                        Text(
                          'تفاصيل النشاط',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),

                        const SizedBox(height: 14),

                        if (activities.isEmpty)
                          _card(
                            cardColor,
                            borderColor,
                            Column(
                              children: [
                                Icon(
                                  Icons.directions_run_rounded,
                                  size: 48,
                                  color: primaryColor,
                                ),

                                const SizedBox(height: 12),

                                Text(
                                  'لا توجد بيانات نشاط للعرض',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),

                                const SizedBox(height: 8),

                                Text(
                                  'لا توجد سجلات نشاط خلال الفترة المحددة.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.7,
                                    color: secondaryTextColor,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ...activities.asMap().entries.map((entry) {
                            final index = entry.key;
                            final activity = entry.value;

                            return Padding(
                              padding:
                              const EdgeInsets.only(bottom: 12),
                              child: _activityCard(
                                activity: activity,
                                index: index,
                                primaryColor: primaryColor,
                                cardColor: cardColor,
                                borderColor: borderColor,
                                textColor: textColor,
                                secondaryTextColor:
                                secondaryTextColor,
                              ),
                            );
                          }),

                        const SizedBox(height: 12),

                        // تنبيه طبي
                        _card(
                          cardColor,
                          borderColor,
                          Row(
                            crossAxisAlignment:
                            CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                color: primaryColor,
                                size: 22,
                              ),

                              const SizedBox(width: 9),

                              Expanded(
                                child: Text(
                                  'هذا التقرير مخصص للمتابعة والتنظيم فقط، '
                                      'ولا يُعد تقييمًا طبيًا لمستوى نشاط الطفل.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.7,
                                    color: secondaryTextColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // حفظ التقرير
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _showMessage(
                                context,
                                'حفظ التقرير سيتاح بعد ربط خدمة حفظ التقارير.',
                              );
                            },
                            icon: const Icon(Icons.save_outlined),
                            label: const Text(
                              'حفظ التقرير',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // تحميل PDF
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: activities.isEmpty
                                ? null
                                : () => _exportPdf(context),
                            icon: const Icon(
                              Icons.picture_as_pdf_outlined,
                            ),
                            label: const Text(
                              'تحميل التقرير PDF',
                              style: TextStyle(
                                fontSize: 15,
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
  // بطاقة تفاصيل النشاط
  // =====================================

  Widget _activityCard({
    required Map<String, dynamic> activity,
    required int index,
    required Color primaryColor,
    required Color cardColor,
    required Color borderColor,
    required Color textColor,
    required Color secondaryTextColor,
  }) {
    return _card(
      cardColor,
      borderColor,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _icon(
                Icons.directions_run_rounded,
                primaryColor,
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  activity['activity_name']?.toString() ??
                      'نشاط ${index + 1}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          _infoRow(
            Icons.timer_outlined,
            'المدة',
            activity['duration']?.toString() ?? 'غير محددة',
            textColor,
            secondaryTextColor,
          ),

          const SizedBox(height: 10),

          _infoRow(
            Icons.speed_rounded,
            'الشدة',
            activity['intensity']?.toString() ?? 'غير محددة',
            textColor,
            secondaryTextColor,
          ),

          const SizedBox(height: 10),

          _infoRow(
            Icons.calendar_today_outlined,
            'التاريخ',
            formatActivityDate(activity['activity_date']),
            textColor,
            secondaryTextColor,
          ),

          const SizedBox(height: 10),

          _infoRow(
            Icons.access_time_rounded,
            'الوقت',
            activity['activity_time']?.toString() ??
                'غير محدد',
            textColor,
            secondaryTextColor,
          ),
        ],
      ),
    );
  }

  Widget _infoRow(
      IconData icon,
      String title,
      String value,
      Color textColor,
      Color secondaryTextColor,
      ) {
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: secondaryTextColor,
        ),

        const SizedBox(width: 9),

        Text(
          '$title: ',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),

        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: secondaryTextColor,
            ),
          ),
        ),
      ],
    );
  }

  // =====================================
  // البطاقة العامة
  // =====================================

  Widget _card(
      Color cardColor,
      Color borderColor,
      Widget child,
      ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: child,
    );
  }

  // =====================================
  // الأيقونات
  // =====================================

  Widget _icon(
      IconData icon,
      Color primaryColor,
      ) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(
        icon,
        color: primaryColor,
        size: 25,
      ),
    );
  }
}