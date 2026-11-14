
import 'dart:convert';

import 'package:flutter/material.dart';
import 'services/report_service.dart';
import 'SavedReportsScreen.dart';

// =====================================================
// Comprehensive Health Report
// =====================================================

class ComprehensiveHealthReportScreen extends StatefulWidget {
  final int childId;
  final String childName;
  final String? childAge;
  final DateTime startDate;
  final DateTime endDate;
  final Map<String, dynamic> report;

  const ComprehensiveHealthReportScreen({
    super.key,
    required this.childId,
    required this.childName,
    this.childAge,
    required this.startDate,
    required this.endDate,
    required this.report,
  });

  @override
  State<ComprehensiveHealthReportScreen> createState() =>
      _ComprehensiveHealthReportScreenState();
}

class _ComprehensiveHealthReportScreenState
    extends State<ComprehensiveHealthReportScreen> {
  int get childId => widget.childId;
  String get childName => widget.childName;
  String? get childAge => widget.childAge;
  DateTime get startDate => widget.startDate;
  DateTime get endDate => widget.endDate;
  Map<String, dynamic> get report => widget.report;

  DateTime? _selectedAnalysisDay;

  void _setSelectedAnalysisDay(DateTime? day) {
    setState(() => _selectedAnalysisDay = day);
  }

// =====================================================
// TinyGuide Colors
// =====================================================

  static const Color primary = Color(0xff60C5C2);
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get darkText => _isDark ? const Color(0xffEDF7F7) : const Color(0xff2C4A5A);
  Color get secondaryText => _isDark ? const Color(0xffAEC5CB) : const Color(0xff78909A);
  Color get background => _isDark ? const Color(0xff101D25) : const Color(0xffF0F8F8);
  Color get border => _isDark ? const Color(0xff36505A) : const Color(0xffDDECEC);
  Color get _cardColor => _isDark ? const Color(0xff1B2B35) : Colors.white;

// =====================================================
// Report Data
// =====================================================

  Map<String, dynamic> get reportData {
    final data = report['data'];

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    return {};
  }

// تجهيز بيانات التقرير للحفظ كما يتوقعها Laravel داخل report_data.
// نحتفظ بجميع السجلات، ونضيف التحليل الذي جُلب من خدمة التحليل
// إذا كان موجودًا على مستوى الاستجابة بدلًا من report.data.
  Map<String, dynamic> get saveReportPayload {
    final data = reportData;
    final dynamic separateAnalysis = report['health_analysis'];

    if (separateAnalysis is Map) {
      data['health_analysis'] =
      Map<String, dynamic>.from(separateAnalysis);
    }

    return data;
  }

// قد يصل التحليل داخل report.data أو في المستوى الرئيسي
// بعد جلبه من ReportService.getHealthAnalysis.
  Map<String, dynamic> get healthAnalysis {
    final dynamic separateAnalysis = report['health_analysis'];

    if (separateAnalysis is Map) {
      return Map<String, dynamic>.from(separateAnalysis);
    }

    final dynamic nestedAnalysis = reportData['health_analysis'];

    if (nestedAnalysis is Map) {
      return Map<String, dynamic>.from(nestedAnalysis);
    }

    return {};
  }

  Map<String, dynamic> get mealAnalysis {
    final data = healthAnalysis['meal_analysis'];

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    return {};
  }

  Map<String, dynamic> get analysisSummary {
    final data = mealAnalysis['summary'];

    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }

    return {};
  }

