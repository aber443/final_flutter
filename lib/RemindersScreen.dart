import 'package:flutter/material.dart';

import 'services/reminder_service.dart';

class RemindersScreen extends StatefulWidget {
  final String? childName;
  final DateTime? birthDate;
  final String? gender;
  final String? childImagePath;

  const RemindersScreen({
    super.key,
    this.childName,
    this.birthDate,
    this.gender,
    this.childImagePath,
  });

  @override
  State<RemindersScreen> createState() =>
      _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> {
  final GlobalKey<FormState> formKey =
  GlobalKey<FormState>();

  final TextEditingController reminderTypeController =
  TextEditingController();

  DateTime? reminderDate;
  TimeOfDay? reminderTime;

  String? reminderDateError;
  String? reminderTimeError;

  bool reminderEnabled = true;
  bool isSaving = false;
  bool isLoading = true;

  List<Map<String, dynamic>> reminders = [];

  @override
  void initState() {
    super.initState();
    loadReminders();
  }

  // =====================================
  // Date and time helpers
  // =====================================

  DateTime dateOnly(DateTime date) {
    return DateTime(
      date.year,
      date.month,
      date.day,
    );
  }

  bool isSameDay(DateTime first, DateTime second) {
    return first.year == second.year &&
        first.month == second.month &&
        first.day == second.day;
  }

  String formatDate(DateTime? date) {
    if (date == null) return '';

    final String day =
    date.day.toString().padLeft(2, '0');

    final String month =
    date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  String formatTime(TimeOfDay? time) {
    if (time == null) return '';

    final int hour =
    time.hourOfPeriod == 0
        ? 12
        : time.hourOfPeriod;

    final String minute =
    time.minute.toString().padLeft(2, '0');

    final String period =
    time.period == DayPeriod.am ? 'ص' : 'م';

    return '$hour:$minute $period';
  }

  DateTime buildReminderDateTime() {
    return DateTime(
      reminderDate!.year,
      reminderDate!.month,
      reminderDate!.day,
      reminderTime!.hour,
      reminderTime!.minute,
    );
  }

  DateTime? parseReminderDateTime(
      Map<String, dynamic> reminder,
      ) {
    final dynamic value = reminder['remind_at'];

    if (value == null) return null;

    final String dateText = value.toString();

    final DateTime? parsed =
    DateTime.tryParse(dateText);

    if (parsed == null) return null;

    // Laravel stores the reminder time as UTC.
    // Display it in the device's local timezone.
    //
    // ISO timestamps with Z are handled directly.
    // For timezone-less API values, interpret them
    // as UTC, matching the Laravel controller.
    if (parsed.isUtc) {
      return parsed.toLocal();
    }

    final bool hasTimezone =
    RegExp(
      r'(Z|[+-]\d{2}:\d{2})$',
      caseSensitive: false,
    ).hasMatch(dateText);

    if (hasTimezone) {
      return parsed.toLocal();
    }

    final DateTime utcDate = DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    );

    return utcDate.toLocal();
  }

  void sortReminders(
      List<Map<String, dynamic>> items,
      ) {
    items.sort((first, second) {
      final int firstId =
          int.tryParse(first['reminder_id']?.toString() ?? '') ?? 0;

      final int secondId =
          int.tryParse(second['reminder_id']?.toString() ?? '') ?? 0;

      return secondId.compareTo(firstId);
    });
  }

  String readableError(Object error) {
    final String message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
    }

    return message;
  }

  // =====================================
  // Validation
  // =====================================

  String? validateReminderType(String? value) {
    final String text = value?.trim() ?? '';

    if (text.isEmpty) {
      return 'مطلوب';
    }

    if (text.length < 2) {
      return 'نوع التذكير قصير';
    }

    if (text.length > 80) {
      return 'نوع التذكير طويل';
    }

    if (text.contains('  ')) {
      return 'النص غير صحيح';
    }

    return null;
  }

