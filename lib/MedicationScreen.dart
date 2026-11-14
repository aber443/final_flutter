import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ChildStore.dart';
import 'services/medication_service.dart';

class MedicationScreen extends StatefulWidget {
  final String childName;
  final DateTime birthDate;
  final String gender;
  final String? childImagePath;

  const MedicationScreen({
    super.key,
    required this.childName,
    required this.birthDate,
    required this.gender,
    this.childImagePath,
  });

  @override
  State<MedicationScreen> createState() => _MedicationScreenState();
}

class _MedicationScreenState extends State<MedicationScreen> {
  final formKey = GlobalKey<FormState>();
  final doseController = TextEditingController();
  final otherMedicineController = TextEditingController();
  final otherMedicineFocusNode = FocusNode();
  final List<SavedMedication> savedMedications = [];

  static const medicines = ['Insulin', 'Metformin', 'Empagliflozin', 'أخرى'];
  static const insulinTypes = ['Short', 'Long', 'Mixed'];
  static const otherDoseUnits = ['UI', 'mg'];

  String? selectedMedicine;
  String? selectedInsulinType;
  String? selectedDoseUnit;
  TimeOfDay? selectedMedicationTime;
  int? editingMedicationId;

  bool isLoadingMedications = false;
  bool isSaving = false;
  String? medicationsError;