// =====================================================
// Records
// =====================================================

  List<Map<String, dynamic>> records(String key) {
    final data = reportData[key];

    if (data is! List) return [];

    return data
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  List<Map<String, dynamic>> get glucoseReadings =>
      records('glucose_readings');

  List<Map<String, dynamic>> get meals =>
      records('meals');

  List<Map<String, dynamic>> get medications =>
      records('medications');

  List<Map<String, dynamic>> get activities =>
      records('activities');

  List<Map<String, dynamic>> get medicalExams =>
      records('medical_exams');

// =====================================================
// Child Age
// =====================================================

// تنسيق العمر حسب قواعد اللغة العربية:
// 1 سنة، 2 سنتين، من 3 إلى 10 سنوات، و11 و12 سنة.
  String _formatAge(dynamic rawAge) {
    final rawText = rawAge.toString().trim();
    final match = RegExp(r'\d+').firstMatch(rawText);

    if (match == null) return rawText;

    final years = int.tryParse(match.group(0)!);
    if (years == null) return rawText;

    final unit = years == 1
        ? 'سنة'
        : years == 2
        ? 'سنتين'
        : years >= 3 && years <= 10
        ? 'سنوات'
        : 'سنة';

    return '$years $unit';
  }

  String get displayedAge {
    if (childAge != null &&
        childAge!.trim().isNotEmpty &&
        childAge!.trim() != 'غير متوفر') {
      return _formatAge(childAge);
    }

    final child = report['child'] is Map
        ? Map<String, dynamic>.from(report['child'])
        : <String, dynamic>{};

    final dynamic age =
        child['age'] ?? report['child_age'];

    if (age != null) {
      return _formatAge(age);
    }

    final birthDate = child['birth_date'] ??
        child['date_of_birth'] ??
        report['birth_date'] ??
        reportData['birth_date'];

    if (birthDate != null) {
      final date = DateTime.tryParse(
        birthDate.toString(),
      );

      if (date != null) {
        final now = DateTime.now();

        int years = now.year - date.year;

        if (now.month < date.month ||
            (now.month == date.month &&
                now.day < date.day)) {
          years--;
        }

        if (years >= 0) {
          return _formatAge(years);
        }
      }
    }

    return 'غير متوفر';
  }

// =====================================================
// Helpers
// =====================================================

  String value(
      Map<String, dynamic> record,
      List<String> keys, {
        String fallback = 'غير متوفر',
      }) {
    for (final key in keys) {
      final data = record[key];

      if (data != null &&
          data.toString().trim().isNotEmpty) {
        return data.toString();
      }
    }

    return fallback;
  }

  String optionalValue(
      Map<String, dynamic> record,
      List<String> keys,
      ) {
    for (final key in keys) {
      final data = record[key];

      if (data != null &&
          data.toString().trim().isNotEmpty) {
        return data.toString();
      }
    }

    return '';
  }

// تحويل مكونات الوجبة المخزنة بصيغة JSON إلى أسماء أطعمة واضحة.
  List<String> mealFoods(Map<String, dynamic> meal) {
    dynamic raw = meal['ingredients'];

    if (raw is String && raw.trim().isNotEmpty) {
      try {
        raw = jsonDecode(raw);
      } catch (_) {
        return [raw];
      }
    }

    final foods = <String>[];
    if (raw is Map) {
      for (final entry in raw.entries) {
        final items = entry.value;
        if (items is List) {
          foods.addAll(items.map((item) => item.toString()));
        } else if (items != null && items.toString().trim().isNotEmpty) {
          foods.add(items.toString());
        }
      }
    } else if (raw is List) {
      foods.addAll(raw.map((item) => item.toString()));
    }

    if (foods.isEmpty) {
      final name = optionalValue(meal, ['meal_name', 'name']);
      if (name.isNotEmpty) foods.add(name);
    }

    return foods;
  }

  String mealTypeLabel(Map<String, dynamic> meal) {
    final type = value(meal, ['meal_type'], fallback: 'الوجبة');
    if (type.contains('الإفطار')) return 'الإفطار';
    if (type.contains('الغداء')) return 'الغداء';
    if (type.contains('العشاء')) return 'العشاء';
    return type;
  }

  String formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String get periodType {
    final start = DateTime(
      startDate.year,
      startDate.month,
      startDate.day,
    );

    final end = DateTime(
      endDate.year,
      endDate.month,
      endDate.day,
    );

    final days = end.difference(start).inDays + 1;

    if (days == 1) return 'التقرير اليومي';
    if (days == 7) return 'التحليل الأسبوعي';

    if (days >= 28 && days <= 31) {
      return 'التحليل الشهري';
    }

    return 'تقرير لمدة $days يوم';
  }

  void showMessage(
      BuildContext context,
      String message,
      ) {
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

// =====================================================
// Glucose Values
// =====================================================

  List<double> get glucoseValues {
    final sortedReadings = [...glucoseReadings];

    DateTime? readingDateTime(Map<String, dynamic> reading) {
      final combined = reading['measured_at'] ??
          reading['reading_datetime'];

      if (combined != null && combined.toString().trim().isNotEmpty) {
        return DateTime.tryParse(combined.toString());
      }

      final date = reading['reading_date'];
      final time = reading['reading_time'];

      if (date == null) return null;

      return DateTime.tryParse(
        '${date.toString()} ${time?.toString() ?? '00:00:00'}',
      );
    }

    sortedReadings.sort((a, b) {
      final dateA = readingDateTime(a);
      final dateB = readingDateTime(b);

      if (dateA == null && dateB == null) return 0;
      if (dateA == null) return 1;
      if (dateB == null) return -1;

      return dateA.compareTo(dateB);
    });

    return sortedReadings
        .map((item) {
      final raw = item['glucose_level'];

      if (raw is num) return raw.toDouble();

      return double.tryParse(
        raw?.toString() ?? '',
      );
    })
        .whereType<double>()
        .toList();
  }

// استخراج التاريخ والوقت من سجل القراءة مع دعم أسماء الحقول المستخدمة في قاعدة البيانات وLaravel.
  DateTime? _readingDateTime(Map<String, dynamic> reading) {
    final combined = reading['measured_at'] ??
        reading['reading_datetime'] ??
        reading['reading_date_time'];

    if (combined != null && combined.toString().trim().isNotEmpty) {
      return DateTime.tryParse(combined.toString());
    }

    final date = reading['reading_date'] ?? reading['measured_date'];
    final time = reading['reading_time'];

    if (date == null) return null;

    return DateTime.tryParse(
      '${date.toString()} ${time?.toString() ?? '00:00:00'}',
    );
  }

  List<DailyGlucosePoint> get dailyGlucosePoints {
    final firstDay = DateTime(startDate.year, startDate.month, startDate.day);
    final lastDay = DateTime(endDate.year, endDate.month, endDate.day);
    final totalDays = lastDay.difference(firstDay).inDays + 1;
    if (totalDays <= 0) return [];

    final readingsByDay = <DateTime, List<Map<String, dynamic>>>{};

    for (final reading in glucoseReadings) {
      final dateTime = _readingDateTime(reading);
      if (dateTime == null) continue;

      final day = DateTime(dateTime.year, dateTime.month, dateTime.day);
      if (day.isBefore(firstDay) || day.isAfter(lastDay)) continue;

      readingsByDay.putIfAbsent(day, () => []).add(reading);
    }

    return List.generate(totalDays, (index) {
      final day = firstDay.add(Duration(days: index));
      final dayReadings = readingsByDay[day] ?? <Map<String, dynamic>>[];
      final values = dayReadings
          .map((reading) => double.tryParse(
        reading['glucose_level']?.toString() ?? '',
      ))
          .whereType<double>()
          .toList();

      final average = values.isEmpty
          ? null
          : values.reduce((a, b) => a + b) / values.length;

      dayReadings.sort((a, b) {
        final first = _readingDateTime(a);
        final second = _readingDateTime(b);
        if (first == null || second == null) return 0;
        return first.compareTo(second);
      });

      return DailyGlucosePoint(
        date: day,
        average: average,
        readings: dayReadings,
      );
    });
  }

  String _formatTime12(dynamic raw) {
    final text = raw?.toString().trim() ?? '';
    if (text.isEmpty || text == 'غير متوفر') return 'الوقت غير متوفر';
    final date = DateTime.tryParse(text.contains(' ') || text.contains('T')
        ? text : '2000-01-01 $text');
    if (date == null) return text;
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${date.hour < 12 ? 'ص' : 'م'}';
  }

  String _formatReadingDateTime12(dynamic raw) {
    final date = DateTime.tryParse(raw?.toString() ?? '');
    if (date == null) return raw?.toString() ?? 'غير متوفر';
    return '${formatDate(date)} - ${_formatTime12(date.toIso8601String())}';
  }

  String _formatReadingTime(Map<String, dynamic> reading) {
    final dateTime = _readingDateTime(reading);
    if (dateTime != null) {
      return _formatTime12(dateTime.toIso8601String());
    }
    return optionalValue(reading, ['reading_time']).isEmpty
        ? 'الوقت غير متوفر'
        : _formatTime12(optionalValue(reading, ['reading_time']));
  }

  String _readingTypeLabel(Map<String, dynamic> reading) {
    final type = optionalValue(reading, [
      'reading_type',
      'measurement_type',
      'readingType',
    ]);
    if (type.isEmpty) return 'نوع القراءة غير محدد';
    return type;
  }

  Widget _dayReadingRow(Map<String, dynamic> reading) {
    final level = reading['glucose_level'];
    final status = optionalValue(reading, ['meal_status']);
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Icon(Icons.bloodtype_outlined, color: primary, size: 17),
          SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _readingTypeLabel(reading),
                  style: TextStyle(
                    color: darkText,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'الوقت: ${_formatReadingTime(reading)}'
                      '${status.isEmpty ? '' : ' • $status'}',
                  style: TextStyle(
                    color: secondaryText,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          Text(
            level == null ? '--' : '$level',
            style: TextStyle(
              color: darkText,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(width: 3),
          Text(
            'mg/dL',
            style: TextStyle(color: secondaryText, fontSize: 9),
          ),
        ],
      ),
    );
  }

  bool _isBeforeMeal(Map<String, dynamic> reading) {
    final type = _readingTypeLabel(reading).toLowerCase();
    return type.contains('قبل') || type.contains('before');
  }

  bool _isAfterMeal(Map<String, dynamic> reading) {
    final type = _readingTypeLabel(reading).toLowerCase();
    return type.contains('بعد') || type.contains('after');
  }

  int? _mealIndexForReading(
      Map<String, dynamic> reading,
      List<Map<String, dynamic>> dayMeals,
      ) {
    final readingMealId = reading['meal_id']?.toString();
    final mealStatus = optionalValue(reading, ['meal_status']).toLowerCase();

// إذا صرّح ولي الأمر أن الوجبة غير مسجلة، لا نربط القراءة بوجبة أخرى بالتخمين.
    if (mealStatus.contains('غير مسجلة') ||
        mealStatus.contains('غير مسجل') ||
        mealStatus.contains('not registered')) {
      return null;
    }

// نعتمد الربط المباشر أولًا، إن كان meal_id موجودًا.
    if (readingMealId != null && readingMealId.isNotEmpty) {
      final linkedIndex = dayMeals.indexWhere(
            (meal) => meal['meal_id']?.toString() == readingMealId,
      );
      return linkedIndex >= 0 ? linkedIndex : null;
    }

// الصائم والقراءات غير المصنفة قبل/بعد الوجبة تبقى قراءات مستقلة.
    final isBefore = _isBeforeMeal(reading);
    final isAfter = _isAfterMeal(reading);
    if (!isBefore && !isAfter) return null;

    final readingTime = _readingDateTime(reading);
    if (readingTime == null) return null;

    int? nearestIndex;
    int nearestMinutes = 181;

    for (int i = 0; i < dayMeals.length; i++) {
      final meal = dayMeals[i];
      final mealDate = DateTime.tryParse(
        '${meal['meal_date']} ${meal['meal_time'] ?? '00:00:00'}',
      );
      if (mealDate == null) continue;

      final difference = mealDate.difference(readingTime).inMinutes;
      final valid = isBefore
          ? difference >= 0 && difference <= 180
          : difference <= 0 && difference >= -180;
      if (!valid) continue;

      final absoluteMinutes = difference.abs();
      if (absoluteMinutes < nearestMinutes) {
        nearestMinutes = absoluteMinutes;
        nearestIndex = i;
      }
    }

    return nearestIndex;
  }

  Widget _readingMetricCard(
      Map<String, dynamic> reading, {
        required String label,
        required Color color,
      }) {
    final level = reading['glucose_level'];
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 5),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bloodtype_outlined, color: color, size: 14),
              SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 3),
          Text(
            level == null ? '--' : '$level',
            style: TextStyle(
              color: darkText,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            'mg/dL',
            style: TextStyle(color: secondaryText, fontSize: 9),
          ),
          SizedBox(height: 3),
          Text(
            _formatReadingTime(reading),
            style: TextStyle(color: secondaryText, fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _readingColumn(
      String title,
      List<Map<String, dynamic>> readings, {
        required Color color,
      }) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (readings.isEmpty)
            Container(
              margin: const EdgeInsets.only(top: 5),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                'لا توجد قراءة',
                textAlign: TextAlign.center,
                style: TextStyle(color: secondaryText, fontSize: 9),
              ),
            )
          else
            ...readings.map(
                  (reading) => _readingMetricCard(
                reading,
                label: title,
                color: color,
              ),
            ),
        ],
      ),
    );
  }

  Widget _selectedDayDetails(DailyGlucosePoint selectedDay) {
    final dayMeals = meals.where((meal) {
      final rawDate = meal['meal_date'];
      final date = rawDate == null ? null : DateTime.tryParse(rawDate.toString());
      return date != null &&
          date.year == selectedDay.date.year &&
          date.month == selectedDay.date.month &&
          date.day == selectedDay.date.day;
    }).toList()
      ..sort((a, b) => value(a, ['meal_time']).compareTo(value(b, ['meal_time'])));

    final linkedReadingIndexes = <int>{};

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, color: primary, size: 16),
              SizedBox(width: 6),
              Expanded(
                child: Text(
                  'تفاصيل ${formatDate(selectedDay.date)}',
                  style: TextStyle(
                    color: darkText,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                selectedDay.average == null
                    ? 'لا يوجد متوسط'
                    : '${selectedDay.average!.toStringAsFixed(1)} mg/dL',
                style: TextStyle(
                  color: primary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          if (selectedDay.readings.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'لا توجد قراءات مسجلة في هذا اليوم.',
                style: TextStyle(color: secondaryText, fontSize: 11),
              ),
            )
          else ...[
            if (dayMeals.isEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: 7),
                child: Text(
                  'لا توجد وجبات مسجلة في هذا اليوم. تظهر القراءات أدناه حسب نوعها ووقتها.',
                  style: TextStyle(color: secondaryText, fontSize: 10),
                ),
              ),
            ...List.generate(dayMeals.length, (mealIndex) {
              final meal = dayMeals[mealIndex];
              final related = <Map<String, dynamic>>[];

              for (int i = 0; i < selectedDay.readings.length; i++) {
                if (_mealIndexForReading(selectedDay.readings[i], dayMeals) == mealIndex) {
                  linkedReadingIndexes.add(i);
                  related.add(selectedDay.readings[i]);
                }
              }

              final beforeReadings = related.where(_isBeforeMeal).toList();
              final afterReadings = related.where(_isAfterMeal).toList();
              final otherReadings = related
                  .where((reading) => !_isBeforeMeal(reading) && !_isAfterMeal(reading))
                  .toList();
              final foods = mealFoods(meal);

              return Container(
                margin: const EdgeInsets.only(top: 7),
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: _cardColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.restaurant_outlined, color: primary, size: 15),
                        SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            mealTypeLabel(meal),
                            style: TextStyle(
                              color: darkText,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Icon(Icons.access_time_rounded, color: secondaryText, size: 12),
                        SizedBox(width: 4),
                        Text(
                          _formatTime12(value(meal, ['meal_time'])),
                          style: TextStyle(color: secondaryText, fontSize: 10),
                        ),
                      ],
                    ),
                    if (foods.isNotEmpty) ...[
                      SizedBox(height: 4),
                      Text(
                        foods.join('، '),
                        style: TextStyle(color: secondaryText, fontSize: 10),
                      ),
                    ],
                    SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _readingColumn(
                          'قبل الوجبة',
                          beforeReadings,
                          color: const Color(0xff7185D5),
                        ),
                        SizedBox(width: 7),
                        _readingColumn(
                          'بعد الوجبة',
                          afterReadings,
                          color: const Color(0xff25AFA9),
                        ),
                      ],
                    ),
                    if (otherReadings.isNotEmpty) ...[
                      Divider(height: 16),
                      Text(
                        'قراءات أخرى مرتبطة بهذا اليوم',
                        style: TextStyle(
                          color: darkText,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      ...otherReadings.map(_dayReadingRow),
                    ],
                  ],
                ),
              );
            }),
            _unlinkedReadingsSection(selectedDay, linkedReadingIndexes),
          ],
        ],
      ),
    );
  }

  Widget _unlinkedReadingsSection(
      DailyGlucosePoint selectedDay,
      Set<int> linkedReadingIndexes,
      ) {
    final unlinked = selectedDay.readings.asMap().entries
        .where((entry) => !linkedReadingIndexes.contains(entry.key))
        .map((entry) => entry.value)
        .toList();

    if (unlinked.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(9),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'قراءات مستقلة خلال اليوم',
            style: TextStyle(
              color: darkText,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
          ...unlinked.map(_dayReadingRow),
        ],
      ),
    );
  }

  double get averageGlucose {
    final values = glucoseValues;

    if (values.isEmpty) return 0;

    return values.reduce((a, b) => a + b) /
        values.length;
  }

  double get highestGlucose {
    final values = glucoseValues;

    if (values.isEmpty) return 0;

    return values.reduce(
          (a, b) => a > b ? a : b,
    );
  }

  double get lowestGlucose {
    final values = glucoseValues;

    if (values.isEmpty) return 0;

    return values.reduce(
          (a, b) => a < b ? a : b,
    );
  }

