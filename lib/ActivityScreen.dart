import 'dart:io';
import 'package:flutter/material.dart';
import 'validators.dart';
import 'ChildStore.dart';
import 'services/activity_service.dart';

class ActivityScreen extends StatefulWidget {
  final String childName;
  final DateTime birthDate;
  final String gender;
  final String? childImagePath;

  const ActivityScreen({
    super.key,
    required this.childName,
    required this.birthDate,
    required this.gender,
    this.childImagePath,
  });

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  GlobalKey<FormState> formKey = GlobalKey<FormState>();

  String? selectedActivity;
  String? selectedDuration;
  String? selectedIntensity;

  DateTime? activityDate;
  TimeOfDay? activityTime;

  final TextEditingController customActivityController =
  TextEditingController();

  final FocusNode customActivityFocusNode = FocusNode();

  // =====================================
  // Scroll Controllers للقوائم الثلاث
  // =====================================

  final ScrollController activityScrollController =
  ScrollController();

  final ScrollController durationScrollController =
  ScrollController();

  final ScrollController intensityScrollController =
  ScrollController();

  bool isOtherActivity = false;
  bool isSaving = false;

  String? dateError;
  String? timeError;

  // =====================================
  // Date Helpers
  // =====================================

  DateTime dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool isToday(DateTime date) {
    return dateOnly(date) == dateOnly(DateTime.now());
  }

  bool isFutureTimeToday() {
    if (activityDate == null ||
        activityTime == null ||
        !isToday(activityDate!)) {
      return false;
    }

    final DateTime now = DateTime.now();

    final DateTime selectedDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      activityTime!.hour,
      activityTime!.minute,
    );

