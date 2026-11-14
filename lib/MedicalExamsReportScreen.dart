import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class MedicalExamsReportScreen extends StatelessWidget {
  final String childName;
  final DateTime startDate;
  final DateTime endDate;

  // الفحوصات القادمة من Laravel
  final List<Map<String, dynamic>> medicalExams;

  const MedicalExamsReportScreen({
    super.key,
    required this.childName,
    required this.startDate,
    required this.endDate,
    this.medicalExams = const [],
  });

  // =========================
  // Format Date
  // =========================

  String formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String formatExamDate(dynamic value) {
    if (value == null) return 'غير محدد';

    try {
      final date = DateTime.parse(value.toString());
      return formatDate(date);
    } catch (_) {
      return value.toString();
    }
  }

  // =========================
  // Show Message
  // =========================

  void _showMessage(BuildContext context, String message) {
    if (!context.mounted) return;

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

  // =========================
  // Export PDF
  // =========================

  Future<void> _exportPdf(BuildContext context) async {
    try {
      if (medicalExams.isEmpty) {
        _showMessage(
          context,
          'لا توجد بيانات فحوصات لإنشاء التقرير.',
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
          margin: const pw.EdgeInsets.all(32),
          textDirection: pw.TextDirection.rtl,
          build: (pw.Context pdfContext) => [
            // العنوان
            pw.Center(
              child: pw.Text(
                'تقرير الفحوصات الطبية',
                style: pw.TextStyle(
                  font: arabicFont,
                  fontSize: 22,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),

            pw.SizedBox(height: 24),

            pw.Text(
              'اسم الطفل: $childName',
              style: pw.TextStyle(font: arabicFont),
            ),

            pw.SizedBox(height: 10),

            pw.Text(
              'فترة التقرير: ${formatDate(startDate)} - ${formatDate(endDate)}',
              style: pw.TextStyle(font: arabicFont),
            ),

            pw.SizedBox(height: 24),

            // ملخص الفحوصات
            pw.Text(
              'ملخص الفحوصات الطبية',
              style: pw.TextStyle(
                font: arabicFont,
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),

            pw.SizedBox(height: 12),

            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(
                  color: const PdfColor(0.82, 0.88, 0.88),
                ),
                borderRadius: pw.BorderRadius.circular(8),
              ),
              child: pw.Text(
                'إجمالي الفحوصات الطبية المسجلة: ${medicalExams.length}',
                style: pw.TextStyle(
                  font: arabicFont,
                  fontSize: 14,
                ),
              ),
            ),

            pw.SizedBox(height: 24),

            // تفاصيل الفحوصات
            pw.Text(
              'تفاصيل الفحوصات الطبية',
              style: pw.TextStyle(
                font: arabicFont,
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),

            pw.SizedBox(height: 14),

            ...medicalExams.asMap().entries.map((entry) {
              final index = entry.key;
              final exam = entry.value;

              final examName =
                  exam['exam_name']?.toString() ?? 'غير محدد';

              final examDate =
              formatExamDate(exam['exam_date']);

              final attachment =
                  exam['attachment_path']?.toString() ?? '';

              return pw.Container(
                width: double.infinity,
                margin: const pw.EdgeInsets.only(bottom: 14),
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
                      'الفحص رقم ${index + 1}: $examName',
                      style: pw.TextStyle(
                        font: arabicFont,
                        fontSize: 15,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),

                    pw.SizedBox(height: 10),

                    pw.Text(
                      'تاريخ الفحص: $examDate',
                      style: pw.TextStyle(
                        font: arabicFont,
                        fontSize: 12,
                      ),
                    ),

                    pw.SizedBox(height: 8),

                    pw.Text(
                      attachment.isNotEmpty
                          ? 'مرفق الفحص: $attachment'
                          : 'لا يوجد مرفق مسجل.',
                      style: pw.TextStyle(
                        font: arabicFont,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            }),

            pw.SizedBox(height: 20),

            // الملاحظة الطبية
            pw.Text(
              'ملاحظة طبية',
              style: pw.TextStyle(
                font: arabicFont,
                fontSize: 16,
                fontWeight: pw.FontWeight.bold,
              ),
            ),

            pw.SizedBox(height: 8),

            pw.Text(
              'هذا التقرير مخصص لتنظيم الفحوصات الطبية المسجلة ومشاركتها مع الطبيب. لا يُعد تفسيرًا طبيًا لنتائج الفحوصات ولا يغني عن مراجعة الطبيب المختص.',
              style: pw.TextStyle(
                font: arabicFont,
                fontSize: 11,
              ),
            ),
          ],
        ),
      );

      await Printing.layoutPdf(
        name: 'TinyGuide_Medical_Exams_Report.pdf',
        format: PdfPageFormat.a4,
        onLayout: (format) async => pdf.save(),
      );
    } catch (e) {
      if (!context.mounted) return;

      _showMessage(
        context,
        'تعذر إنشاء ملف PDF. تأكدي من وجود الخط وإعداداته.',
      );

      debugPrint('Medical Exams PDF Error: $e');
    }
  }

  // =========================
  // Build Screen
  // =========================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryColor = theme.primaryColor;

    final textColor =
    isDark ? Colors.white : const Color(0xff2C4A5A);

    final secondaryTextColor = isDark
        ? Colors.white.withOpacity(0.60)
        : const Color(0xff78909A);

    final cardColor =
    isDark ? const Color(0xff1D292D) : Colors.white;

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
                    constraints:
                    const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        // =========================
                        // Header
                        // =========================

                        SizedBox(
                          height: 48,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Center(
                                child: Text(
                                  'تقرير الفحوصات الطبية',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: isTablet ? 31 : 25,
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
                          'متابعة الفحوصات الطبية للطفل $childName خلال الفترة المحددة',
                          style: TextStyle(
                            fontSize: 14,
                            color: secondaryTextColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        const SizedBox(height: 24),

                        // =========================
                        // Report Period
                        // =========================

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

                        // =========================
                        // Summary
                        // =========================

                        Text(
                          'ملخص الفحوصات الطبية',
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
                                  Icons.medical_information_outlined,
                                  size: 52,
                                  color: primaryColor,
                                ),

                                const SizedBox(height: 12),

                                Text(
                                  'إجمالي الفحوصات الطبية',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),

                                const SizedBox(height: 8),

                                Text(
                                  '${medicalExams.length}',
                                  style: TextStyle(
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),

                                Text(
                                  'فحص طبي',
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

                        // =========================
                        // Exam Details
                        // =========================

                        Text(
                          'تفاصيل الفحوصات الطبية',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),

                        const SizedBox(height: 12),

                        if (medicalExams.isEmpty)
                          _card(
                            cardColor,
                            borderColor,
                            Column(
                              children: [
                                Icon(
                                  Icons.medical_information_outlined,
                                  size: 48,
                                  color: primaryColor,
                                ),

                                const SizedBox(height: 12),

                                Text(
                                  'لا توجد بيانات فحوصات للعرض',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),

                                const SizedBox(height: 8),

                                Text(
                                  'لا توجد فحوصات طبية مسجلة للطفل خلال الفترة المحددة.',
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
                          ...medicalExams.asMap().entries.map(
                                (entry) {
                              final index = entry.key;
                              final exam = entry.value;

                              return Padding(
                                padding:
                                const EdgeInsets.only(bottom: 12),
                                child: _examCard(
                                  exam: exam,
                                  index: index,
                                  primaryColor: primaryColor,
                                  cardColor: cardColor,
                                  borderColor: borderColor,
                                  textColor: textColor,
                                  secondaryTextColor:
                                  secondaryTextColor,
                                ),
                              );
                            },
                          ),

                        const SizedBox(height: 24),

                        // =========================
                        // Medical Disclaimer
                        // =========================

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
                                  'هذا التقرير مخصص لتنظيم الفحوصات الطبية المسجلة ومشاركتها مع الطبيب. لا يُعد تفسيرًا طبيًا لنتائج الفحوصات ولا يغني عن مراجعة الطبيب المختص.',
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

                        // =========================
                        // Save Report
                        // =========================

                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _showMessage(
                                context,
                                'حفظ التقرير غير متاح حاليًا. سيتفعّل بعد ربط خدمة حفظ التقارير.',
                              );
                            },
                            icon: const Icon(
                              Icons.save_outlined,
                            ),
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

                        // =========================
                        // Download PDF
                        // =========================

                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: medicalExams.isEmpty
                                ? null
                                : () => _exportPdf(context),
                            icon: const Icon(
                              Icons.picture_as_pdf_outlined,
                            ),
                            label: const Text(
                              'تنزيل PDF',
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

  // =========================
  // Exam Card
  // =========================

  Widget _examCard({
    required Map<String, dynamic> exam,
    required int index,
    required Color primaryColor,
    required Color cardColor,
    required Color borderColor,
    required Color textColor,
    required Color secondaryTextColor,
  }) {
    final examName =
        exam['exam_name']?.toString() ?? 'غير محدد';

    final examDate = formatExamDate(exam['exam_date']);

    final attachment =
        exam['attachment_path']?.toString() ?? '';

    return _card(
      cardColor,
      borderColor,
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _icon(
                Icons.medical_information_outlined,
                primaryColor,
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  examName,
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
            Icons.calendar_today_outlined,
            'تاريخ الفحص',
            examDate,
            textColor,
            secondaryTextColor,
          ),

          const SizedBox(height: 12),

          _infoRow(
            Icons.attach_file_rounded,
            'المرفق',
            attachment.isNotEmpty
                ? attachment
                : 'لا يوجد مرفق',
            textColor,
            secondaryTextColor,
          ),
        ],
      ),
    );
  }

  // =========================
  // Information Row
  // =========================

  Widget _infoRow(
      IconData icon,
      String title,
      String value,
      Color textColor,
      Color secondaryTextColor,
      ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
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

  // =========================
  // Card
  // =========================

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

  // =========================
  // Icon
  // =========================

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