  bool validateDateAndTime() {
    reminderDateError =
    reminderDate == null ? 'مطلوب' : null;

    reminderTimeError =
    reminderTime == null ? 'مطلوب' : null;

    if (reminderDate != null &&
        reminderTime != null) {
      final DateTime selectedDateTime =
      buildReminderDateTime();

      if (!selectedDateTime.isAfter(DateTime.now())) {
        reminderTimeError = 'اختر وقتًا لاحقًا';
      }
    }

    setState(() {});

    return reminderDateError == null &&
        reminderTimeError == null;
  }

  // =====================================
  // Select reminder date
  // =====================================

  Future<void> selectReminderDate() async {
    if (isSaving || isLoading) return;

    final DateTime today =
    dateOnly(DateTime.now());

    DateTime initialDate =
        reminderDate ?? today;

    if (initialDate.isBefore(today)) {
      initialDate = today;
    }

    final DateTime lastDate = DateTime(
      today.year + 5,
      today.month,
      today.day,
    );

    final DateTime? selectedDate =
    await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: today,
      lastDate: lastDate,
      helpText: 'اختيار تاريخ التذكير',
      cancelText: 'إلغاء',
      confirmText: 'اختيار',
    );

    if (selectedDate == null || !mounted) {
      return;
    }

    setState(() {
      reminderDate = selectedDate;
      reminderDateError = null;
      reminderTimeError = null;

      if (reminderTime != null &&
          isSameDay(selectedDate, DateTime.now())) {
        final DateTime selectedDateTime = DateTime(
          selectedDate.year,
          selectedDate.month,
          selectedDate.day,
          reminderTime!.hour,
          reminderTime!.minute,
        );

        if (!selectedDateTime.isAfter(DateTime.now())) {
          reminderTime = null;
          reminderTimeError = 'اختر وقتًا لاحقًا';
        }
      }
    });
  }

  // =====================================
  // Select reminder time
  // =====================================

  Future<void> selectReminderTime() async {
    if (isSaving || isLoading) return;

    final TimeOfDay? selectedTime =
    await showTimePicker(
      context: context,
      initialTime:
      reminderTime ?? TimeOfDay.now(),
      helpText: 'اختيار وقت التذكير',
      cancelText: 'إلغاء',
      confirmText: 'اختيار',
    );

    if (selectedTime == null || !mounted) {
      return;
    }

    if (reminderDate != null &&
        isSameDay(reminderDate!, DateTime.now())) {
      final DateTime selectedDateTime = DateTime(
        reminderDate!.year,
        reminderDate!.month,
        reminderDate!.day,
        selectedTime.hour,
        selectedTime.minute,
      );

      if (!selectedDateTime.isAfter(DateTime.now())) {
        setState(() {
          reminderTime = null;
          reminderTimeError = 'اختر وقتًا لاحقًا';
        });

        return;
      }
    }

    setState(() {
      reminderTime = selectedTime;
      reminderTimeError = null;
    });
  }

  // =====================================
  // Load reminders from Laravel
  // GET /api/reminders
  // =====================================

  Future<void> loadReminders() async {
    if (mounted) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      final List<Map<String, dynamic>>
      loadedReminders =
      await ReminderService.getReminders();

      sortReminders(loadedReminders);

      if (!mounted) return;

      setState(() {
        reminders = loadedReminders;
        isLoading = false;
      });
    } catch (error) {
      debugPrint(
        'Load reminders error: $error',
      );

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      showTemporaryMessage(
        readableError(error),
      );
    }
  }

  // =====================================
  // Save reminder in Laravel
  // POST /api/reminders
  // =====================================

  Future<void> saveReminder() async {
    if (isSaving || isLoading) return;

    FocusScope.of(context).unfocus();

    final bool formIsValid =
        formKey.currentState?.validate() ?? false;

    final bool dateAndTimeValid =
    validateDateAndTime();

    if (!formIsValid || !dateAndTimeValid) {
      return;
    }

    final String title =
    reminderTypeController.text.trim();

    final DateTime selectedDateTime =
    buildReminderDateTime();

    setState(() {
      isSaving = true;
    });

    try {
      final Map<String, dynamic> savedReminder =
      await ReminderService.saveReminder(
        title: title,
        remindAt: selectedDateTime,
        isActive: reminderEnabled,
      );

      if (!mounted) return;

      final List<Map<String, dynamic>>
      updatedReminders = [
        ...reminders,
        savedReminder,
      ];

      sortReminders(updatedReminders);

      reminderTypeController.clear();
      formKey.currentState?.reset();

      setState(() {
        reminders = updatedReminders;

        reminderDate = null;
        reminderTime = null;

        reminderDateError = null;
        reminderTimeError = null;

        reminderEnabled = true;
        isSaving = false;
      });

      showTemporaryMessage(
        'تم حفظ التذكير بنجاح',
      );
    } catch (error) {
      debugPrint(
        'Save reminder error: $error',
      );

      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      showTemporaryMessage(
        readableError(error),
      );
    }
  }

  // =====================================
  // Delete reminder from Laravel
  // DELETE /api/reminders/{reminderId}
  // =====================================

  Future<void> deleteReminder(int reminderId) async {
    if (isSaving || isLoading) return;

    setState(() {
      isSaving = true;
    });

    try {
      final bool deleted =
      await ReminderService.deleteReminder(
        reminderId: reminderId,
      );

      if (!mounted) return;

      if (deleted) {
        setState(() {
          reminders.removeWhere((reminder) {
            return int.tryParse(
              reminder['reminder_id'].toString(),
            ) ==
                reminderId;
          });
        });

        showTemporaryMessage(
          'تم حذف التذكير بنجاح',
        );
      }
    } catch (error) {
      debugPrint(
        'Delete reminder error: $error',
      );

      if (!mounted) return;

      showTemporaryMessage(
        readableError(error),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  // =====================================
  // Messages
  // =====================================

  void showTemporaryMessage(String message) {
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
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    reminderTypeController.dispose();
    super.dispose();
  }

  // =====================================
  // Main interface
  // =====================================

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final bool isDark =
        theme.brightness == Brightness.dark;

    final Color primaryColor = theme.primaryColor;
    final Color darkColor =
        theme.colorScheme.onSurface;
    final Color cardColor = theme.cardColor;

    final Color borderColor = isDark
        ? darkColor.withOpacity(0.14)
        : const Color(0xffD7E7E7);

    final Color hintColor = isDark
        ? darkColor.withOpacity(0.52)
        : const Color(0xff8A989D);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double screenWidth =
                constraints.maxWidth;

            final double screenHeight =
                constraints.maxHeight;

            final bool isVerySmall =
                screenWidth < 390;

            final bool isSmallScreen =
                screenWidth < 430 ||
                    screenHeight < 650;

            final bool isTablet =
                screenWidth >= 600;

            final double horizontalPadding =
            isVerySmall
                ? 14
                : isTablet
                ? 36
                : 20;

            return Directionality(
              textDirection: TextDirection.rtl,
              child: SingleChildScrollView(
                physics:
                const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical:
                  isSmallScreen ? 12 : 16,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints:
                    const BoxConstraints(
                      maxWidth: 720,
                    ),
                    child: Form(
                      key: formKey,
                      child: Column(
                        children: [
                          // =====================
                          // Header
                          // =====================

                          SizedBox(
                            height: 48,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Text(
                                  'إضافة تذكير',
                                  textAlign:
                                  TextAlign.center,
                                  style: TextStyle(
                                    fontSize:
                                    isVerySmall
                                        ? 18
                                        : 22,
                                    fontWeight:
                                    FontWeight.bold,
                                    color: darkColor,
                                  ),
                                ),

                                Align(
                                  alignment:
                                  AlignmentDirectional
                                      .centerStart,
                                  child: IconButton(
                                    onPressed:
                                    isSaving
                                        ? null
                                        : () =>
                                        Navigator.pop(
                                          context,
                                        ),
                                    padding:
                                    EdgeInsets.zero,
                                    constraints:
                                    const BoxConstraints(
                                      minWidth: 44,
                                      minHeight: 44,
                                    ),
                                    icon: Icon(
                                      Icons
                                          .arrow_back_ios_new_rounded,
                                      color: darkColor,
                                      size: 22,
                                    ),
                                  ),
                                ),

                                Align(
                                  alignment:
                                  AlignmentDirectional
                                      .centerEnd,
                                  child: SizedBox(
                                    height: 44,
                                    child: ElevatedButton(
                                      onPressed:
                                      isSaving ||
                                          isLoading
                                          ? null
                                          : saveReminder,
                                      style:
                                      ElevatedButton
                                          .styleFrom(
                                        backgroundColor:
                                        primaryColor,
                                        foregroundColor:
                                        Colors.white,
                                        elevation: 0,
                                        padding:
                                        EdgeInsets.symmetric(
                                          horizontal:
                                          isVerySmall
                                              ? 14
                                              : 18,
                                        ),
                                        shape:
                                        RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius
                                              .circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                      child: isSaving
                                          ? const SizedBox(
                                        width: 21,
                                        height: 21,
                                        child:
                                        CircularProgressIndicator(
                                          strokeWidth:
                                          2.3,
                                          color:
                                          Colors.white,
                                        ),
                                      )
                                          : Text(
                                        'حفظ',
                                        style:
                                        TextStyle(
                                          fontSize:
                                          isVerySmall
                                              ? 14
                                              : 16,
                                          fontWeight:
                                          FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(
                            height:
                            isSmallScreen
                                ? 26
                                : 34,
                          ),

                          // =====================
                          // Reminder title
                          // =====================

                          Row(
                            children: [
                              Icon(
                                Icons
                                    .notifications_none_rounded,
                                color: primaryColor,
                                size: 25,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                'بيانات التذكير',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight:
                                  FontWeight.bold,
                                  color: darkColor,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 18),

                          // =====================
                          // Reminder type
                          // =====================

                          TextFormField(
                            controller:
                            reminderTypeController,
                            enabled:
                            !isSaving && !isLoading,
                            style:
                            TextStyle(color: darkColor),
                            textAlign: TextAlign.right,
                            keyboardType:
                            TextInputType.text,
                            textInputAction:
                            TextInputAction.done,
                            autovalidateMode:
                            AutovalidateMode
                                .onUserInteraction,
                            validator:
                            validateReminderType,
                            decoration:
                            reminderInputDecoration(
                              label: 'نوع التذكير',
                              hint:
                              'مثال: موعد طبي أو تناول الدواء',
                              icon: Icons
                                  .edit_notifications_outlined,
                              primaryColor:
                              primaryColor,
                              borderColor:
                              borderColor,
                              hintColor: hintColor,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // =====================
                          // Date and time
                          // =====================

                          _responsivePair(
                            isVerySmall: isVerySmall,
                            first:
                            _buildReminderDateField(
                              primaryColor:
                              primaryColor,
                              borderColor:
                              borderColor,
                              hintColor: hintColor,
                              darkColor: darkColor,
                            ),
                            second:
                            _buildReminderTimeField(
                              primaryColor:
                              primaryColor,
                              borderColor:
                              borderColor,
                              hintColor: hintColor,
                              darkColor: darkColor,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // =====================
                          // Reminder switch
                          // =====================

                          Container(
                            width: double.infinity,
                            padding:
                            const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius:
                              BorderRadius.circular(
                                14,
                              ),
                              border: Border.all(
                                color: borderColor,
                                width: 1.3,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons
                                      .notifications_none_rounded,
                                  color: primaryColor,
                                  size: 23,
                                ),

                                const SizedBox(width: 8),

                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,
                                    children: [
                                      Text(
                                        'تفعيل التذكير',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight:
                                          FontWeight.bold,
                                          color:
                                          darkColor,
                                        ),
                                      ),
                                      const SizedBox(
                                        height: 2,
                                      ),
                                      Text(
                                        reminderEnabled
                                            ? 'التذكير مفعّل'
                                            : 'التذكير غير مفعّل',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color:
                                          hintColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                Switch(
                                  value:
                                  reminderEnabled,
                                  activeColor:
                                  primaryColor,
                                  onChanged:
                                  isSaving ||
                                      isLoading
                                      ? null
                                      : (value) {
                                    setState(
                                          () {
                                        reminderEnabled =
                                            value;
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),


                          const SizedBox(height: 25),

                          // =====================
                          // Saved reminders
                          // =====================

                          Row(
                            children: [
                              Icon(
                                Icons.list_alt_rounded,
                                color: primaryColor,
                                size: 25,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                'التذكيرات المضافة',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight:
                                  FontWeight.bold,
                                  color: darkColor,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 14),

                          if (isLoading)
                            Padding(
                              padding:
                              const EdgeInsets.all(
                                24,
                              ),
                              child:
                              CircularProgressIndicator(
                                color: primaryColor,
                              ),
                            )
                          else if (reminders.isEmpty)
                            Container(
                              width: double.infinity,
                              padding:
                              const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 22,
                              ),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius:
                                BorderRadius.circular(
                                  14,
                                ),
                                border: Border.all(
                                  color: borderColor,
                                  width: 1.3,
                                ),
                              ),
                              child: Text(
                                'لا توجد تذكيرات مضافة حتى الآن',
                                textAlign:
                                TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: hintColor,
                                ),
                              ),
                            )
                          else
                            ...reminders.map((reminder) {
                              final DateTime? dateTime =
                              parseReminderDateTime(
                                reminder,
                              );

                              final bool isActive =
                                  reminder['is_active'] ==
                                      true ||
                                      reminder['is_active'] ==
                                          1;

                              final int? reminderId =
                              int.tryParse(
                                reminder['reminder_id']
                                    ?.toString() ??
                                    '',
                              );

                              return Container(
                                width: double.infinity,
                                margin:
                                const EdgeInsets.only(
                                  bottom: 12,
                                ),
                                padding:
                                const EdgeInsets.all(
                                  14,
                                ),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius:
                                  BorderRadius.circular(
                                    14,
                                  ),
                                  border: Border.all(
                                    color: borderColor,
                                    width: 1.3,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons
                                          .notifications_outlined,
                                      color:
                                      primaryColor,
                                      size: 26,
                                    ),

                                    const SizedBox(
                                      width: 10,
                                    ),

                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                        CrossAxisAlignment
                                            .start,
                                        children: [
                                          Text(
                                            reminder['title']
                                                ?.toString() ??
                                                '',
                                            style:
                                            TextStyle(
                                              fontSize:
                                              14,
                                              fontWeight:
                                              FontWeight.bold,
                                              color:
                                              darkColor,
                                            ),
                                          ),

                                          const SizedBox(
                                            height: 5,
                                          ),

                                          if (dateTime !=
                                              null)
                                            Text(
                                              '${formatDate(dateTime)} - '
                                                  '${formatTime(TimeOfDay.fromDateTime(dateTime))}',
                                              style:
                                              TextStyle(
                                                fontSize:
                                                12,
                                                color:
                                                hintColor,
                                              ),
                                            ),

                                          const SizedBox(
                                            height: 5,
                                          ),

                                          Text(
                                            isActive
                                                ? 'مفعّل'
                                                : 'غير مفعّل',
                                            style:
                                            TextStyle(
                                              fontSize:
                                              12,
                                              color:
                                              isActive
                                                  ? primaryColor
                                                  : hintColor,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    IconButton(
                                      onPressed:
                                      isSaving ||
                                          reminderId ==
                                              null
                                          ? null
                                          : () =>
                                          deleteReminder(
                                            reminderId,
                                          ),
                                      tooltip:
                                      'حذف التذكير',
                                      icon:
                                      const Icon(
                                        Icons
                                            .delete_outline_rounded,
                                        color: Color(
                                          0xffC85C55,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),

                          const SizedBox(height: 25),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // =====================================
  // Responsive date/time fields
  // =====================================

  Widget _responsivePair({
    required bool isVerySmall,
    required Widget first,
    required Widget second,
  }) {
    if (isVerySmall) {
      return Column(
        children: [
          first,
          const SizedBox(height: 16),
          second,
        ],
      );
    }

    return Row(
      crossAxisAlignment:
      CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: 10),
        Expanded(child: second),
      ],
    );
  }

  // =====================================
  // Reminder date field
  // =====================================

  Widget _buildReminderDateField({
    required Color primaryColor,
    required Color borderColor,
    required Color hintColor,
    required Color darkColor,
  }) {
    return InkWell(
      onTap:
      isSaving || isLoading
          ? null
          : selectReminderDate,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: reminderInputDecoration(
          label: 'تاريخ التذكير',
          hint: '',
          icon: Icons.calendar_month_outlined,
          errorText: reminderDateError,
          primaryColor: primaryColor,
          borderColor: borderColor,
          hintColor: hintColor,
        ),
        child: Text(
          reminderDate == null
              ? 'اختر تاريخ التذكير'
              : formatDate(reminderDate),
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 13,
            color: reminderDate == null
                ? hintColor
                : darkColor,
          ),
        ),
      ),
    );
  }

  // =====================================
  // Reminder time field
  // =====================================

  Widget _buildReminderTimeField({
    required Color primaryColor,
    required Color borderColor,
    required Color hintColor,
    required Color darkColor,
  }) {
    return InkWell(
      onTap:
      isSaving || isLoading
          ? null
          : selectReminderTime,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: reminderInputDecoration(
          label: 'وقت التذكير',
          hint: '',
          icon: Icons.access_time_rounded,
          errorText: reminderTimeError,
          primaryColor: primaryColor,
          borderColor: borderColor,
          hintColor: hintColor,
        ),
        child: Text(
          reminderTime == null
              ? 'اختر وقت التذكير'
              : formatTime(reminderTime),
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 13,
            color: reminderTime == null
                ? hintColor
                : darkColor,
          ),
        ),
      ),
    );
  }

  // =====================================
  // Input decoration
  // =====================================

  InputDecoration reminderInputDecoration({
    required String label,
    required String hint,
    required IconData icon,
    required Color primaryColor,
    required Color borderColor,
    required Color hintColor,
    String? errorText,
  }) {
    final ThemeData theme = Theme.of(context);

    final bool isDark =
        theme.brightness == Brightness.dark;

    final Color textColor =
        theme.colorScheme.onSurface;

    final Color labelColor = isDark
        ? textColor.withOpacity(0.70)
        : const Color(0xff6F8086);

    return InputDecoration(
      labelText: label,
      hintText: hint,
      hintTextDirection: TextDirection.rtl,
      floatingLabelBehavior:
      FloatingLabelBehavior.auto,
      labelStyle: TextStyle(
        color: labelColor,
        fontSize: 13,
      ),
      floatingLabelStyle: TextStyle(
        color: primaryColor,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      hintStyle: TextStyle(
        color: hintColor,
        fontSize: 12,
      ),
      errorText: errorText,
      errorStyle: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Icon(
        icon,
        color: primaryColor,
        size: 22,
      ),
      filled: true,
      fillColor: theme.cardColor,
      contentPadding:
      const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 17,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(14),
        borderSide: BorderSide(
          color: borderColor,
          width: 1.3,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(14),
        borderSide: BorderSide(
          color: primaryColor,
          width: 2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 1.3,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius:
        BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 2,
        ),
      ),
    );
  }
}