    return selectedDateTime.isAfter(now);
  }

  String formatDate(DateTime? date) {
    if (date == null) {
      return '';
    }

    final String day =
    date.day.toString().padLeft(2, '0');

    final String month =
    date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year}';
  }

  String formatApiDate(DateTime date) {
    final String month =
    date.month.toString().padLeft(2, '0');

    final String day =
    date.day.toString().padLeft(2, '0');

    return '${date.year}-$month-$day';
  }

  String formatTime(TimeOfDay? time) {
    if (time == null) {
      return '';
    }

    final int hour =
    time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;

    final String minute =
    time.minute.toString().padLeft(2, '0');

    final String period =
    time.period == DayPeriod.am ? 'ص' : 'م';

    return '$hour:$minute $period';
  }

  String formatApiTime(TimeOfDay time) {
    final String hour =
    time.hour.toString().padLeft(2, '0');

    final String minute =
    time.minute.toString().padLeft(2, '0');

    return '$hour:$minute:00';
  }

  // =====================================
  // Select Activity Date
  // =====================================

  Future<void> selectActivityDate() async {
    final DateTime today = dateOnly(DateTime.now());
    final DateTime childBirthDate =
    dateOnly(widget.birthDate);

    DateTime initialDate = activityDate ?? today;

    if (initialDate.isBefore(childBirthDate)) {
      initialDate = childBirthDate;
    }

    if (initialDate.isAfter(today)) {
      initialDate = today;
    }

    final DateTime? selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: childBirthDate,
      lastDate: today,
      helpText: 'اختيار تاريخ النشاط',
      cancelText: 'إلغاء',
      confirmText: 'اختيار',
    );

    if (selectedDate == null) {
      return;
    }

    setState(() {
      activityDate = selectedDate;
      dateError = null;

      if (activityTime != null && isFutureTimeToday()) {
        activityTime = null;
        timeError = null;
      }
    });
  }

  // =====================================
  // Select Activity Time
  // =====================================

  Future<void> selectActivityTime() async {
    final TimeOfDay? selectedTime = await showTimePicker(
      context: context,
      initialTime: activityTime ?? TimeOfDay.now(),
      helpText: 'اختيار وقت النشاط',
      cancelText: 'إلغاء',
      confirmText: 'اختيار',
    );

    if (selectedTime == null) {
      return;
    }

    setState(() {
      activityTime = selectedTime;

      if (activityDate != null && isFutureTimeToday()) {
        timeError = 'لا يمكن اختيار وقت مستقبلي';
      } else {
        timeError = null;
      }
    });
  }

  // =====================================
  // Other Activity
  // =====================================

  void selectOtherActivity() {
    setState(() {
      selectedActivity = null;
      isOtherActivity = true;
      customActivityController.clear();
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        customActivityFocusNode.requestFocus();
      }
    });
  }

  void returnToActivityOptions() {
    FocusScope.of(context).unfocus();

    setState(() {
      selectedActivity = null;
      isOtherActivity = false;
      customActivityController.clear();
    });
  }

  String get finalActivityName {
    if (isOtherActivity) {
      return customActivityController.text.trim();
    }

    return selectedActivity ?? '';
  }

  // =====================================
  // Validation
  // =====================================

  bool validateDateAndTime() {
    setState(() {
      dateError = activityDate == null ? 'مطلوب' : null;

      if (activityTime == null) {
        timeError = 'مطلوب';
      } else if (isFutureTimeToday()) {
        timeError = 'لا يمكن اختيار وقت مستقبلي';
      } else {
        timeError = null;
      }
    });

    return dateError == null && timeError == null;
  }

  // =====================================
  // حفظ النشاط في Laravel
  // =====================================

  Future<void> saveActivity() async {
    if (isSaving) {
      return;
    }

    FocusScope.of(context).unfocus();

    final bool formIsValid =
        formKey.currentState?.validate() ?? false;

    final bool dateTimeValid = validateDateAndTime();

    if (!formIsValid || !dateTimeValid) {
      return;
    }

    final int? childId =
        ChildStore.instance.selectedChild?.id;

    if (childId == null) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'يرجى اختيار طفل محفوظ أولاً.',
            textAlign: TextAlign.center,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );

      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      await ActivityService.addActivity(
        childId: childId,
        activityName: finalActivityName,
        duration: selectedDuration!,
        intensity: selectedIntensity!,
        activityDate: formatApiDate(activityDate!),
        activityTime: formatApiTime(activityTime!),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        selectedActivity = null;
        isOtherActivity = false;
        customActivityController.clear();

        selectedDuration = null;
        selectedIntensity = null;

        activityDate = null;
        activityTime = null;

        dateError = null;
        timeError = null;

        formKey = GlobalKey<FormState>();
      });

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'تم حفظ النشاط بنجاح',
            textAlign: TextAlign.center,
          ),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).hideCurrentSnackBar();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Exception: ', ''),
            textAlign: TextAlign.center,
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
        ),
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
  // Dispose
  // =====================================

  @override
  void dispose() {
    customActivityController.dispose();
    customActivityFocusNode.dispose();

    activityScrollController.dispose();
    durationScrollController.dispose();
    intensityScrollController.dispose();

    super.dispose();
  }

  // =====================================
  // Main Screen
  // =====================================

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final Color primaryColor = theme.primaryColor;
    final Color darkColor = theme.colorScheme.onSurface;
    final Color cardColor = theme.cardColor;

    final Color borderColor =
    theme.brightness == Brightness.dark
        ? darkColor.withOpacity(0.14)
        : const Color(0xffD7E7E7);

    final Color hintColor =
    theme.brightness == Brightness.dark
        ? darkColor.withOpacity(0.52)
        : const Color(0xff8A989D);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double screenWidth = constraints.maxWidth;
            final double screenHeight = constraints.maxHeight;

            final bool isVerySmall = screenWidth < 390;

            final bool isSmallScreen =
                screenWidth < 430 || screenHeight < 650;

            final bool isTablet = screenWidth >= 600;

            final double horizontalPadding =
            isVerySmall
                ? 14
                : isTablet
                ? 36
                : 20;

            return Directionality(
              textDirection: TextDirection.rtl,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: isSmallScreen ? 12 : 16,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 720,
                    ),
                    child: Form(
                      key: formKey,
                      child: Column(
                        children: [
                          // =========================
                          // Header
                          // =========================

                          SizedBox(
                            height: 48,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Text(
                                  'تسجيل النشاط',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize:
                                    isVerySmall ? 18 : 22,
                                    fontWeight: FontWeight.bold,
                                    color: darkColor,
                                  ),
                                ),

                                Align(
                                  alignment:
                                  AlignmentDirectional.centerStart,
                                  child: IconButton(
                                    onPressed: isSaving
                                        ? null
                                        : () {
                                      Navigator.pop(context);
                                    },
                                    padding: EdgeInsets.zero,
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
                                  AlignmentDirectional.centerEnd,
                                  child: SizedBox(
                                    height: 44,
                                    child: ElevatedButton(
                                      onPressed: isSaving
                                          ? null
                                          : saveActivity,
                                      style:
                                      ElevatedButton.styleFrom(
                                        backgroundColor:
                                        primaryColor,
                                        foregroundColor:
                                        Colors.white,
                                        padding:
                                        EdgeInsets.symmetric(
                                          horizontal:
                                          isVerySmall ? 14 : 18,
                                        ),
                                        shape:
                                        RoundedRectangleBorder(
                                          borderRadius:
                                          BorderRadius.circular(12),
                                        ),
                                        elevation: 0,
                                      ),
                                      child: isSaving
                                          ? const SizedBox(
                                        width: 21,
                                        height: 21,
                                        child:
                                        CircularProgressIndicator(
                                          strokeWidth: 2.3,
                                          color: Colors.white,
                                        ),
                                      )
                                          : Text(
                                        'حفظ',
                                        style: TextStyle(
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
                            height: isSmallScreen ? 35 : 45,
                          ),

                          // =========================
                          // Section Title
                          // =========================

                          Row(
                            children: [
                              Icon(
                                Icons.directions_run_rounded,
                                color: primaryColor,
                                size: 24,
                              ),
                              const SizedBox(width: 7),
                              Text(
                                'بيانات النشاط',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: darkColor,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // =========================
                          // Activity + Duration
                          // =========================

                          _responsivePair(
                            isVerySmall: isVerySmall,
                            first: _activityField(
                              primaryColor: primaryColor,
                              borderColor: borderColor,
                              fieldColor: cardColor,
                              textColor: darkColor,
                              hintColor: hintColor,
                            ),
                            second: _durationField(
                              primaryColor: primaryColor,
                              borderColor: borderColor,
                              fieldColor: cardColor,
                              textColor: darkColor,
                              hintColor: hintColor,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // =========================
                          // Intensity + Date
                          // =========================

                          _responsivePair(
                            isVerySmall: isVerySmall,
                            first: _intensityField(
                              primaryColor: primaryColor,
                              borderColor: borderColor,
                              fieldColor: cardColor,
                              textColor: darkColor,
                              hintColor: hintColor,
                            ),
                            second: _dateField(
                              primaryColor: primaryColor,
                              borderColor: borderColor,
                              hintColor: hintColor,
                              darkColor: darkColor,
                              fieldColor: cardColor,
                            ),
                          ),

                          const SizedBox(height: 16),

                          // =========================
                          // Time
                          // =========================

                          _timeField(
                            primaryColor: primaryColor,
                            borderColor: borderColor,
                            hintColor: hintColor,
                            darkColor: darkColor,
                            fieldColor: cardColor,
                          ),

                          const SizedBox(height: 300),

                          // =========================
                          // Information Message
                          // =========================

                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 13,
                            ),
                            decoration: BoxDecoration(
                              color: theme.brightness ==
                                  Brightness.dark
                                  ? primaryColor.withOpacity(0.08)
                                  : const Color(0xffEEF7FA),
                              borderRadius:
                              BorderRadius.circular(13),
                            ),
                            child: Row(
                              mainAxisAlignment:
                              MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.info_outline_rounded,
                                  color: primaryColor,
                                  size: 20,
                                ),
                                const SizedBox(width: 7),
                                Flexible(
                                  child: Text(
                                    'يرجى التأكد من صحة البيانات قبل الحفظ',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: darkColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

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
  // Responsive Pair
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: 10),
        Expanded(child: second),
      ],
    );
  }

  // =====================================
  // Activity Field
  // =====================================

  Widget _activityField({
    required Color primaryColor,
    required Color borderColor,
    required Color fieldColor,
    required Color textColor,
    required Color hintColor,
  }) {
    // =====================================
    // نشاط آخر: حقل كتابة
    // =====================================

    if (isOtherActivity) {
      return TextFormField(
        controller: customActivityController,
        focusNode: customActivityFocusNode,
        enabled: !isSaving,
        autofocus: true,
        textAlign: TextAlign.right,
        style: TextStyle(color: textColor),
        autovalidateMode:
        AutovalidateMode.onUserInteraction,
        validator: (value) {
          return Validators.arabicText(
            value: value,
            minLength: 2,
            maxLength: 50,
          );
        },
        decoration: inputDecoration(
          icon: Icons.directions_run_rounded,
          borderColor: borderColor,
          primaryColor: primaryColor,
          errorText: null,
          fieldColor: fieldColor,
        ).copyWith(
          hintText: 'اكتب اسم النشاط',
          hintStyle: TextStyle(color: hintColor),
          hintTextDirection: TextDirection.rtl,
          suffixIcon: IconButton(
            tooltip: 'الرجوع للخيارات',
            onPressed:
            isSaving ? null : returnToActivityOptions,
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: textColor,
            ),
          ),
        ),
      );
    }

    // =====================================
    // نوع النشاط: القائمة الجديدة
    // =====================================

    return _buildPopupField(
      selectedValue: selectedActivity,
      hint: 'نوع النشاط',
      icon: Icons.directions_run_rounded,
      options: const [
        'المشي',
        'الجري',
        'السباحة',
        'ركوب الدراجة',
        'كرة القدم',
        'نشاط آخر',
      ],
      scrollController: activityScrollController,
      primaryColor: primaryColor,
      borderColor: borderColor,
      fieldColor: fieldColor,
      textColor: textColor,
      hintColor: hintColor,
      onSelected: (value) {
        if (value == 'نشاط آخر') {
          selectOtherActivity();
          return;
        }

        setState(() {
          selectedActivity = value;
        });
      },
    );
  }

  // =====================================
  // Duration Field
  // =====================================

  Widget _durationField({
    required Color primaryColor,
    required Color borderColor,
    required Color fieldColor,
    required Color textColor,
    required Color hintColor,
  }) {
    return _buildPopupField(
      selectedValue: selectedDuration,
      hint: 'مدة النشاط',
      icon: Icons.access_time_rounded,
      options: const [
        '15 دقيقة',
        '30 دقيقة',
        '45 دقيقة',
        'ساعة',
        'أكثر من ساعة',
      ],
      scrollController: durationScrollController,
      primaryColor: primaryColor,
      borderColor: borderColor,
      fieldColor: fieldColor,
      textColor: textColor,
      hintColor: hintColor,
      onSelected: (value) {
        setState(() {
          selectedDuration = value;
        });
      },
    );
  }

  // =====================================
  // Intensity Field
  // =====================================

  Widget _intensityField({
    required Color primaryColor,
    required Color borderColor,
    required Color fieldColor,
    required Color textColor,
    required Color hintColor,
  }) {
    return _buildPopupField(
      selectedValue: selectedIntensity,
      hint: 'شدة النشاط',
      icon: Icons.bar_chart_rounded,
      options: const [
        'خفيف',
        'متوسط',
        'شديد',
      ],
      scrollController: intensityScrollController,
      primaryColor: primaryColor,
      borderColor: borderColor,
      fieldColor: fieldColor,
      textColor: textColor,
      hintColor: hintColor,
      onSelected: (value) {
        setState(() {
          selectedIntensity = value;
        });
      },
    );
  }

  // =====================================
  // تصميم موحد للقوائم المنسدلة
  // =====================================

  Widget _buildPopupField({
    required String? selectedValue,
    required String hint,
    required IconData icon,
    required List<String> options,
    required ScrollController scrollController,
    required Color primaryColor,
    required Color borderColor,
    required Color fieldColor,
    required Color textColor,
    required Color hintColor,
    required ValueChanged<String> onSelected,
  }) {
    // القائمة قصيرة، وبحد أقصى 200 للخيارات.
    final double listHeight =
    (options.length * 44.0).clamp(0.0, 200.0);

    final bool needsScroll =
        options.length * 44.0 > 200.0;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: FormField<String>(
        initialValue: selectedValue,
        validator: (value) {
          return value == null ? 'مطلوب' : null;
        },
        builder: (field) {
          return PopupMenuButton<String>(
            enabled: !isSaving,
            tooltip: hint,

            // القائمة تظهر أسفل الحقل
            position: PopupMenuPosition.under,

            // نفس عرض قائمة المدن
            constraints: const BoxConstraints(
              minWidth: 190,
              maxWidth: 190,
              maxHeight: 220,
            ),

            color: fieldColor,
            elevation: 5,

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),

            // =====================================
            // اختيار العنصر
            // =====================================

            onSelected: (value) {
              field.didChange(value);
              onSelected(value);
            },

            // =====================================
            // القائمة القابلة للتمرير
            // =====================================

            itemBuilder: (menuContext) {
              return <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  enabled: false,
                  padding: EdgeInsets.zero,
                  height: listHeight,

                  child: SizedBox(
                    width: 190,
                    height: listHeight,

                    child: Directionality(
                      textDirection: TextDirection.ltr,

                      child: Scrollbar(
                        controller: scrollController,

                        // إظهار الشريط عندما تكون
                        // الخيارات أكثر من المساحة المتاحة
                        thumbVisibility: needsScroll,
                        trackVisibility: needsScroll,
                        interactive: needsScroll,

                        thickness: 6,

                        radius: const Radius.circular(8),

                        scrollbarOrientation:
                        ScrollbarOrientation.left,

                        child: ListView.builder(
                          controller: scrollController,

                          padding: const EdgeInsets.only(
                            left: 14,
                            right: 6,
                          ),

                          itemCount: options.length,

                          itemBuilder: (context, index) {
                            final String option =
                            options[index];

                            return InkWell(
                              onTap: () {
                                Navigator.pop(
                                  menuContext,
                                  option,
                                );
                              },

                              child: SizedBox(
                                height: 44,

                                child: Directionality(
                                  textDirection:
                                  TextDirection.rtl,

                                  child: Align(
                                    alignment:
                                    Alignment.centerRight,

                                    child: Padding(
                                      padding:
                                      const EdgeInsets.symmetric(
                                        horizontal: 10,
                                      ),

                                      child: Text(
                                        option,
                                        textAlign:
                                        TextAlign.right,
                                        overflow:
                                        TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: textColor,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ];
            },

            // =====================================
            // شكل الحقل الأصلي
            // =====================================

            child: InputDecorator(
              decoration: inputDecoration(
                icon: icon,
                borderColor: borderColor,
                primaryColor: primaryColor,
                errorText: field.errorText,
                fieldColor: fieldColor,
              ),

              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      selectedValue ?? hint,
                      textAlign: TextAlign.right,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selectedValue == null
                            ? hintColor
                            : textColor,
                        fontSize: 14,
                      ),
                    ),
                  ),

                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: primaryColor,
                    size: 22,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // =====================================
  // Date Field
  // =====================================

  Widget _dateField({
    required Color primaryColor,
    required Color borderColor,
    required Color hintColor,
    required Color darkColor,
    required Color fieldColor,
  }) {
    return InkWell(
      onTap: isSaving ? null : selectActivityDate,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: inputDecoration(
          icon: Icons.calendar_month_outlined,
          borderColor: borderColor,
          primaryColor: primaryColor,
          errorText: dateError,
          fieldColor: fieldColor,
        ),
        child: Text(
          activityDate == null
              ? 'تاريخ النشاط'
              : formatDate(activityDate),
          textAlign: TextAlign.right,
          style: TextStyle(
            color: activityDate == null
                ? hintColor
                : darkColor,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // =====================================
  // Time Field
  // =====================================

  Widget _timeField({
    required Color primaryColor,
    required Color borderColor,
    required Color hintColor,
    required Color darkColor,
    required Color fieldColor,
  }) {
    return InkWell(
      onTap: isSaving ? null : selectActivityTime,
      borderRadius: BorderRadius.circular(14),
      child: InputDecorator(
        decoration: inputDecoration(
          icon: Icons.access_time_rounded,
          borderColor: borderColor,
          primaryColor: primaryColor,
          errorText: timeError,
          fieldColor: fieldColor,
        ),
        child: Text(
          activityTime == null
              ? 'وقت النشاط'
              : formatTime(activityTime),
          textAlign: TextAlign.right,
          style: TextStyle(
            color: activityTime == null
                ? hintColor
                : darkColor,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // =====================================
  // Input Decoration
  // =====================================

  InputDecoration inputDecoration({
    required IconData icon,
    required Color borderColor,
    required Color primaryColor,
    required String? errorText,
    required Color fieldColor,
  }) {
    return InputDecoration(
      errorText: errorText,
      errorStyle: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: Icon(
        icon,
        color: primaryColor,
      ),
      filled: true,
      fillColor: fieldColor,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 17,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: borderColor,
          width: 1.3,
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
          width: 1.3,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Colors.red,
          width: 2,
        ),
      ),
    );
  }
}