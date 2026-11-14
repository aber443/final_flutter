import 'package:flutter/material.dart';

import 'ChildStore.dart';
import 'services/glucose_reading_service.dart';

class GlucoseRecordsScreen extends StatefulWidget {
  const GlucoseRecordsScreen({super.key});

  @override
  State<GlucoseRecordsScreen> createState() =>
      _GlucoseRecordsScreenState();
}

class _GlucoseRecordsScreenState extends State<GlucoseRecordsScreen> {
  List<GlucoseRecord> allRecords = [];
  bool isLoading = true;
  bool isDeleting = false;
  String? loadError;

  @override
  void initState() {
    super.initState();
    loadRecords();
  }

  String formatDate(DateTime date) {
    final String day = date.day.toString().padLeft(2, '0');
    final String month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }

  String formatTime(String rawTime) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(rawTime);
    if (match == null) return rawTime;

    final int? hour = int.tryParse(match.group(1)!);
    if (hour == null || hour > 23) return rawTime;

    final String minute = match.group(2)!;
    final int twelveHour = hour % 12 == 0 ? 12 : hour % 12;
    final String period = hour < 12 ? 'ص' : 'م';

    return '$twelveHour:$minute $period';
  }

  Future<void> loadRecords() async {
    final int? childId = ChildStore.instance.selectedChild?.id;

    if (childId == null) {
      if (!mounted) return;

      setState(() {
        allRecords = [];
        isLoading = false;
        loadError = 'يرجى اختيار طفل محفوظ في الحساب أولًا.';
      });
      return;
    }

    setState(() {
      isLoading = true;
      loadError = null;
    });

    try {
      final data =
      await GlucoseReadingService.getReadings(childId: childId);

      final records = data.map(GlucoseRecord.fromJson).toList();

      if (!mounted) return;

      setState(() {
        allRecords = records;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        loadError =
            error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> confirmDelete(GlucoseRecord record) async {
    if (isDeleting) return;

    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final ThemeData theme = Theme.of(dialogContext);
        final Color textColor = theme.colorScheme.onSurface;
        final Color cardColor = theme.cardColor;

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
              'هل أنت متأكد من حذف هذا السجل؟',
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: textColor.withOpacity(0.70),
              ),
            ),
            actionsPadding:
            const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, false),
                child: Text(
                  'إلغاء',
                  style: TextStyle(
                    color: textColor.withOpacity(0.65),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () =>
                    Navigator.pop(dialogContext, true),
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

    if (shouldDelete != true || !mounted) return;

    setState(() => isDeleting = true);

    try {
      await GlucoseReadingService.deleteReading(
        readingId: record.id,
      );

      if (!mounted) return;

      setState(() {
        allRecords.removeWhere(
              (item) => item.id == record.id,
        );
      });

      showMessage('تم حذف السجل بنجاح');
    } catch (error) {
      if (!mounted) return;

      showMessage(
        error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() => isDeleting = false);
      }
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            textAlign: TextAlign.center,
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).primaryColor,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final Color textColor =
    isDark ? Colors.white : const Color(0xff2C4A5A);

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
                    constraints:
                    const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment:
                      CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          height: 48,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Center(
                                child: Text(
                                  'قراءات السكر',
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
                                  padding: EdgeInsets.zero,
                                  constraints:
                                  const BoxConstraints(
                                    minWidth: 44,
                                    minHeight: 44,
                                  ),
                                  splashRadius: 22,
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
                          padding:
                          const EdgeInsets.symmetric(
                            horizontal: 6,
                          ),
                          child: Text(
                            'عرض القراءات التي تم تسجيلها سابقًا',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: secondaryTextColor,
                            ),
                          ),
                        ),

                        const SizedBox(height: 22),

                        // عنوان السجلات وعددها
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

                            if (!isLoading &&
                                loadError == null)
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
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(28),
                              child: CircularProgressIndicator(
                                color: theme.primaryColor,
                              ),
                            ),
                          )
                        else if (loadError != null)
                          _messageState(context, loadError!)
                        else if (allRecords.isEmpty)
                            _emptyState(context)
                          else
                            ...allRecords.asMap().entries.map(
                                  (entry) {
                                final int index = entry.key;
                                final GlucoseRecord record =
                                    entry.value;

                                return Column(
                                  children: [
                                    _glucoseRecordCard(
                                      context,
                                      record: record,
                                    ),
                                    if (index !=
                                        allRecords.length - 1)
                                      const SizedBox(height: 12),
                                  ],
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

  Widget _glucoseRecordCard(
      BuildContext context, {
        required GlucoseRecord record,
      }) {
    final ThemeData theme = Theme.of(context);
    final bool isDark =
        theme.brightness == Brightness.dark;

    final Color primaryColor = theme.primaryColor;

    final Color textColor =
    isDark ? Colors.white : const Color(0xff2C4A5A);

    final Color cardColor =
    isDark ? const Color(0xff1D292D) : Colors.white;

    final Color borderColor = isDark
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
                  ? const Color(0xffD95C49).withOpacity(0.14)
                  : const Color(0xffFCEDE8),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.water_drop_rounded,
              color: Color(0xffD95C49),
              size: 27,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      record.value.toString(),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Padding(
                      padding:
                      const EdgeInsets.only(bottom: 3),
                      child: Text(
                        'mg/dL',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: textColor.withOpacity(0.55),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 5),

                Text(
                  record.note,
                  style: TextStyle(
                    fontSize: 12.5,
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
                        Icon(
                          Icons.calendar_today_outlined,
                          size: 14,
                          color: primaryColor,
                        ),
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
                        Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formatTime(record.time),
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
            color: Colors.red.withOpacity(
              isDark ? 0.12 : 0.08,
            ),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: isDeleting
                  ? null
                  : () => confirmDelete(record),
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

  Widget _messageState(
      BuildContext context,
      String message,
      ) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 28,
      ),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 36,
            color: theme.primaryColor,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: loadRecords,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark =
        theme.brightness == Brightness.dark;

    final Color primaryColor = theme.primaryColor;

    final Color textColor =
    isDark ? Colors.white : const Color(0xff2C4A5A);

    final Color cardColor =
    isDark ? const Color(0xff1D292D) : Colors.white;

    final Color borderColor = isDark
        ? Colors.white.withOpacity(0.12)
        : const Color(0xffE2EEEE);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 32,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          Icon(
            Icons.water_drop_outlined,
            size: 38,
            color: primaryColor,
          ),
          const SizedBox(height: 12),
          Text(
            'لا توجد بيانات',
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

class GlucoseRecord {
  final int id;
  final num value;
  final DateTime date;
  final String time;
  final String note;

  const GlucoseRecord({
    required this.id,
    required this.value,
    required this.date,
    required this.time,
    required this.note,
  });

  factory GlucoseRecord.fromJson(
      Map<String, dynamic> json,
      ) {
    final dynamic idValue =
    json['glucose_reading_id'];

    final int? id = idValue is int
        ? idValue
        : int.tryParse(idValue?.toString() ?? '');

    final num? glucoseValue = num.tryParse(
      json['glucose_level']?.toString() ?? '',
    );

    final DateTime? date = DateTime.tryParse(
      json['reading_date']?.toString() ?? '',
    );

    if (id == null ||
        glucoseValue == null ||
        date == null) {
      throw const FormatException(
        'Invalid glucose reading data',
      );
    }

    return GlucoseRecord(
      id: id,
      value: glucoseValue,
      date: date,
      time: json['reading_time']?.toString() ?? '',
      note: json['reading_type']?.toString() ?? '',
    );
  }
}