// =====================================================
// Main Card
// =====================================================

  Widget card(Widget child) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: child,
    );
  }

  Widget sectionTitle(
      String title, {
        IconData? icon,
      }) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            color: primary,
            size: 20,
          ),
          SizedBox(width: 7),
        ],
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: darkText,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

// =====================================================
// Combined Child Information + Report Period
// =====================================================

  Widget reportHeaderCard() {
    return card(
      Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.child_care_rounded,
              color: primary,
              size: 18,
            ),
          ),

          SizedBox(width: 6),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  'اسم الطفل',
                  style: TextStyle(
                    color: secondaryText,
                    fontSize: 10,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  childName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: darkText,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 5),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayedAge == 'غير متوفر'
                            ? 'العمر غير متوفر'
                            : displayedAge,
                        style: TextStyle(
                          color: secondaryText,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Container(
            width: 1,
            height: 48,
            color: border,
          ),

          SizedBox(width: 10),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      size: 16,
                      color: primary,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'فترة التقرير',
                      style: TextStyle(
                        color: darkText,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 5),
                Text(
                  periodType,
                  style: TextStyle(
                    color: primary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  '${formatDate(startDate)} - ${formatDate(endDate)}',
                  style: TextStyle(
                    color: secondaryText,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

// =====================================================
// Compact Statistics
// =====================================================

  Widget statisticItem(
      String title,
      int count,
      IconData icon,
      ) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 3,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: primary,
            size: 15,
          ),
          SizedBox(height: 2),
          Text(
            '$count',
            maxLines: 1,
            style: TextStyle(
              color: darkText,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 0),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              title,
              maxLines: 1,
              style: TextStyle(
                color: secondaryText,
                fontSize: 9,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget statisticsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionTitle(
          'الملخص الصحي العام',
          icon: Icons.health_and_safety_outlined,
        ),
        SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 1.30,
          children: [
            statisticItem(
              'السكر',
              glucoseReadings.length,
              Icons.bloodtype_outlined,
            ),
            statisticItem(
              'الوجبات',
              meals.length,
              Icons.restaurant_outlined,
            ),
            statisticItem(
              'الأدوية',
              medications.length,
              Icons.medication_outlined,
            ),
            statisticItem(
              'الأنشطة',
              activities.length,
              Icons.directions_run_rounded,
            ),
          ],
        ),
      ],
    );
  }

// =====================================================
// Glucose Summary
// =====================================================

  Widget glucoseSummary() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          sectionTitle(
            'ملخص قراءات السكر',
            icon: Icons.monitor_heart_outlined,
          ),
          SizedBox(height: 5),
          Row(
            children: [
              Expanded(
                child: _glucoseNumber(
                  'المتوسط',
                  averageGlucose,
                ),
              ),
              Expanded(
                child: _glucoseNumber(
                  'أعلى قراءة',
                  highestGlucose,
                ),
              ),
              Expanded(
                child: _glucoseNumber(
                  'أقل قراءة',
                  lowestGlucose,
                ),
              ),
            ],
          ),
          SizedBox(height: 3),
          Text(
            'الوحدة: mg/dL',
            style: TextStyle(
              color: secondaryText,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

  Widget _glucoseNumber(
      String title,
      double value,
      ) {
    return Column(
      children: [
        Text(
          value == 0 ? '--' : value.toStringAsFixed(0),
          style: TextStyle(
            fontSize: 20,
            color: darkText,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 2),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: secondaryText,
            fontSize: 9,
          ),
        ),
      ],
    );
  }

// =====================================================
// Glucose Chart
// =====================================================

  Widget glucoseChart() {
    final points = dailyGlucosePoints;
    final availablePoints =
        points.where((point) => point.average != null).length;

    return _InteractiveGlucoseChart(
      points: points,
      availablePoints: availablePoints,
      buildSelectedDetails: _selectedDayDetails,
      onDaySelected: _setSelectedAnalysisDay,
      selectedDay: _selectedAnalysisDay,
    );
  }

// =====================================================
// Info Row
// =====================================================

  Widget infoRow(String title, dynamic data) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              title,
              style: TextStyle(
                color: secondaryText,
                fontSize: 12,
              ),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: Text(
              data == null ||
                  data.toString().trim().isEmpty
                  ? 'غير متوفر'
                  : data.toString(),
              textAlign: TextAlign.left,
              style: TextStyle(
                color: darkText,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

// =====================================================
// Translate Analysis Values
// =====================================================

  String translateValue(String key, dynamic data) {
    if (data == null) return 'غير متوفر';

    if (key == 'classification') {
      switch (data.toString()) {
        case 'before_meal':
          return 'قبل الوجبة';
        case 'within_window':
          return 'بعد الوجبة';
        case 'early':
          return 'بعد الوجبة';
        case 'late':
          return 'بعد الوجبة';
      }
    }

    if (key == 'change_direction') {
      switch (data.toString()) {
        case 'increase':
          return 'ارتفاع';
        case 'decrease':
          return 'انخفاض';
        case 'unchanged':
          return 'ثبات';
      }
    }

    if (data is bool) {
      return data ? 'نعم' : 'لا';
    }

    return data.toString();
  }

// =====================================================
// Reading Card
// =====================================================

  Widget readingCard(
      String title,
      dynamic reading,
      ) {
    if (reading is! Map) {
      return const SizedBox.shrink();
    }

    final data = Map<String, dynamic>.from(reading);

    final classification =
    data['classification']?.toString();

    final isBeforeMeal =
        classification == 'before_meal';

    final isAfterMeal =
        classification == 'within_window' ||
            classification == 'early' ||
            classification == 'late';

    return Container(
      margin: const EdgeInsets.only(top: 9),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: primary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),

          SizedBox(height: 8),

          infoRow(
            'مستوى السكر',
            data['glucose_level'] == null
                ? 'غير متوفر'
                : '${data['glucose_level']} mg/dL',
          ),

          infoRow(
            'تاريخ ووقت القراءة',
            _formatReadingDateTime12(data['reading_datetime'] ?? data['measured_at']),
          ),

          if (isBeforeMeal &&
              data['minutes_before_meal'] != null)
            infoRow(
              'الفارق قبل الوجبة',
              '${data['minutes_before_meal']} دقيقة',
            ),

          if (isAfterMeal &&
              data['minutes_after_meal'] != null)
            infoRow(
              'الفارق بعد الوجبة',
              '${data['minutes_after_meal']} دقيقة',
            ),

          if (data['classification_label'] != null)
            infoRow(
              'التصنيف',
              data['classification_label'],
            ),
        ],
      ),
    );
  }

// =====================================================
// Comparison Card
// =====================================================

  Widget comparisonCard(dynamic comparison) {
    if (comparison is! Map) {
      return const SizedBox.shrink();
    }

    final data = Map<String, dynamic>.from(comparison);

    final before = data['before_reading'];
    final after = data['after_reading'];

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: primary.withOpacity(0.07),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'نتيجة المقارنة',
            style: TextStyle(
              color: darkText,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),

          SizedBox(height: 8),

          infoRow(
            'قراءة قبل الوجبة',
            before is Map
                ? '${before['glucose_level']} mg/dL'
                : 'غير متوفر',
          ),

          infoRow(
            'قراءة بعد الوجبة',
            after is Map
                ? '${after['glucose_level']} mg/dL'
                : 'غير متوفر',
          ),

          infoRow(
            'مقدار التغير',
            data['glucose_difference'] == null
                ? 'غير متوفر'
                : '${data['glucose_difference']} mg/dL',
          ),

          infoRow(
            'اتجاه التغير',
            translateValue(
              'change_direction',
              data['change_direction'],
            ),
          ),
        ],
      ),
    );
  }