  int? get selectedChildId => ChildStore.instance.selectedChild?.id;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) loadMedications();
    });
  }

  String normalizeDoseUnit(String? value) {
    switch (value) {
      case 'U':
      case 'Ul':
      case 'UI':
      case 'IU':
        return 'IU';
      default:
        return value ?? '';
    }
  }

  String formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${time.period == DayPeriod.am ? 'ص' : 'م'}';
  }

  String formatApiTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute:00';
  }

  TimeOfDay? parseMedicationTime(dynamic raw) {
    // Laravel reminder_times is normally a JSON array of time strings.
    dynamic times = raw;
    if (times is String) {
      try {
        times = jsonDecode(times);
      } catch (_) {
        times = [times];
      }
    }
    if (times is! List || times.isEmpty) return null;
    final text = times.first.toString();
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch(text);
    if (match == null) return null;
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null || minute == null || hour > 23 || minute > 59) {
      return null;
    }
    return TimeOfDay(hour: hour, minute: minute);
  }

  SavedMedication medicationFromApi(Map<String, dynamic> data) {
    final name = data['medication_name']?.toString() ?? '';
    final medicineSelection =
    medicines.contains(name) && name != 'أخرى' ? name : 'أخرى';

    return SavedMedication(
      medicationId: int.tryParse(data['medication_id'].toString()),
      medicineSelection: medicineSelection,
      name: name,
      insulinType: data['insulin_type']?.toString(),
      dose: data['dosage']?.toString() ?? '',
      doseUnit: normalizeDoseUnit(data['dosage_unit']?.toString()),
      medicationTime: parseMedicationTime(data['reminder_times']),
    );
  }

  Future<void> loadMedications() async {
    final childId = selectedChildId;
    if (childId == null) {
      if (!mounted) return;
      setState(() {
        savedMedications.clear();
        medicationsError = 'يرجى اختيار طفل مسجل أولاً.';
        isLoadingMedications = false;
      });
      return;
    }

    setState(() {
      isLoadingMedications = true;
      medicationsError = null;
    });

    try {
      final medications = await MedicationService.getMedications(childId: childId);
      if (!mounted) return;
      final loadedMedications = medications.map(medicationFromApi).toList();
      setState(() {
        savedMedications
          ..clear()
          ..addAll(loadedMedications);
        isLoadingMedications = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        medicationsError = error.toString().replaceFirst('Exception: ', '');
        isLoadingMedications = false;
      });
    }
  }

  String? validateMedicineName(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'مطلوب';
    if (text.length < 2) return 'اسم الدواء قصير';
    if (text.length > 60) return 'اسم الدواء طويل';
    final regex = RegExp(r'^[A-Za-z\u0621-\u064A0-9 .\-]+$');
    if (!regex.hasMatch(text) || text.contains('  ')) {
      return 'اسم الدواء غير صحيح';
    }
    return null;
  }

  String? validateDose(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'مطلوب';
    final dose = double.tryParse(text);
    if (dose == null) return 'رقم غير صحيح';
    if (dose <= 0) return 'الجرعة غير صحيحة';
    if (dose > 9999) return 'تحقق من الجرعة';
    if (selectedMedicine == 'أخرى' && selectedDoseUnit == null) {
      return 'اختاري وحدة الجرعة';
    }
    return null;
  }

  void onMedicineChanged(String? value) {
    setState(() {
      selectedMedicine = value;
      selectedInsulinType = null;
      selectedDoseUnit = null;
      otherMedicineController.clear();
      if (value == 'Insulin') {
        selectedDoseUnit = 'UI';
      } else if (value == 'Metformin' || value == 'Empagliflozin') {
        selectedDoseUnit = 'mg';
      }
    });
    if (value == 'أخرى') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) otherMedicineFocusNode.requestFocus();
      });
    }
  }

  Future<void> selectMedicationTime() async {
    if (isSaving) return;
    final time = await showTimePicker(
      context: context,
      initialTime: selectedMedicationTime ?? TimeOfDay.now(),
      helpText: 'اختيار توقيت الدواء',
      cancelText: 'إلغاء',
      confirmText: 'اختيار',
    );
    if (time == null || !mounted) return;
    setState(() => selectedMedicationTime = time);
  }

  void editMedication(int index) {
    final medication = savedMedications[index];
    FocusScope.of(context).unfocus();
    setState(() {
      editingMedicationId = medication.medicationId;
      selectedMedicine = medication.medicineSelection;
      selectedInsulinType = medication.insulinType;
      otherMedicineController.text =
      medication.medicineSelection == 'أخرى' ? medication.name : '';
      doseController.text = medication.dose;
      selectedDoseUnit = medication.medicineSelection == 'Insulin'
          ? 'UI'
          : (medication.medicineSelection == 'Metformin' ||
          medication.medicineSelection == 'Empagliflozin')
          ? 'mg'
          : (medication.doseUnit.isEmpty ? null : medication.doseUnit);
      selectedMedicationTime = medication.medicationTime;
    });
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('يمكنك الآن تعديل بيانات الدواء', textAlign: TextAlign.center),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> saveMedication() async {
    if (isSaving) return;
    final childId = selectedChildId;
    if (childId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار طفل مسجل أولاً.', textAlign: TextAlign.center),
        ),
      );
      return;
    }

    FocusScope.of(context).unfocus();
    if (!(formKey.currentState?.validate() ?? false)) return;

    setState(() => isSaving = true);

    final medicineName = selectedMedicine == 'أخرى'
        ? otherMedicineController.text.trim()
        : selectedMedicine!;

    // IMPORTANT: Laravel must validate/store reminder_times as a JSON list.
    // start_date is intentionally not sent because it was removed from the UI.
    final medicationData = <String, dynamic>{
      'medication_name': medicineName,
      'insulin_type': selectedMedicine == 'Insulin' ? selectedInsulinType : null,
      'dosage': doseController.text.trim(),
      'dosage_unit': selectedDoseUnit,
      'reminder_times': [formatApiTime(selectedMedicationTime!)],
    };

    final isEditing = editingMedicationId != null;
    try {
      final Map<String, dynamic> responseMedication;
      if (isEditing) {
        responseMedication = await MedicationService.updateMedication(
          childId: childId,
          medicationId: editingMedicationId!,
          medicationData: medicationData,
        );
      } else {
        responseMedication = await MedicationService.addMedication(
          childId: childId,
          medicationData: medicationData,
        );
      }

      final savedMedication = medicationFromApi(responseMedication);
      if (!mounted) return;
      setState(() {
        if (isEditing) {
          final index = savedMedications.indexWhere(
                (item) => item.medicationId == editingMedicationId,
          );
          if (index != -1) {
            savedMedications[index] = savedMedication;
          } else {
            savedMedications.insert(0, savedMedication);
          }
        } else {
          savedMedications.insert(0, savedMedication);
        }
        isSaving = false;
        clearForm();
      });

      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditing ? 'تم تحديث بيانات الدواء بنجاح' : 'تم حفظ الدواء بنجاح',
            textAlign: TextAlign.center,
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Exception: ', ''),
            textAlign: TextAlign.center,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void clearForm() {
    doseController.clear();
    otherMedicineController.clear();
    selectedMedicine = null;
    selectedInsulinType = null;
    selectedDoseUnit = null;
    selectedMedicationTime = null;
    editingMedicationId = null;
    formKey.currentState?.reset();
    FocusScope.of(context).unfocus();
  }

  void cancelEditing() {
    setState(clearForm);
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم إلغاء التعديل', textAlign: TextAlign.center),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> deleteMedication(int index) async {
    if (isSaving) return;
    final childId = selectedChildId;
    final medication = savedMedications[index];
    final medicationId = medication.medicationId;
    if (childId == null || medicationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تعذر تحديد الطفل أو الدواء.', textAlign: TextAlign.center),
        ),
      );
      return;
    }

    setState(() => isSaving = true);
    try {
      await MedicationService.deleteMedication(
        childId: childId,
        medicationId: medicationId,
      );
      if (!mounted) return;
      setState(() {
        savedMedications.removeWhere((item) => item.medicationId == medicationId);
        if (editingMedicationId == medicationId) clearForm();
        isSaving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حذف ${medication.name} بنجاح', textAlign: TextAlign.center),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.toString().replaceFirst('Exception: ', ''),
            textAlign: TextAlign.center,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void dispose() {
    doseController.dispose();
    otherMedicineController.dispose();
    otherMedicineFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.primaryColor;
    final darkColor = theme.colorScheme.onSurface;
    final cardColor = theme.cardColor;
    final isDark = theme.brightness == Brightness.dark;
    final borderColor = isDark
        ? darkColor.withOpacity(0.14)
        : const Color(0xffD7E7E7);
    final hintColor = isDark
        ? darkColor.withOpacity(0.52)
        : const Color(0xff8A989D);

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final screenWidth = constraints.maxWidth;
            final screenHeight = constraints.maxHeight;
            final isVerySmall = screenWidth < 390;
            final isSmallScreen = screenWidth < 430 || screenHeight < 650;
            final isTablet = screenWidth >= 600;
            final horizontalPadding =
            isVerySmall ? 14.0 : (isTablet ? 36.0 : 20.0);

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
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Form(
                      key: formKey,
                      child: Column(
                        children: [
                          SizedBox(
                            height: 48,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Text(
                                  'تسجيل دواء',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: isVerySmall ? 18 : 22,
                                    fontWeight: FontWeight.bold,
                                    color: darkColor,
                                  ),
                                ),
                                Align(
                                  alignment: AlignmentDirectional.centerStart,
                                  child: IconButton(
                                    onPressed: isSaving ? null : () => Navigator.pop(context),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                                    icon: Icon(Icons.arrow_back_ios_new_rounded, color: darkColor, size: 22),
                                  ),
                                ),
                                Align(
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: SizedBox(
                                    height: 44,
                                    child: ElevatedButton(
                                      onPressed: isSaving ? null : saveMedication,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(horizontal: isVerySmall ? 12 : 18),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        elevation: 0,
                                      ),
                                      child: isSaving
                                          ? const SizedBox(
                                        width: 21,
                                        height: 21,
                                        child: CircularProgressIndicator(strokeWidth: 2.3, color: Colors.white),
                                      )
                                          : Text(
                                        editingMedicationId != null ? 'تحديث' : 'حفظ',
                                        style: TextStyle(fontSize: isVerySmall ? 14 : 16, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 30 : 40),
                          Row(
                            children: [
                              Icon(Icons.medication_liquid_rounded, color: primaryColor, size: 24),
                              const SizedBox(width: 7),
                              Text(
                                'الأدوية المسجلة',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkColor),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: borderColor, width: 1.2),
                            ),
                            child: isLoadingMedications && savedMedications.isEmpty
                                ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: Center(child: CircularProgressIndicator(color: primaryColor)),
                            )
                                : savedMedications.isEmpty
                                ? Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Column(
                                children: [
                                  Icon(Icons.medication_outlined, size: 36, color: hintColor),
                                  const SizedBox(height: 9),
                                  Text(
                                    'لا توجد أدوية مسجلة',
                                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: darkColor),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    medicationsError ?? 'سيظهر الدواء هنا بعد حفظه',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 12, color: hintColor),
                                  ),
                                ],
                              ),
                            )
                                : ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 260),
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const BouncingScrollPhysics(),
                                itemCount: savedMedications.length,
                                separatorBuilder: (context, index) => const SizedBox(height: 12),
                                itemBuilder: (context, index) => medicationRecordCard(
                                  medication: savedMedications[index],
                                  index: index,
                                  primaryColor: primaryColor,
                                  darkColor: darkColor,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: primaryColor.withOpacity(0.40), width: 1.4),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      editingMedicationId != null
                                          ? Icons.edit_outlined
                                          : Icons.add_circle_outline_rounded,
                                      color: primaryColor,
                                      size: 25,
                                    ),
                                    const SizedBox(width: 7),
                                    Expanded(
                                      child: Text(
                                        editingMedicationId != null ? 'تعديل بيانات الدواء' : 'إضافة دواء',
                                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkColor),
                                      ),
                                    ),
                                    if (editingMedicationId != null)
                                      TextButton(
                                        onPressed: isSaving ? null : cancelEditing,
                                        child: const Text('إلغاء التعديل'),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                _buildDropdown(
                                  value: selectedMedicine,
                                  values: medicines,
                                  hint: 'اسم الدواء',
                                  icon: Icons.medication_outlined,
                                  primaryColor: primaryColor,
                                  borderColor: borderColor,
                                  cardColor: cardColor,
                                  onChanged: onMedicineChanged,
                                ),
                                if (selectedMedicine == 'Insulin') ...[
                                  const SizedBox(height: 16),
                                  _buildDropdown(
                                    value: selectedInsulinType,
                                    values: insulinTypes,
                                    hint: 'نوع الأنسولين',
                                    icon: Icons.medication_liquid_outlined,
                                    primaryColor: primaryColor,
                                    borderColor: borderColor,
                                    cardColor: cardColor,
                                    onChanged: (value) => setState(() => selectedInsulinType = value),
                                  ),
                                ],
                                if (selectedMedicine == 'أخرى') ...[
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: otherMedicineController,
                                    focusNode: otherMedicineFocusNode,
                                    enabled: !isSaving,
                                    style: TextStyle(color: darkColor),
                                    textAlign: TextAlign.right,
                                    textInputAction: TextInputAction.next,
                                    autovalidateMode: AutovalidateMode.onUserInteraction,
                                    validator: validateMedicineName,
                                    decoration: medicationDecoration(
                                      icon: Icons.edit_note_rounded,
                                      hint: 'اكتب اسم الدواء',
                                      primaryColor: primaryColor,
                                      borderColor: borderColor,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                _responsivePair(
                                  isVerySmall: isVerySmall,
                                  first: TextFormField(
                                    controller: doseController,
                                    enabled: !isSaving,
                                    style: TextStyle(color: darkColor),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    textAlign: TextAlign.right,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.allow(RegExp(r'^\d{0,4}(\.\d{0,2})?')),
                                    ],
                                    validator: validateDose,
                                    autovalidateMode: AutovalidateMode.onUserInteraction,
                                    decoration: medicationDecoration(
                                      icon: Icons.vaccines_outlined,
                                      hint: 'الجرعة',
                                      primaryColor: primaryColor,
                                      borderColor: borderColor,
                                    ).copyWith(
                                      // Unit stays beside the typed dose, not in a separate field.
                                      suffixIcon: selectedMedicine == 'أخرى'
                                          ? PopupMenuButton<String>(
                                        tooltip: 'اختيار وحدة الجرعة',
                                        enabled: !isSaving,
                                        initialValue: selectedDoseUnit,
                                        onSelected: (unit) => setState(() => selectedDoseUnit = unit),
                                        itemBuilder: (_) => otherDoseUnits
                                            .map((unit) => PopupMenuItem(value: unit, child: Text(unit)))
                                            .toList(),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 8),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(selectedDoseUnit ?? 'الوحدة', style: TextStyle(color: primaryColor, fontSize: 12)),
                                              Icon(Icons.arrow_drop_down, color: primaryColor, size: 18),
                                            ],
                                          ),
                                        ),
                                      )
                                          : selectedDoseUnit == null
                                          ? null
                                          : Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        child: Center(
                                          widthFactor: 1,
                                          child: Text(
                                            selectedDoseUnit!,
                                            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  second: _buildMedicationTimeField(
                                    primaryColor: primaryColor,
                                    borderColor: borderColor,
                                    hintColor: hintColor,
                                    darkColor: darkColor,
                                  ),
                                ),
                             ]
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

  // Small rounded popup, matching the previously approved selector design.
  Future<String?> _showCompactMenu(
      BuildContext anchorContext,
      List<String> options,
      ) async {
    final box = anchorContext.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(anchorContext).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null) return null;
    final offset = box.localToGlobal(Offset.zero, ancestor: overlay);
    final width = box.size.width < 190.0 ? box.size.width : 190.0;
    final rect = Rect.fromLTWH(
      offset.dx + box.size.width - width,
      offset.dy + box.size.height + 4,
      width,
      0,
    );
    final theme = Theme.of(anchorContext);
    final scrollController = ScrollController();
    try {
      return await showMenu<String>(
        context: anchorContext,
        position: RelativeRect.fromRect(rect, Offset.zero & overlay.size),
        color: theme.cardColor,
        elevation: 5,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        constraints: BoxConstraints(minWidth: width, maxWidth: width, maxHeight: 220),
        items: [
          PopupMenuItem<String>(
            enabled: false,
            padding: EdgeInsets.zero,
            height: (options.length * 44.0).clamp(0.0, 200.0),
            child: SizedBox(
              width: width,
              height: (options.length * 44.0).clamp(0.0, 200.0),
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Scrollbar(
                  controller: scrollController,
                  thumbVisibility: options.length * 44.0 > 200,
                  trackVisibility: options.length * 44.0 > 200,
                  thickness: 6,
                  radius: const Radius.circular(8),
                  scrollbarOrientation: ScrollbarOrientation.left,
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.only(left: 12, right: 6),
                    itemCount: options.length,
                    itemBuilder: (itemContext, index) => InkWell(
                      onTap: () => Navigator.pop(itemContext, options[index]),
                      child: SizedBox(
                        height: 44,
                        child: Directionality(
                          textDirection: TextDirection.rtl,
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              child: Text(
                                options[index],
                                textAlign: TextAlign.right,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    } finally {
      // Let the closing menu finish its transition before releasing the controller.
      Future<void>.delayed(const Duration(milliseconds: 350), scrollController.dispose);
    }
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> values,
    required String hint,
    required IconData icon,
    required Color primaryColor,
    required Color borderColor,
    required Color cardColor,
    required ValueChanged<String?> onChanged,
  }) {
    return FormField<String>(
      key: ValueKey('$hint-$value'),
      initialValue: values.contains(value) ? value : null,
      validator: (current) => current == null ? 'مطلوب' : null,
      builder: (field) => Builder(
        builder: (anchorContext) => InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: isSaving
              ? null
              : () async {
            final selected = await _showCompactMenu(anchorContext, values);
            if (selected == null || !mounted) return;
            field.didChange(selected);
            onChanged(selected);
          },
          child: InputDecorator(
            isEmpty: field.value == null,
            decoration: medicationDecoration(
              icon: icon,
              hint: '',
              primaryColor: primaryColor,
              borderColor: borderColor,
            ).copyWith(errorText: field.errorText),
            child: Row(
              children: [
                Expanded(child: _RightText(field.value ?? hint, isHint: field.value == null)),
                Icon(Icons.keyboard_arrow_down_rounded, color: primaryColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _responsivePair({
    required bool isVerySmall,
    required Widget first,
    required Widget second,
  }) {
    if (isVerySmall) {
      return Column(children: [first, const SizedBox(height: 16), second]);
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

  Widget _buildMedicationTimeField({
    required Color primaryColor,
    required Color borderColor,
    required Color hintColor,
    required Color darkColor,
  }) {
    return FormField<TimeOfDay>(
      key: ValueKey('medication-time-${selectedMedicationTime?.hour}-${selectedMedicationTime?.minute}'),
      initialValue: selectedMedicationTime,
      validator: (value) => value == null ? 'مطلوب' : null,
      builder: (field) => InkWell(
        onTap: isSaving
            ? null
            : () async {
          await selectMedicationTime();
          if (mounted && selectedMedicationTime != null) {
            field.didChange(selectedMedicationTime);
          }
        },
        borderRadius: BorderRadius.circular(14),
        child: InputDecorator(
          decoration: medicationDecoration(
            icon: Icons.access_time_rounded,
            hint: '',
            primaryColor: primaryColor,
            borderColor: borderColor,
          ).copyWith(errorText: field.errorText),
          child: Text(
            field.value == null ? 'توقيت الدواء' : formatTime(field.value!),
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: field.value == null ? hintColor : darkColor,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget medicationRecordCard({
    required SavedMedication medication,
    required int index,
    required Color primaryColor,
    required Color darkColor,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondaryTextColor = isDark
        ? darkColor.withOpacity(0.65)
        : const Color(0xff6D7A80);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xff182326) : const Color(0xffFAFDFD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? darkColor.withOpacity(0.10) : const Color(0xffE3EEEE),
          width: 1.1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xff3B3020) : const Color(0xffFFF4E0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.medication_rounded, color: Color(0xffC87817), size: 26),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medication.name,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: darkColor),
                    ),
                    if (medication.insulinType != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        'نوع الأنسولين: ${medication.insulinType}',
                        style: TextStyle(fontSize: 12, color: secondaryTextColor),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      'الجرعة: ${medication.dose} ${medication.doseUnit}',
                      style: TextStyle(fontSize: 12, color: secondaryTextColor),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: isSaving ? null : () => editMedication(index),
                tooltip: 'تعديل بيانات الدواء',
                icon: const Icon(Icons.edit_outlined, color: Color(0xff419F98)),
              ),
              IconButton(
                onPressed: isSaving ? null : () => deleteMedication(index),
                tooltip: 'حذف الدواء',
                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xffC85C55)),
              ),
            ],
          ),
          if (medication.medicationTime != null) ...[
            const SizedBox(height: 11),
            medicationDetail(
              icon: Icons.access_time_rounded,
              text: 'التوقيت: ${formatTime(medication.medicationTime!)}',
              primaryColor: primaryColor,
            ),
          ],
        ],
      ),
    );
  }

  Widget medicationDetail({
    required IconData icon,
    required String text,
    required Color primaryColor,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark
        ? theme.colorScheme.onSurface.withOpacity(0.70)
        : const Color(0xff5C6E75);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xff202E31) : const Color(0xffF2F8F8),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: primaryColor),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(fontSize: 11, color: textColor, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  InputDecoration medicationDecoration({
    required IconData icon,
    required String hint,
    required Color primaryColor,
    required Color borderColor,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final hintColor = isDark
        ? theme.colorScheme.onSurface.withOpacity(0.52)
        : const Color(0xff8A989D);

    return InputDecoration(
      hintText: hint,
      hintTextDirection: TextDirection.rtl,
      hintStyle: TextStyle(color: hintColor, fontSize: 13),
      errorStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500),
      prefixIcon: Icon(icon, color: primaryColor, size: 22),
      filled: true,
      fillColor: theme.cardColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 11, vertical: 17),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: borderColor, width: 1.3),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 1.3),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }
}

class SavedMedication {
  final int? medicationId;
  final String medicineSelection;
  final String name;
  final String? insulinType;
  final String dose;
  final String doseUnit;
  final TimeOfDay? medicationTime;

  const SavedMedication({
    required this.medicationId,
    required this.medicineSelection,
    required this.name,
    required this.insulinType,
    required this.dose,
    required this.doseUnit,
    required this.medicationTime,
  });
}

class _RightText extends StatelessWidget {
  final String text;
  final bool isHint;

  const _RightText(this.text, {this.isHint = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isHint
        ? (isDark
        ? theme.colorScheme.onSurface.withOpacity(0.52)
        : const Color(0xff8A989D))
        : (isDark
        ? theme.colorScheme.onSurface
        : const Color(0xff2C4A5A));

    return SizedBox(
      width: double.infinity,
      child: Text(
        text,
        textAlign: TextAlign.right,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: textColor, fontSize: 14),
      ),
    );
  }
}
