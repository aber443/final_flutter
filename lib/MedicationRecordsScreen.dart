import 'package:flutter/material.dart';

import 'ChildStore.dart';
import 'services/medication_service.dart';

// =====================================================
// ABEER - Medication Records Model
// =====================================================

class MedicationRecord {
  final int medicationId;
  final String medicationName;
  final String dose;
  final DateTime date;
  final String time;
  final String note;

  MedicationRecord({
    required this.medicationId,
    required this.medicationName,
    required this.dose,
    required this.date,
    required this.time,
    required this.note,
  });
}

// =====================================================
// ABEER - Medication Records Screen
// =====================================================

class MedicationRecordsScreen extends StatefulWidget {
  const MedicationRecordsScreen({super.key});

  @override
  State<MedicationRecordsScreen> createState() =>
      _MedicationRecordsScreenState();
}

class _MedicationRecordsScreenState
    extends State<MedicationRecordsScreen> {
  final List<MedicationRecord> allRecords = [];

  bool isLoading = true;
  bool isDeleting = false;
  String? errorMessage;

  int? get selectedChildId =>
      ChildStore.instance.selectedChild?.id;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      loadMedicationRecords();
    });
  }

  // =====================================================
  // ABEER - Load Medication Records From Laravel
  // =====================================================

  Future<void> loadMedicationRecords() async {
    final int? childId = selectedChildId;

    if (childId == null) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = 'يرجى اختيار طفل مسجل أولاً';
        allRecords.clear();
      });

      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
      allRecords.clear();
    });

    try {
      final List<dynamic> medications =
      await MedicationService.getMedications(
        childId: childId,
      );

      final List<MedicationRecord> loadedRecords = [];

      for (final item in medications) {
        if (item is! Map) continue;

        final Map<String, dynamic> data =
        Map<String, dynamic>.from(item);

        final int? medicationId = int.tryParse(
          data['medication_id'].toString(),
        );

        if (medicationId == null) continue;

        final String medicationName =
            data['medication_name']?.toString() ?? '';

        final String dosage =
            data['dosage']?.toString() ?? '';

        final String dosageUnit =
            data['dosage_unit']?.toString() ?? '';

        final String frequency =
            data['frequency']?.toString() ?? '';

        final String insulinType =
            data['insulin_type']?.toString() ?? '';

        final String startDateText =
            data['start_date']?.toString() ?? '';

        final DateTime startDate =
            DateTime.tryParse(startDateText) ??
                DateTime.now();

        // Laravel stores reminder_times as JSON.
        final dynamic reminderTimes =
        data['reminder_times'];

        String timeText = 'غير محدد';

        if (reminderTimes is List &&
            reminderTimes.isNotEmpty) {
          timeText = reminderTimes
              .map((time) => formatReminderTime(
            time.toString(),
          ))
              .join('، ');
        }

        String note = frequency;

        if (insulinType.isNotEmpty &&
            insulinType.toLowerCase() != 'null') {
          note = note.isEmpty
              ? 'نوع الإنسولين: $insulinType'
              : '$note • نوع الإنسولين: $insulinType';
        }

        if (note.isEmpty) {
          note = 'دواء مسجل';
        }

        loadedRecords.add(
          MedicationRecord(
            medicationId: medicationId,
            medicationName: medicationName,
            dose: '$dosage $dosageUnit'.trim(),
            date: startDate,
            time: timeText,
            note: note,
          ),
        );
      }

      if (!mounted) return;

      // Prevent showing records for another child
      // if the selected child changes during loading.
      if (selectedChildId != childId) {
        setState(() {
          isLoading = false;
          allRecords.clear();
          errorMessage =
          'تم تغيير الطفل، يرجى تحديث السجلات';
        });
        return;
      }

      setState(() {
        allRecords
          ..clear()
          ..addAll(loadedRecords);

        isLoading = false;
        errorMessage = null;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = error
            .toString()
            .replaceFirst('Exception: ', '');
      });
    }
  }

  // =====================================================
  // ABEER - Format Date
  // =====================================================

  String formatDate(DateTime date) {
    final String day =
    date.day.toString().padLeft(2, '0');

    final String month =
    date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  // =====================================================
  // ABEER - Format Reminder Time
  // =====================================================

  String formatReminderTime(String value) {
    final List<String> parts = value.split(':');

    if (parts.length < 2) return value;

    final int? hour24 = int.tryParse(parts[0]);
    final int? minute = int.tryParse(parts[1]);

    if (hour24 == null ||
        minute == null ||
        hour24 < 0 ||
        hour24 > 23 ||
        minute < 0 ||
        minute > 59) {
      return value;
    }

    final int hour12 = hour24 == 0
        ? 12
        : hour24 > 12
        ? hour24 - 12
        : hour24;

    final String minuteText =
    minute.toString().padLeft(2, '0');

    final String period =
    hour24 < 12 ? 'ص' : 'م';

    return '$hour12:$minuteText $period';
  }

  // =====================================================
  // ABEER - Confirm Delete
  // =====================================================

  Future<void> confirmDelete(
      MedicationRecord record,
      ) async {
    if (isDeleting) return;

    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final ThemeData theme =
        Theme.of(dialogContext);

        final bool isDark =
            theme.brightness == Brightness.dark;

        final Color textColor = isDark
            ? Colors.white
            : const Color(0xff2C4A5A);

        final Color cardColor = isDark
            ? const Color(0xff1D292D)
            : Colors.white;

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
              'سيتم حذف هذا الدواء نهائيًا من قاعدة البيانات ومن شاشة الأدوية أيضًا. هل أنت متأكد؟',
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
                onPressed: () {
                  Navigator.pop(dialogContext, false);
                },
                child: Text(
                  'إلغاء',
                  style: TextStyle(
                    color: textColor.withOpacity(0.65),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext, true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'نعم، حذف',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
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

  // =====================================================
  // ABEER - Delete Medication From Laravel
  // =====================================================

  Future<void> deleteRecord(
      MedicationRecord record,
      ) async {
    final int? childId = selectedChildId;

    if (childId == null) {
      showMessage('يرجى اختيار طفل مسجل أولاً');
      return;
    }

    setState(() {
      isDeleting = true;
    });

    try {
      await MedicationService.deleteMedication(
        childId: childId,
        medicationId: record.medicationId,
      );

      if (!mounted) return;

      setState(() {
        allRecords.removeWhere(
              (item) =>
          item.medicationId == record.medicationId,
        );

        isDeleting = false;
      });

      showMessage('تم حذف الدواء بنجاح');
    } catch (error) {
      if (!mounted) return;

      setState(() {
        isDeleting = false;
      });

      showMessage(
        error
            .toString()
            .replaceFirst('Exception: ', ''),
      );
    }
  }

  // =====================================================
  // ABEER - Show Message
  // =====================================================

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor:
        Theme.of(context).primaryColor,
      ),
    );
  }

  // =====================================================
  // ABEER - Build
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final bool isDark =
        theme.brightness == Brightness.dark;

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
              final double width =
                  constraints.maxWidth;

              final bool isVerySmall =
                  width < 390;

              final bool isTablet =
                  width >= 600;

              final double horizontalPadding =
              isVerySmall
                  ? 14
                  : isTablet
                  ? 36
                  : 20;

              return SingleChildScrollView(
                physics:
                const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 18,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints:
                    const BoxConstraints(
                      maxWidth: 760,
                    ),
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
                            alignment:
                            Alignment.center,
                            children: [
                              Center(
                                child: Text(
                                  'سجلات الأدوية',
                                  textAlign:
                                  TextAlign.center,
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
                                alignment:
                                AlignmentDirectional
                                    .centerStart,
                                child: IconButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  padding:
                                  EdgeInsets.zero,
                                  constraints:
                                  const BoxConstraints(
                                    minWidth: 44,
                                    minHeight: 44,
                                  ),
                                  splashRadius: 22,
                                  icon: Icon(
                                    Icons
                                        .arrow_back_ios_new_rounded,
                                    size: 22,
                                    color: textColor,
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
                            'عرض سجلات الأدوية التي تم تسجيلها سابقًا',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight:
                              FontWeight.w500,
                              color:
                              secondaryTextColor,
                            ),
                          ),
                        ),

                        const SizedBox(height: 22),

                        // =========================
                        // Records Header
                        // =========================

                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'السجلات',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight:
                                  FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ),

                            Text(
                              '${allRecords.length} سجل',
                              style: TextStyle(
                                fontSize: 12.5,
                                color:
                                secondaryTextColor,
                                fontWeight:
                                FontWeight.w500,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 12),

                        // =========================
                        // Medication Records
                        // =========================

                        if (isLoading)
                          const Padding(
                            padding:
                            EdgeInsets.symmetric(
                              vertical: 40,
                            ),
                            child: Center(
                              child:
                              CircularProgressIndicator(),
                            ),
                          )
                        else if (errorMessage != null)
                          _errorState(context)
                        else if (allRecords.isEmpty)
                            _emptyState(context)
                          else
                            ...allRecords
                                .asMap()
                                .entries
                                .map(
                                  (entry) {
                                final int index =
                                    entry.key;

                                final MedicationRecord
                                record =
                                    entry.value;

                                return Column(
                                  children: [
                                    _medicationRecordCard(
                                      context,
                                      record: record,
                                    ),

                                    if (index !=
                                        allRecords.length -
                                            1)
                                      const SizedBox(
                                        height: 12,
                                      ),
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

  // =====================================================
  // ABEER - Medication Record Card
  // =====================================================

  Widget _medicationRecordCard(
      BuildContext context, {
        required MedicationRecord record,
      }) {
    final ThemeData theme =
    Theme.of(context);

    final bool isDark =
        theme.brightness == Brightness.dark;

    final Color primaryColor =
        theme.primaryColor;

    final Color textColor = isDark
        ? Colors.white
        : const Color(0xff2C4A5A);

    final Color cardColor = isDark
        ? const Color(0xff1D292D)
        : Colors.white;

    final Color borderColor = isDark
        ? Colors.white.withOpacity(0.12)
        : const Color(0xffE2EEEE);

    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.all(16),
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
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xff7058A5)
                  .withOpacity(0.18)
                  : const Color(0xffF2EDFA),
              borderRadius:
              BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.medication_rounded,
              color: Color(0xff7058A5),
              size: 27,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
              CrossAxisAlignment.start,
              children: [
                Text(
                  record.medicationName,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight:
                    FontWeight.bold,
                    color: textColor,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  'الجرعة: ${record.dose}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: textColor
                        .withOpacity(0.65),
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  record.note,
                  style: TextStyle(
                    fontSize: 12,
                    color: textColor
                        .withOpacity(0.55),
                  ),
                ),

                const SizedBox(height: 7),

                Wrap(
                  spacing: 12,
                  runSpacing: 5,
                  children: [
                    Row(
                      mainAxisSize:
                      MainAxisSize.min,
                      children: [
                        Icon(
                          Icons
                              .calendar_today_outlined,
                          size: 14,
                          color: primaryColor,
                        ),

                        const SizedBox(
                          width: 4,
                        ),

                        Text(
                          formatDate(
                            record.date,
                          ),
                          style: TextStyle(
                            fontSize: 11.5,
                            color: textColor
                                .withOpacity(0.55),
                          ),
                        ),
                      ],
                    ),

                    Row(
                      mainAxisSize:
                      MainAxisSize.min,
                      children: [
                        Icon(
                          Icons
                              .access_time_rounded,
                          size: 14,
                          color: primaryColor,
                        ),

                        const SizedBox(
                          width: 4,
                        ),

                        Flexible(
                          child: Text(
                            record.time,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: textColor
                                  .withOpacity(0.55),
                            ),
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
            borderRadius:
            BorderRadius.circular(12),
            child: InkWell(
              onTap: isDeleting
                  ? null
                  : () =>
                  confirmDelete(record),
              borderRadius:
              BorderRadius.circular(12),
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

  // =====================================================
  // ABEER - Error State
  // =====================================================

  Widget _errorState(
      BuildContext context,
      ) {
    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 32,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
        BorderRadius.circular(18),
        border: Border.all(
          color:
          const Color(0xffE2EEEE),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.red,
            size: 38,
          ),

          const SizedBox(height: 12),

          Text(
            errorMessage ??
                'تعذر تحميل السجلات',
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 12),

          ElevatedButton(
            onPressed:
            loadMedicationRecords,
            child: const Text(
              'إعادة المحاولة',
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================
  // ABEER - Empty State
  // =====================================================

  Widget _emptyState(
      BuildContext context,
      ) {
    final ThemeData theme =
    Theme.of(context);

    final bool isDark =
        theme.brightness == Brightness.dark;

    final Color primaryColor =
        theme.primaryColor;

    final Color textColor = isDark
        ? Colors.white
        : const Color(0xff2C4A5A);

    final Color cardColor = isDark
        ? const Color(0xff1D292D)
        : Colors.white;

    final Color borderColor = isDark
        ? Colors.white.withOpacity(0.12)
        : const Color(0xffE2EEEE);

    return Container(
      width: double.infinity,
      padding:
      const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 32,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius:
        BorderRadius.circular(18),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.medication_outlined,
            size: 38,
            color: primaryColor,
          ),

          const SizedBox(height: 12),

          Text(
            'لا توجد سجلات أدوية',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight:
              FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}