// =====================================================
// Meal Analysis Section
// =====================================================

  int _countFrom(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final raw = data[key];
      if (raw is num) return raw.toInt();
      if (raw != null) {
        final parsed = int.tryParse(raw.toString());
        if (parsed != null) return parsed;
      }
    }
    return 0;
  }

  Widget _legendItem(Color color, String title, int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 7),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: secondaryText,
                fontSize: 11,
              ),
            ),
          ),
          Text(
            '$count',
            style: TextStyle(
              color: darkText,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactAnalysisStat(String label, String metric) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: secondaryText, fontSize: 10),
            ),
          ),
          SizedBox(width: 4),
          Flexible(
            child: Text(
              metric,
              textAlign: TextAlign.left,
              style: TextStyle(
                color: darkText,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget mealAnalysisSection() {
    final summary = analysisSummary;
    final raw = mealAnalysis['after_meal_glucose_readings'];
    final linkedReadings = raw is List
        ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];
    final hasDetailedData = raw is List;
    final scopedReadings = linkedReadings.where((reading) {
      if (_selectedAnalysisDay == null) return true;
      final date = _readingDateTime(reading);
      return date != null &&
          date.year == _selectedAnalysisDay!.year &&
          date.month == _selectedAnalysisDay!.month &&
          date.day == _selectedAnalysisDay!.day;
    }).toList();
    int countCategory(String category) => scopedReadings.where((reading) {
      final value = double.tryParse(reading['glucose_level']?.toString() ?? '');
      if (value == null) return false;
      if (category == 'low') return value < 70;
      if (category == 'high') return value > 180;
      return value >= 70 && value <= 180;
    }).length;
    final lowCount = hasDetailedData ? countCategory('low') : _countFrom(summary, ['low_glucose_count']);
    final normalCount = hasDetailedData ? countCategory('normal') : _countFrom(summary, ['in_range_glucose_count']);
    final highCount = hasDetailedData ? countCategory('high') : _countFrom(summary, ['high_glucose_count']);
    final totalAnalyzed = lowCount + normalCount + highCount;
    final beforeCount = _countFrom(summary, ['before_meal_count']);
    final linkedCount = totalAnalyzed;
    final highDays = scopedReadings.where((reading) {
      final value = double.tryParse(reading['glucose_level']?.toString() ?? '');
      return value != null && value > 180;
    }).map((reading) => _readingDateTime(reading)).whereType<DateTime>()
        .map((date) => '${date.year}-${date.month}-${date.day}').toSet().length;
    final averageAfter = scopedReadings.isEmpty ? null :
    scopedReadings.map((e) => double.tryParse(e['glucose_level']?.toString() ?? ''))
        .whereType<double>().fold<double>(0, (a, b) => a + b) / scopedReadings.length;

// تجميع الوجبات حسب النوع: بطاقة واحدة للإفطار، وأخرى للغداء، وأخرى للعشاء.
    const mealOrder = ['الإفطار', 'الغداء', 'العشاء', 'وجبات أخرى'];
    final groupedMeals = <String, List<Map<String, dynamic>>>{};

    for (final meal in meals) {
      final type = mealTypeLabel(meal);
      final normalizedType = mealOrder.contains(type) ? type : 'وجبات أخرى';
      groupedMeals.putIfAbsent(normalizedType, () => []).add(meal);
    }

    final orderedGroups = <String, List<Map<String, dynamic>>>{};
    for (final type in mealOrder) {
      if (groupedMeals.containsKey(type)) {
        orderedGroups[type] = groupedMeals[type]!;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionTitle(
          'تحليل العلاقة بين الوجبات وقراءات السكر',
          icon: Icons.analytics_outlined,
        ),
        SizedBox(height: 8),
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تصنيف قراءات السكر بعد الوجبات المرتبطة',
                style: TextStyle(
                  color: darkText,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 10),
// الدائرة وتصنيفاتها على اليمين، والإحصائيات المختصرة على اليسار.
              Directionality(
                textDirection: TextDirection.rtl,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 5,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          if (totalAnalyzed == 0)
                            Padding(
                              padding: EdgeInsets.symmetric(vertical: 18),
                              child: Text(
                                'لا توجد قراءات مرتبطة لعرضها.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: secondaryText, fontSize: 10),
                              ),
                            )
                          else
                            Align(
                              alignment: Alignment.centerRight,
                              child: SizedBox(
                                width: 112,
                                height: 112,
                                child: CustomPaint(
                                  painter: MealAnalysisDonutPainter(
                                    referenceCount: normalCount,
                                    graceCount: lowCount,
                                    outsideCount: highCount,
                                    isDark: _isDark,
                                  ),
                                  child: Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '$totalAnalyzed',
                                          style: TextStyle(
                                            color: darkText,
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          'قراءة',
                                          style: TextStyle(color: secondaryText, fontSize: 9),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          SizedBox(height: 8),
                          _legendItem(const Color(0xff65C987), 'ضمن النطاق (70–180)', normalCount),
                          _legendItem(const Color(0xffF2B84B), 'منخفض (<70)', lowCount),
                          _legendItem(const Color(0xffEF7180), 'مرتفع (>180)', highCount),
                        ],
                      ),
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      flex: 7,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: 0.78,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                _selectedAnalysisDay == null
                                    ? 'ملخص الفترة كاملة'
                                    : 'ملخص ${formatDate(_selectedAnalysisDay!)}',
                                style: TextStyle(
                                  color: darkText,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 5),
                              _compactAnalysisStat(
                                'إجمالي الوجبات',
                                _selectedAnalysisDay == null
                                    ? '${summary['meals_count'] ?? meals.length}'
                                    : '${meals.where((meal) {
                                  final date = DateTime.tryParse(meal['meal_date']?.toString() ?? '');
                                  return date != null &&
                                      date.year == _selectedAnalysisDay!.year &&
                                      date.month == _selectedAnalysisDay!.month &&
                                      date.day == _selectedAnalysisDay!.day;
                                }).length}',
                              ),
                              if (_selectedAnalysisDay == null)
                                _compactAnalysisStat('قبل الوجبة للمقارنة', '$beforeCount'),
                              _compactAnalysisStat('قراءات بعد الوجبة', '$linkedCount'),
                              _compactAnalysisStat('أيام شهدت ارتفاعًا', '$highDays'),
                              _compactAnalysisStat(
                                'نسبة الارتفاع',
                                totalAnalyzed == 0 ? '0%' : '${(highCount * 100 / totalAnalyzed).toStringAsFixed(1)}%',
                              ),
                              _compactAnalysisStat(
                                'نسبة الانخفاض',
                                totalAnalyzed == 0 ? '0%' : '${(lowCount * 100 / totalAnalyzed).toStringAsFixed(1)}%',
                              ),
                              _compactAnalysisStat(
                                'ضمن النطاق',
                                totalAnalyzed == 0 ? '0%' : '${(normalCount * 100 / totalAnalyzed).toStringAsFixed(1)}%',
                              ),
                              if (averageAfter != null)
                                _compactAnalysisStat('متوسط السكر', '${averageAfter.toStringAsFixed(1)} mg/dL'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 9),
        if (orderedGroups.isEmpty)
          card(
            Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'لا توجد وجبات مسجلة خلال الفترة المحددة.',
                textAlign: TextAlign.center,
                style: TextStyle(color: secondaryText, fontSize: 11),
              ),
            ),
          )
        else
          ...orderedGroups.entries.map((group) {
            final groupTitle = group.key;
            final groupMeals = group.value;
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: border),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                  splashColor: primary.withOpacity(0.05),
                  highlightColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  dense: true,
                  tilePadding: const EdgeInsets.symmetric(horizontal: 9),
                  childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 9),
                  visualDensity: const VisualDensity(vertical: -3),
                  minTileHeight: 42,
                  leading: Container(
                    width: 29,
                    height: 29,
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.restaurant_outlined,
                      color: primary,
                      size: 16,
                    ),
                  ),
                  title: Text(
                    groupTitle,
                    style: TextStyle(
                      color: darkText,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
// إبقاء سهم ExpansionTile الافتراضي حتى يدور عند الفتح والإغلاق.
                  subtitle: Text(
                    '${groupMeals.length} وجبة',
                    style: TextStyle(color: secondaryText, fontSize: 10),
                  ),
                  children: [
// تظهر وجبتان تقريبًا، وتُمرر بقية الوجبات داخل المجموعة فقط.
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: groupMeals.length > 2 ? 142 : double.infinity,
                      ),
                      child: ScrollConfiguration(
                        behavior: const MaterialScrollBehavior().copyWith(scrollbars: false),
                        child: ListView(
                          shrinkWrap: groupMeals.length <= 2,
                          primary: false,
                          physics: groupMeals.length > 2
                              ? const BouncingScrollPhysics()
                              : const NeverScrollableScrollPhysics(),
                          children: groupMeals.map((meal) {

                            final foods = mealFoods(meal);
                            final mealDate = value(meal, ['meal_date']);
                            final mealTime = _formatTime12(value(meal, ['meal_time']));
                            return Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(top: 5),
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                              decoration: BoxDecoration(
                                color: background,
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.calendar_today_outlined, color: secondaryText, size: 12),
                                      SizedBox(width: 5),
                                      Expanded(
                                        child: Text(
                                          mealDate,
                                          style: TextStyle(color: secondaryText, fontSize: 10),
                                        ),
                                      ),
                                      Icon(Icons.access_time_rounded, color: secondaryText, size: 12),
                                      SizedBox(width: 4),
                                      Text(
                                        mealTime,
                                        style: TextStyle(color: secondaryText, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 5),
                                  Text(
                                    foods.isEmpty ? 'لم يتم تحديد الأطعمة.' : foods.join('، '),
                                    style: TextStyle(
                                      color: darkText,
                                      fontSize: 11,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }

  Widget _mealDetailRow(IconData icon, String label, String textValue) {
    return Row(
      children: [
        Icon(icon, color: secondaryText, size: 15),
        SizedBox(width: 7),
        Text(
          '$label: ',
          style: TextStyle(
            color: secondaryText,
            fontSize: 11,
          ),
        ),
        Expanded(
          child: Text(
            textValue,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: darkText,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _smallMetric(String title, int count) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              color: darkText,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          SizedBox(height: 3),
          Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(
              color: secondaryText,
              fontSize: 9,
            ),
          ),
        ],
      ),
    );
  }

// =====================================================
// Physical Activity Chart
// =====================================================

// activity_date هو تاريخ النشاط، بينما activity_time هو الوقت فقط.
  DateTime? _activityDate(Map<String, dynamic> activity) {
    final rawDate = activity['activity_date'] ?? activity['date'];

    if (rawDate != null && rawDate.toString().trim().isNotEmpty) {
      return DateTime.tryParse(rawDate.toString().trim());
    }

// دعم البيانات القديمة إذا كان activity_time يحتوي تاريخًا ووقتًا معًا.
    final rawDateTime = activity['activity_time'];
    if (rawDateTime != null &&
        rawDateTime.toString().trim().contains('-')) {
      return DateTime.tryParse(rawDateTime.toString().trim());
    }

    return null;
  }

// يدعم القيم الرقمية والنصية مثل "20 دقيقة".
  double _activityDurationMinutes(Map<String, dynamic> activity) {
    final raw = activity['duration_minutes'] ??
        activity['duration'] ??
        activity['duration_minute'];

    if (raw == null) return 0;
    if (raw is num) return raw.toDouble();

    final match = RegExp(r'-?\d+(?:\.\d+)?')
        .firstMatch(raw.toString().trim());

    return match == null ? 0 : (double.tryParse(match.group(0)!) ?? 0);
  }

  String _activityDayLabel(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}';
  }

  String _activityWeekLabel(DateTime first, DateTime last) {
    final firstLabel = '${first.day.toString().padLeft(2, '0')}/'
        '${first.month.toString().padLeft(2, '0')}';
    final lastLabel = '${last.day.toString().padLeft(2, '0')}/'
        '${last.month.toString().padLeft(2, '0')}';
    return '$firstLabel - $lastLabel';
  }

  List<ActivityChartBucket> get activityChartData {
    final firstDay = DateTime(startDate.year, startDate.month, startDate.day);
    final lastDay = DateTime(endDate.year, endDate.month, endDate.day);
    final totalDays = lastDay.difference(firstDay).inDays + 1;

    if (totalDays <= 0) return [];

// الأسبوع: عمود لكل يوم. الشهر أو الفترات الأطول: عمود لكل 7 أيام.
    final dailyView = totalDays <= 10;
    final bucketCount = dailyView ? totalDays : (totalDays / 7).ceil();
    final totals = List<double>.filled(bucketCount, 0);
    final activityNames = List<Set<String>>.generate(
      bucketCount,
          (_) => <String>{},
    );

    for (final activity in activities) {
      final date = _activityDate(activity);
      if (date == null) continue;

      final activityDay = DateTime(date.year, date.month, date.day);
      final dayOffset = activityDay.difference(firstDay).inDays;

      if (dayOffset < 0 || dayOffset >= totalDays) continue;

      final bucketIndex = dailyView ? dayOffset : dayOffset ~/ 7;
      totals[bucketIndex] += _activityDurationMinutes(activity);

      final rawName = activity['activity_name'] ??
          activity['activity_type'] ??
          activity['name'];
      final activityName = rawName?.toString().trim() ?? '';
      if (activityName.isNotEmpty) {
        activityNames[bucketIndex].add(activityName);
      }
    }

    return List.generate(bucketCount, (index) {
      final bucketStart = dailyView
          ? firstDay.add(Duration(days: index))
          : firstDay.add(Duration(days: index * 7));
      final bucketEndCandidate = dailyView
          ? bucketStart
          : bucketStart.add(const Duration(days: 6));
      final bucketEnd = bucketEndCandidate.isAfter(lastDay)
          ? lastDay
          : bucketEndCandidate;

      return ActivityChartBucket(
        label: dailyView
            ? _activityDayLabel(bucketStart)
            : _activityWeekLabel(bucketStart, bucketEnd),
        value: totals[index],
        activityNames: activityNames[index].toList(),
      );
    });
  }

  Widget activitySection() {
    final chartData = activityChartData;
    final isDailyView = endDate.difference(startDate).inDays + 1 <= 10;

    return card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle(
            'النشاط البدني خلال الفترة',
            icon: Icons.directions_run_rounded,
          ),
          SizedBox(height: 4),
          Text(
            isDailyView
                ? 'مدة النشاط المسجلة لكل يوم بالدقائق'
                : 'إجمالي مدة النشاط لكل أسبوع بالدقائق',
            style: TextStyle(color: secondaryText, fontSize: 10),
          ),
          SizedBox(height: 8),
          if (activities.isEmpty || chartData.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Text(
                  'لا توجد أنشطة مسجلة خلال الفترة المحددة.',
                  style: TextStyle(color: secondaryText, fontSize: 11),
                ),
              ),
            )
          else ...[
            SizedBox(
              height: 148,
              width: double.infinity,
              child: CustomPaint(
                painter: WeeklyActivityChartPainter(data: chartData, isDark: _isDark),
              ),
            ),
            SizedBox(height: 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.circle, color: primary, size: 8),
                SizedBox(width: 5),
                Text(
                  'مدة النشاط بالدقائق',
                  style: TextStyle(color: secondaryText, fontSize: 9),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }


  Widget medicationsSection() {
    return card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xff7D9BD1).withOpacity(0.13),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.medication_outlined,
                  color: Color(0xff7D9BD1),
                  size: 20,
                ),
              ),
              SizedBox(width: 9),
              Expanded(
                child: Text(
                  'الأدوية المسجلة',
                  style: TextStyle(
                    color: darkText,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                '${medications.length} دواء',
                style: TextStyle(
                  color: secondaryText,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          if (medications.isNotEmpty) ...[
            Divider(height: 20),
            ...medications.map((medication) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 7),
                child: Row(
                  children: [
                    Icon(
                      Icons.medication_liquid_outlined,
                      color: Color(0xff7D9BD1),
                      size: 18,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        value(medication, ['medication_name']),
                        style: TextStyle(
                          color: darkText,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      value(medication, ['dosage']),
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ] else
            Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'لا توجد أدوية مسجلة ضمن بيانات التقرير.',
                style: TextStyle(color: secondaryText, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

// =====================================================
// Record Details
// =====================================================

  List<Map<String, String>> recordDetails(
      String type,
      Map<String, dynamic> record,
      ) {
    switch (type) {
      case 'glucose_readings':
        return [
          {
            'label': 'مستوى السكر',
            'value': value(
              record,
              ['glucose_level'],
            ),
          },
          {
            'label': 'نوع القراءة',
            'value': value(
              record,
              ['reading_type', 'measurement_type'],
            ),
          },
          {
            'label': 'التاريخ',
            'value': value(
              record,
              ['reading_date', 'measured_at'],
            ),
          },
          {
            'label': 'الوقت',
            'value': value(
              record,
              ['reading_time'],
            ),
          },
          if (optionalValue(record, ['notes']).isNotEmpty)
            {
              'label': 'ملاحظات',
              'value': optionalValue(record, ['notes']),
            },
        ];

      case 'meals':
        return [
          {
            'label': 'نوع الوجبة',
            'value': mealTypeLabel(record),
          },
          {
            'label': 'الأطعمة',
            'value': mealFoods(record).isEmpty
                ? 'غير محدد'
                : mealFoods(record).join('، '),
          },
          {
            'label': 'التاريخ',
            'value': value(record, ['meal_date']),
          },
          {
            'label': 'الوقت',
            'value': value(record, ['meal_time']),
          },
        ];

      case 'medications':
        return [
          {
            'label': 'اسم الدواء',
            'value': value(
              record,
              ['medication_name'],
            ),
          },
          {
            'label': 'الجرعة',
            'value': value(
              record,
              ['dosage'],
            ),
          },
          {
            'label': 'التكرار',
            'value': value(
              record,
              ['frequency'],
            ),
          },
          {
            'label': 'تاريخ البداية',
            'value': value(
              record,
              ['start_date'],
            ),
          },
          {
            'label': 'تاريخ النهاية',
            'value': value(
              record,
              ['end_date'],
            ),
          },
        ];

      case 'activities':
        return [
          {
            'label': 'نوع النشاط',
            'value': value(
              record,
              ['activity_type', 'activity_name'],
            ),
          },
          {
            'label': 'المدة بالدقائق',
            'value': value(
              record,
              ['duration_minutes', 'duration'],
            ),
          },
          {
            'label': 'مستوى الشدة',
            'value': value(
              record,
              ['intensity'],
            ),
          },
          {
            'label': 'التاريخ والوقت',
            'value': value(
              record,
              ['activity_time', 'activity_date'],
            ),
          },
        ];

      case 'medical_exams':
        return [
          {
            'label': 'اسم الفحص',
            'value': value(
              record,
              ['exam_name'],
            ),
          },
          {
            'label': 'تاريخ الفحص',
            'value': value(
              record,
              ['exam_date'],
            ),
          },
          {
            'label': 'النتيجة',
            'value': value(
              record,
              ['result'],
            ),
          },
          if (optionalValue(record, ['notes']).isNotEmpty)
            {
              'label': 'ملاحظات',
              'value': optionalValue(record, ['notes']),
            },
        ];

      default:
        return [];
    }
  }

// =====================================================
// Records Section
// =====================================================

  Widget recordsSection({
    required String title,
    required String description,
    required String keyName,
    required IconData icon,
    required Color color,
  }) {
    final data = records(keyName);

    return card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 37,
                height: 37,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),

              SizedBox(width: 9),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: darkText,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      description,
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  '${data.length}',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: 10),

          Divider(height: 1),

          if (data.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 15),
              child: Center(
                child: Text(
                  'لا توجد سجلات خلال الفترة المحددة.',
                  style: TextStyle(
                    color: secondaryText,
                    fontSize: 12,
                  ),
                ),
              ),
            )
          else
            ...List.generate(data.length, (index) {
              final details = recordDetails(
                keyName,
                data[index],
              );

              return Column(
                crossAxisAlignment:
                CrossAxisAlignment.start,
                children: [
                  if (index > 0)
                    Divider(height: 20),

                  Padding(
                    padding: const EdgeInsets.only(top: 9),
                    child: Text(
                      'السجل ${index + 1}',
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),

                  SizedBox(height: 6),

                  ...details.map(
                        (item) => infoRow(
                      item['label']!,
                      item['value'],
                    ),
                  ),
                ],
              );
            }),
        ],
      ),
    );
  }

// =====================================================
// Main Screen
// =====================================================

  @override
  Widget build(BuildContext context) {
    final isTablet =
        MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 35 : 16,
              vertical: 12,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: 760,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () =>
                              Navigator.pop(context),
                          icon: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: darkText,
                            size: 19,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'التقرير الصحي الشامل',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: darkText,
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        SizedBox(width: 45),
                      ],
                    ),

                    SizedBox(height: 5),

                    Text(
                      'متابعة الحالة الصحية للطفل',
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 12,
                      ),
                    ),

                    SizedBox(height: 15),

                    reportHeaderCard(),

                    SizedBox(height: 18),

                    statisticsSection(),

                    SizedBox(height: 16),

                    glucoseSummary(),

                    SizedBox(height: 12),

                    glucoseChart(),

                    SizedBox(height: 20),

                    mealAnalysisSection(),

                    SizedBox(height: 20),

                    activitySection(),

                    SizedBox(height: 10),

                    medicationsSection(),

                    SizedBox(height: 17),

                    _SaveComprehensiveReportButton(
                      childId: childId,
                      childName: childName,
                      startDate: startDate,
                      endDate: endDate,
                      reportPayload: saveReportPayload,
                    ),

                    SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// زر حفظ التقرير الصحي الشامل في Laravel.
// يمنع تكرار الحفظ أثناء الطلب وبعد نجاحه.
class _SaveComprehensiveReportButton extends StatefulWidget {
  final int childId;
  final String childName;
  final DateTime startDate;
  final DateTime endDate;
  final Map<String, dynamic> reportPayload;

  const _SaveComprehensiveReportButton({
    required this.childId,
    required this.childName,
    required this.startDate,
    required this.endDate,
    required this.reportPayload,
  });

  @override
  State<_SaveComprehensiveReportButton> createState() =>
      _SaveComprehensiveReportButtonState();
}

class _SaveComprehensiveReportButtonState
    extends State<_SaveComprehensiveReportButton> {
  bool _isSaving = false;
  bool _isSaved = false;

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

  Future<void> _saveReport() async {
    if (_isSaving || _isSaved) return;

    final int childId = widget.childId;
    if (childId <= 0) {
      _showMessage(
        'تعذر تحديد الطفل. أغلقي التقرير وأنشئيه من جديد.',
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await ReportService.saveReport(
        childId: childId,
        reportType: 'comprehensive',
        startDate: widget.startDate,
        endDate: widget.endDate,
        title: 'التقرير الصحي الشامل',
        reportData: widget.reportPayload,
      );

      if (!mounted) return;

      setState(() => _isSaved = true);

// إظهار رسالة النجاح ثم الانتقال إلى التقارير المحفوظة.
      _showMessage('تم حفظ التقرير الصحي الشامل بنجاح.');

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => SavedReportsScreen(
            childId: widget.childId,
            childName: widget.childName,
            showSavedMessage: true,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 47,
      child: ElevatedButton.icon(
        onPressed: (_isSaving || _isSaved) ? null : _saveReport,
        icon: _isSaving
            ? SizedBox(
          width: 18,
          height: 18,
          child: const CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        )
            : Icon(
          _isSaved
              ? Icons.check_circle_outline_rounded
              : Icons.save_outlined,
          size: 19,
        ),
        label: Text(
          _isSaving
              ? 'جاري حفظ التقرير...'
              : _isSaved
              ? 'تم حفظ التقرير'
              : 'حفظ التقرير',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xff60C5C2),
          disabledBackgroundColor:
          const Color(0xff60C5C2).withValues(alpha: 0.72),
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(13),
          ),
        ),
      ),
    );
  }
}

// بيانات اليوم: المتوسط للرسم فقط، مع الاحتفاظ بكل القراءات الأصلية للتفاصيل.
class DailyGlucosePoint {
  final DateTime date;
  final double? average;
  final List<Map<String, dynamic>> readings;

  const DailyGlucosePoint({
    required this.date,
    required this.average,
    required this.readings,
  });
}

class _InteractiveGlucoseChart extends StatefulWidget {
  final List<DailyGlucosePoint> points;
  final int availablePoints;
  final Widget Function(DailyGlucosePoint point) buildSelectedDetails;
  final ValueChanged<DateTime?> onDaySelected;
  final DateTime? selectedDay;

  const _InteractiveGlucoseChart({
    required this.points,
    required this.availablePoints,
    required this.buildSelectedDetails,
    required this.onDaySelected,
    required this.selectedDay,
  });

  @override
  State<_InteractiveGlucoseChart> createState() =>
      _InteractiveGlucoseChartState();
}

class _InteractiveGlucoseChartState extends State<_InteractiveGlucoseChart> {
  int? selectedIndex;

  @override
  void didUpdateWidget(covariant _InteractiveGlucoseChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDay == null && oldWidget.selectedDay != null) {
      selectedIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xff1B2B35) : Colors.white;
    final textColor = isDark ? const Color(0xffEDF7F7) : const Color(0xff2C4A5A);
    final mutedColor = isDark ? const Color(0xffAEC5CB) : const Color(0xff78909A);
    final chartBorder = isDark ? const Color(0xff36505A) : const Color(0xffDDECEC);
    final points = widget.points;
    final selectedIsValid = selectedIndex != null &&
        selectedIndex! >= 0 &&
        selectedIndex! < points.length &&
        points[selectedIndex!].average != null;

    final painter = GlucoseChartPainter(
      points: points,
      selectedIndex: selectedIsValid ? selectedIndex : null,
      isDark: Theme.of(context).brightness == Brightness.dark,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: chartBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.show_chart_rounded,
                  color: Color(0xff60C5C2), size: 20),
              SizedBox(width: 7),
              Expanded(
                child: Text(
                  'متوسط قراءات السكر اليومية',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          if (widget.availablePoints == 0)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  'لا توجد قراءات كافية لعرض الرسم البياني.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: mutedColor,
                    fontSize: 12,
                  ),
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final chartSize = Size(constraints.maxWidth, 205);
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) {
                    final index = painter.indexAt(
                      details.localPosition,
                      chartSize,
                    );
                    if (index != null) {
                      setState(() => selectedIndex = index);
                      widget.onDaySelected(points[index].date);
                    }
                  },
                  child: SizedBox(
                    width: double.infinity,
                    height: chartSize.height,
                    child: CustomPaint(painter: painter),
                  ),
                );
              },
            ),
          SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.circle, color: Color(0xff60C5C2), size: 9),
              SizedBox(width: 6),
              Text(
                'متوسط السكر اليومي',
                style: TextStyle(
                  color: mutedColor,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          if (selectedIsValid) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  setState(() => selectedIndex = null);
                  widget.onDaySelected(null);
                },
                icon: Icon(Icons.refresh_rounded, size: 16),
                label: Text('عرض الفترة كاملة'),
              ),
            ),
            widget.buildSelectedDetails(points[selectedIndex!]),
          ],
        ],
      ),
    );
  }
}

