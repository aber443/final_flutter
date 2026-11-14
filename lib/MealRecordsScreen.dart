import 'package:flutter/material.dart';

import 'ChildStore.dart';
import 'services/meal_service.dart';

class MealRecordsScreen extends StatefulWidget {
  const MealRecordsScreen({super.key});

  @override
  State<MealRecordsScreen> createState() => _MealRecordsScreenState();
}

class _MealRecordsScreenState extends State<MealRecordsScreen> {
  List<MealRecord> allRecords = [];
  bool isLoading = true;
  bool isDeleting = false;
  String? loadingError;

  @override
  void initState() {
    super.initState();
    loadRecords();
  }

  Future<void> loadRecords() async {
    final int? childId = ChildStore.instance.selectedChild?.id;
    if (childId == null) {
      if (!mounted) return;
      setState(() {
        allRecords = [];
        loadingError = 'يرجى اختيار طفل محفوظ في الحساب أولًا.';
        isLoading = false;
      });
      return;
    }

    setState(() {
      isLoading = true;
      loadingError = null;
    });

    try {
      final data = await MealService.getMeals(childId: childId);
      final records = data.map(MealRecord.fromJson).toList();
      if (!mounted) return;
      setState(() {
        allRecords = records;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loadingError = error.toString().replaceFirst('Exception: ', '');
        isLoading = false;
      });
    }
  }

  String formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  Future<void> confirmDelete(MealRecord record) async {
    if (isDeleting) return;

    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final textColor = theme.colorScheme.onSurface;
        final cardColor = theme.cardColor;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.delete_outline_rounded,
                    color: Colors.red,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'حذف السجل',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
            content: Text(
              'هل أنت متأكد من حذف سجل هذه الوجبة؟',
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: textColor.withOpacity(0.70),
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(
                  'إلغاء',
                  style: TextStyle(
                    color: textColor.withOpacity(0.65),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'نعم، حذف',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (shouldDelete == true && mounted) {
      await deleteRecord(record);
    }
  }

  Future<void> deleteRecord(MealRecord record) async {
    if (isDeleting) return;
    setState(() => isDeleting = true);
    try {
      await MealService.deleteMeal(mealId: record.id);
      if (!mounted) return;
      setState(() {
        allRecords.removeWhere((item) => item.id == record.id);
      });
      showMessage('تم حذف السجل بنجاح');
    } catch (error) {
      if (!mounted) return;
      showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => isDeleting = false);
    }
  }

  void showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, textAlign: TextAlign.center),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xff2C4A5A);
    final secondaryTextColor = isDark
        ? Colors.white.withOpacity(0.60)
        : const Color(0xff78909A);

    return Scaffold(
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final isVerySmall = width < 390;
              final isTablet = width >= 600;
              final horizontalPadding = isVerySmall ? 14.0 : (isTablet ? 36.0 : 20.0);

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 18,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 48,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Text(
                                'سجلات الوجبات',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: isTablet ? 31 : 27,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                              Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: IconButton(
                                  onPressed: () => Navigator.pop(context),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 44,
                                    minHeight: 44,
                                  ),
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
                        const SizedBox(height: 12),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            'عرض الوجبات التي تم تسجيلها سابقًا',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: secondaryTextColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'السجلات',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ),
                            if (!isLoading)
                              Text(
                                '${allRecords.length} سجل',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: secondaryTextColor,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (isLoading)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Center(
                              child: CircularProgressIndicator(color: theme.primaryColor),
                            ),
                          )
                        else if (loadingError != null)
                          Column(
                            children: [
                              Text(
                                loadingError!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: textColor),
                              ),
                              TextButton(
                                onPressed: loadRecords,
                                child: const Text('إعادة المحاولة'),
                              ),
                            ],
                          )
                        else if (allRecords.isEmpty)
                            _emptyState(context)
                          else
                            ...allRecords.asMap().entries.map((entry) {
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: entry.key == allRecords.length - 1 ? 0 : 12,
                                ),
                                child: _mealRecordCard(context, record: entry.value),
                              );
                            }),
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

  Widget _mealRecordCard(BuildContext context, {required MealRecord record}) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;
    final textColor = isDark ? Colors.white : const Color(0xff2C4A5A);
    final cardColor = isDark ? const Color(0xff1D292D) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.12)
        : const Color(0xffE2EEEE);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xff4F7D45).withOpacity(0.16)
                  : const Color(0xffEEF5EA),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.restaurant_rounded,
              color: Color(0xff4F7D45),
              size: 27,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.mealType,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  record.mealDetails,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: textColor.withOpacity(0.65),
                  ),
                ),
                const SizedBox(height: 7),
                Wrap(
                  spacing: 12,
                  runSpacing: 5,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.calendar_today_outlined,
                            size: 14, color: primaryColor),
                        const SizedBox(width: 4),
                        Text(
                          formatDate(record.date),
                          style: TextStyle(
                            fontSize: 11.5,
                            color: textColor.withOpacity(0.55),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time_rounded,
                            size: 14, color: primaryColor),
                        const SizedBox(width: 4),
                        Text(
                          record.time,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: textColor.withOpacity(0.55),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.red.withOpacity(isDark ? 0.12 : 0.08),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: isDeleting ? null : () => confirmDelete(record),
              borderRadius: BorderRadius.circular(12),
              child: const SizedBox(
                width: 42,
                height: 42,
                child: Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryColor = theme.primaryColor;
    final textColor = isDark ? Colors.white : const Color(0xff2C4A5A);
    final cardColor = isDark ? const Color(0xff1D292D) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withOpacity(0.12)
        : const Color(0xffE2EEEE);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Icon(Icons.restaurant_outlined, size: 38, color: primaryColor),
          const SizedBox(height: 12),
          Text(
            'لا توجد وجبات',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class MealRecord {
  final int id;
  final String mealType;
  final String mealDetails;
  final DateTime date;
  final String time;

  MealRecord({
    required this.id,
    required this.mealType,
    required this.mealDetails,
    required this.date,
    required this.time,
  });

  factory MealRecord.fromJson(Map<String, dynamic> json) {
    final id = int.tryParse(json['meal_id']?.toString() ?? '');
    final date = DateTime.tryParse(json['meal_date']?.toString() ?? '');
    if (id == null || date == null) {
      throw const FormatException('بيانات الوجبة غير مكتملة');
    }

    final ingredients = json['ingredients'];
    final foods = <String>[];
    if (ingredients is Map) {
      for (final group in ingredients.values) {
        if (group is List) {
          foods.addAll(group.map((item) => item.toString()));
        }
      }
    }

    final rawTime = json['meal_time']?.toString() ?? '';
    final parts = rawTime.split(':');
    String displayTime = rawTime;
    if (parts.length >= 2) {
      final hour = int.tryParse(parts[0]);
      if (hour != null && hour >= 0 && hour <= 23) {
        final displayHour = hour % 12 == 0 ? 12 : hour % 12;
        displayTime = '$displayHour:${parts[1]} ${hour < 12 ? 'ص' : 'م'}';
      }
    }

    return MealRecord(
      id: id,
      mealType: json['meal_type']?.toString() ?? '',
      mealDetails: foods.isEmpty ? 'لا توجد تفاصيل للأطعمة' : foods.join(' + '),
      date: date,
      time: displayTime,
    );
  }
}