// =====================================================
// Meal Analysis Donut Painter
// =====================================================

class MealAnalysisDonutPainter extends CustomPainter {
  final bool isDark;
  final int referenceCount;
  final int graceCount;
  final int outsideCount;

  MealAnalysisDonutPainter({
    required this.referenceCount,
    required this.graceCount,
    required this.outsideCount,
    this.isDark = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final total = referenceCount + graceCount + outsideCount;
    final rect = Offset.zero & size;
    const stroke = 15.0;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    canvas.drawArc(
      rect.deflate(stroke / 2),
      -1.5708,
      6.2832,
      false,
      paint..color = isDark ? const Color(0xff36505A) : const Color(0xffE8F0F0),
    );

    if (total == 0) return;

    final segments = <MapEntry<int, Color>>[
      MapEntry(referenceCount, const Color(0xff65C987)),
      MapEntry(graceCount, const Color(0xffF2B84B)),
      MapEntry(outsideCount, const Color(0xffEF7180)),
    ];

    var start = -1.5708;
    for (final segment in segments) {
      if (segment.key <= 0) continue;
      final sweep = 6.2832 * segment.key / total;
      canvas.drawArc(
        rect.deflate(stroke / 2),
        start,
        sweep,
        false,
        paint..color = segment.value,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant MealAnalysisDonutPainter oldDelegate) {
    return oldDelegate.referenceCount != referenceCount ||
        oldDelegate.graceCount != graceCount ||
        oldDelegate.outsideCount != outsideCount ||
        oldDelegate.isDark != isDark;
  }
}

// =====================================================
// Weekly Activity Bar Chart Painter
// =====================================================

class ActivityChartBucket {
  final String label;
  final double value;
  final List<String> activityNames;

  const ActivityChartBucket({
    required this.label,
    required this.value,
    this.activityNames = const [],
  });
}

class WeeklyActivityChartPainter extends CustomPainter {
  final List<ActivityChartBucket> data;
  final bool isDark;

  WeeklyActivityChartPainter({required this.data, this.isDark = false});

  static const Color barColor = Color(0xff60C5C2);
  Color get gridColor => isDark ? const Color(0xff36505A) : const Color(0xffE3EEEE);
  Color get labelColor => isDark ? const Color(0xffAEC5CB) : const Color(0xff78909A);
  Color get valueColor => isDark ? const Color(0xffEDF7F7) : const Color(0xff2C4A5A);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || size.width <= 0 || size.height <= 0) return;

    const left = 9.0;
    const right = 9.0;
    const top = 19.0;
    const bottom = 45.0;

    final chartWidth = size.width - left - right;
    final chartHeight = size.height - top - bottom;
    if (chartWidth <= 0 || chartHeight <= 0) return;

    final maxValue = data
        .map((item) => item.value)
        .reduce((a, b) => a > b ? a : b);
    final maxY = maxValue <= 0 ? 10.0 : maxValue * 1.18;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (int i = 0; i <= 3; i++) {
      final y = top + chartHeight * i / 3;
      canvas.drawLine(
        Offset(left, y),
        Offset(size.width - right, y),
        gridPaint,
      );
    }

    final slotWidth = chartWidth / data.length;
    final barWidth = (slotWidth * 0.34).clamp(8.0, 22.0).toDouble();

    final barPaint = Paint()
      ..color = barColor
      ..style = PaintingStyle.fill;

    final valueStyle = TextStyle(
      color: valueColor,
      fontSize: 9,
      fontWeight: FontWeight.w600,
    );

    final labelStyle = TextStyle(
      color: labelColor,
      fontSize: 8,
    );

    for (int i = 0; i < data.length; i++) {
      final item = data[i];
      final centerX = left + slotWidth * (i + 0.5);
      final barHeight = item.value <= 0
          ? 0.0
          : (item.value / maxY) * chartHeight;
      final barTop = top + chartHeight - barHeight;

      if (item.value > 0) {
        final rect = Rect.fromLTWH(
          centerX - barWidth / 2,
          barTop,
          barWidth,
          barHeight,
        );

        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          barPaint,
        );

        final valuePainter = TextPainter(
          text: TextSpan(
            text: item.value % 1 == 0
                ? item.value.toStringAsFixed(0)
                : item.value.toStringAsFixed(1),
            style: valueStyle,
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
          maxLines: 1,
        )..layout(maxWidth: slotWidth);

        final valueX = (centerX - valuePainter.width / 2)
            .clamp(0.0, size.width - valuePainter.width)
            .toDouble();

        valuePainter.paint(
          canvas,
          Offset(valueX, (barTop - 14).clamp(0.0, size.height)),
        );
      }

// التاريخ أسفل العمود.
      final datePainter = TextPainter(
        text: TextSpan(text: item.label, style: labelStyle),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
        maxLines: 1,
      )..layout(maxWidth: slotWidth - 2);

      final dateX = (centerX - datePainter.width / 2)
          .clamp(0.0, size.width - datePainter.width)
          .toDouble();

      datePainter.paint(canvas, Offset(dateX, size.height - 40));

// نوع النشاط بخط صغير جدًا حتى لا يزدحم الرسم.
      if (item.activityNames.isNotEmpty) {
        final namesText = item.activityNames.join('، ');
        final namesPainter = TextPainter(
          text: TextSpan(
            text: namesText,
            style: TextStyle(
              color: labelColor,
              fontSize: 5.8,
              height: 1.05,
            ),
          ),
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.center,
          maxLines: 2,
          ellipsis: '…',
        )..layout(maxWidth: slotWidth - 2);

        final namesX = (centerX - namesPainter.width / 2)
            .clamp(0.0, size.width - namesPainter.width)
            .toDouble();

        namesPainter.paint(canvas, Offset(namesX, size.height - 27));
      }
    }
  }

  @override
  bool shouldRepaint(covariant WeeklyActivityChartPainter oldDelegate) {
    if (oldDelegate.isDark != isDark) return true;
    if (oldDelegate.data.length != data.length) return true;

    for (int i = 0; i < data.length; i++) {
      if (oldDelegate.data[i].label != data[i].label ||
          oldDelegate.data[i].value != data[i].value ||
          oldDelegate.data[i].activityNames.join('|') !=
              data[i].activityNames.join('|')) {
        return true;
      }
    }

    return false;
  }
}


// =====================================================
// Glucose Chart Painter
// =====================================================

class GlucoseChartPainter extends CustomPainter {
  final List<DailyGlucosePoint> points;
  final int? selectedIndex;
  final bool isDark;

  GlucoseChartPainter({
    required this.points,
    this.selectedIndex,
    this.isDark = false,
  });

  static const Color primary = Color(0xff60C5C2);
  Color get gridColor => isDark ? const Color(0xff36505A) : const Color(0xffE5EEEE);
  Color get labelColor => isDark ? const Color(0xffAEC5CB) : const Color(0xff78909A);

  static const double left = 38;
  static const double right = 10;
  static const double top = 16;
  static const double bottom = 32;

  List<Offset?> _calculatePoints(Size size, double minY, double maxY) {
    final chartWidth = size.width - left - right;
    final chartHeight = size.height - top - bottom;
    final range = (maxY - minY).abs() < 0.001 ? 1.0 : maxY - minY;

    return List.generate(points.length, (index) {
      final average = points[index].average;
      if (average == null) return null;

      final x = points.length <= 1
          ? left + chartWidth / 2
          : left + chartWidth * index / (points.length - 1);
      final normalized = (average - minY) / range;
      final y = top + chartHeight - normalized * chartHeight;
      return Offset(x, y);
    });
  }

  int? indexAt(Offset position, Size size) {
    if (points.isEmpty) return null;

// يختار اليوم الأقرب أفقيًا؛ لا يلزم الضغط بدقة على خط الرسم نفسه.
    final chartWidth = size.width - left - right;
    if (chartWidth <= 0 || position.dx < left - 8 || position.dx > size.width - right + 8) {
      return null;
    }

    if (points.length == 1) {
      return points.first.average == null ? null : 0;
    }

    final normalized = ((position.dx - left) / chartWidth).clamp(0.0, 1.0);
    final index = (normalized * (points.length - 1)).round();
    if (index < 0 || index >= points.length) return null;
    return points[index].average == null ? null : index;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final values = points
        .map((point) => point.average)
        .whereType<double>()
        .toList();
    if (values.isEmpty) return;

    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final range = maxValue - minValue;
    final safeMin = minValue - (range * 0.25) - 5;
    final safeMax = maxValue + (range * 0.25) + 5;
    final safeRange = safeMax - safeMin;

    final chartWidth = size.width - left - right;
    final chartHeight = size.height - top - bottom;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (int i = 0; i < 4; i++) {
      final y = top + (chartHeight / 3) * i;
      canvas.drawLine(
        Offset(left, y),
        Offset(size.width - right, y),
        gridPaint,
      );

      final labelValue = safeMax - (safeRange / 3) * i;
      final label = TextPainter(
        text: TextSpan(
          text: labelValue.toStringAsFixed(0),
          style: TextStyle(color: labelColor, fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(0, y - 6));
    }

    final plottedPoints = _calculatePoints(size, safeMin, safeMax);
    final linePaint = Paint()
      ..color = primary
      ..strokeWidth = 2.3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    bool hasStarted = false;
    for (final point in plottedPoints) {
      if (point == null) {
        hasStarted = false;
        continue;
      }
      if (!hasStarted) {
        path.moveTo(point.dx, point.dy);
        hasStarted = true;
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(path, linePaint);

    for (int i = 0; i < plottedPoints.length; i++) {
      final point = plottedPoints[i];
      if (point == null) continue;

      if (selectedIndex == i) {
        canvas.drawCircle(
          point,
          9,
          Paint()
            ..color = primary.withOpacity(0.18)
            ..style = PaintingStyle.fill,
        );
      }

      canvas.drawCircle(point, 4.2, Paint()..color = primary);
      canvas.drawCircle(
        point,
        4.2,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3,
      );
    }

// تسمية التاريخ كل خمسة أيام، مع إظهار تاريخ آخر يوم عند الحاجة.
    for (int i = 0; i < points.length; i++) {
      final shouldShow = i % 5 == 0 || i == points.length - 1;
      if (!shouldShow) continue;

      final x = points.length <= 1
          ? left + chartWidth / 2
          : left + chartWidth * i / (points.length - 1);
      final date = points[i].date;
      final labelText =
          '${date.day.toString().padLeft(2, '0')}/'
          '${date.month.toString().padLeft(2, '0')}';

      final label = TextPainter(
        text: TextSpan(
          text: labelText,
          style: TextStyle(color: labelColor, fontSize: 8.5),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final labelX = (x - label.width / 2)
          .clamp(0.0, size.width - label.width)
          .toDouble();
      label.paint(canvas, Offset(labelX, size.height - 18));
    }
  }

  @override
  bool shouldRepaint(covariant GlucoseChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.isDark != isDark;
  }
}

