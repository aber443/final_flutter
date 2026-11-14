import 'dart:io';
import 'package:flutter/material.dart';
import 'main.dart' show notificationUpdateNotifier;

import 'ReportsScreen.dart';
import 'ActivityScreen.dart';
import 'MealScreen.dart';
import 'MedicationScreen.dart';
import 'MedicalExamScreen.dart';
import 'GlucoseReadingScreen.dart';
import 'RemindersScreen.dart';
import 'ProfileScreen.dart';
import 'NotificationScreen.dart';
import 'RecordsScreen.dart';
import 'ChildStore.dart';
import 'services/notification_service.dart';

enum HomeAction {
  activity,
  meals,
  glucose,
  medication,
  medicalExam,
  reminders,
}

class HomeScreen extends StatefulWidget {
  final String childName;
  final String guardianName;
  final DateTime birthDate;
  final bool showBottomNavigationBar;
  final String gender;
  final String? childImagePath;

  const HomeScreen({
    super.key,
    this.guardianName = '',
    required this.childName,
    required this.birthDate,
    required this.gender,
    this.childImagePath,
    this.showBottomNavigationBar = true,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool dailyHealthExpanded = true;
  bool treatmentExpanded = true;
  bool medicalFollowUpExpanded = true;

  String? currentChildImagePath;

  // =====================================
  // Notification Status
  // =====================================

  bool hasUnreadNotifications = false;

  @override
  void initState() {
    super.initState();

    currentChildImagePath = widget.childImagePath;

    ChildStore.instance.addListener(_onChildChanged);

    // تحميل حالة الإشعارات من Laravel
    loadUnreadNotificationStatus();
    // تحديث النقطة الخضراء عند وصول إشعار Firebase
    notificationUpdateNotifier.addListener(loadUnreadNotificationStatus);
  }

  // =====================================
  // Load Unread Notifications From Laravel
  // =====================================

  Future<void> loadUnreadNotificationStatus() async {
    try {
      final List<dynamic> response =
      await NotificationService.getNotifications();

      final bool hasUnread = response.any((item) {
        if (item is! Map) return false;

        final dynamic readValue = item['is_read'];

        final bool isRead =
            readValue == true ||
                readValue == 1 ||
                readValue == '1';

        return !isRead;
      });

      if (!mounted) return;

      setState(() {
        hasUnreadNotifications = hasUnread;
      });
    } catch (error) {
      debugPrint(
        'Load notification status error: $error',
      );
    }
  }

  // =====================================
  // Open Notifications Screen
  // =====================================

  Future<void> openNotifications() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const NotificationScreen(),
      ),
    );

    if (!mounted) return;

    // تحديث حالة الأيقونة بعد الرجوع
    await loadUnreadNotificationStatus();
  }

  void _onChildChanged() {
    if (!mounted) return;

    setState(() {
      currentChildImagePath =
          ChildStore.instance.selectedChild?.imagePath ??
              widget.childImagePath;
    });
  }

  @override
  void dispose() {
    ChildStore.instance.removeListener(_onChildChanged);
    notificationUpdateNotifier.removeListener(loadUnreadNotificationStatus);
    super.dispose();
  }

  int calculateAge(DateTime dateOfBirth) {
    final DateTime today = DateTime.now();

    int age = today.year - dateOfBirth.year;

    if (today.month < dateOfBirth.month ||
        (today.month == dateOfBirth.month &&
            today.day < dateOfBirth.day)) {
      age--;
    }

    return age;
  }

  void showTemporaryMessage(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          textAlign: TextAlign.center,
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }


  // =====================================
  // Open Home Items
  // =====================================

  void openHomeItem(HomeItem item) {
    switch (item.action) {
      case HomeAction.activity:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ActivityScreen(
              childName: widget.childName,
              birthDate: widget.birthDate,
              gender: widget.gender,
              childImagePath: widget.childImagePath,
            ),
          ),
        );
        break;

      case HomeAction.meals:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MealScreen(
              childName: widget.childName,
              birthDate: widget.birthDate,
              gender: widget.gender,
              childImagePath: widget.childImagePath,
            ),
          ),
        );
        break;

      case HomeAction.glucose:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => GlucoseReadingScreen(
              childName: widget.childName,
              birthDate: widget.birthDate,
              gender: widget.gender,
              childImagePath: widget.childImagePath,
            ),
          ),
        );
        break;

      case HomeAction.medication:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MedicationScreen(
              childName: widget.childName,
              birthDate: widget.birthDate,
              gender: widget.gender,
              childImagePath: widget.childImagePath,
            ),
          ),
        );
        break;

      case HomeAction.medicalExam:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => MedicalExamScreen(
              childName: widget.childName,
              birthDate: widget.birthDate,
              gender: widget.gender,
              childImagePath: widget.childImagePath,
            ),
          ),
        );
        break;

      case HomeAction.reminders:
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RemindersScreen(
              childName: widget.childName,
              birthDate: widget.birthDate,
              gender: widget.gender,
              childImagePath: widget.childImagePath,
            ),
          ),
        );
        break;
    }
  }

  // =====================================
  // Build
  // =====================================

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).primaryColor;
    final int childAge = calculateAge(widget.birthDate);

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

            final double horizontalPadding = isVerySmall
                ? 14
                : isTablet
                ? 36
                : 20;

            return Directionality(
              textDirection: TextDirection.rtl,
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                        vertical: isSmallScreen ? 14 : 18,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: 820,
                          ),
                          child: Column(
                            children: [
                              _buildHeader(
                                primaryColor: primaryColor,
                                isSmallScreen: isSmallScreen,
                                isTablet: isTablet,
                              ),

                              SizedBox(
                                height: isSmallScreen ? 18 : 25,
                              ),

                              _buildChildCard(
                                childAge: childAge,
                                primaryColor: primaryColor,
                                isVerySmall: isVerySmall,
                                isTablet: isTablet,
                              ),

                              SizedBox(
                                height: isSmallScreen ? 22 : 28,
                              ),

                              // القسم الأول: الصحة اليومية

                              collapsibleSection(
                                title: 'الصحة اليومية',
                                isExpanded: dailyHealthExpanded,
                                isVerySmall: isVerySmall,
                                onTap: () {
                                  setState(() {
                                    dailyHealthExpanded =
                                    !dailyHealthExpanded;
                                  });
                                },
                                items: const [
                                  HomeItem(
                                    title: 'النشاط',
                                    icon: Icons.directions_run_rounded,
                                    iconColor: Color(0xff6654B8),
                                    action: HomeAction.activity,
                                  ),
                                  HomeItem(
                                    title: 'الوجبات',
                                    icon: Icons.restaurant_rounded,
                                    iconColor: Color(0xff469E55),
                                    action: HomeAction.meals,
                                  ),
                                ],
                              ),

                              const SizedBox(height: 22),

                              // القسم الثاني: السكر والأدوية

                              collapsibleSection(
                                title: 'السكر والأدوية',
                                isExpanded: treatmentExpanded,
                                isVerySmall: isVerySmall,
                                onTap: () {
                                  setState(() {
                                    treatmentExpanded =
                                    !treatmentExpanded;
                                  });
                                },
                                items: const [
                                  HomeItem(
                                    title: 'قراءة السكر',
                                    icon: Icons.bloodtype_rounded,
                                    iconColor: Color(0xffD95C5C),
                                    action: HomeAction.glucose,
                                  ),
                                  HomeItem(
                                    title: 'الأدوية',
                                    icon: Icons.medication_rounded,
                                    iconColor: Color(0xffC87817),
                                    action: HomeAction.medication,
                                  ),
                                ],
                              ),

                              const SizedBox(height: 22),

                              // القسم الثالث: المتابعة الطبية

                              collapsibleSection(
                                title: 'المتابعة الطبية',
                                isExpanded: medicalFollowUpExpanded,
                                isVerySmall: isVerySmall,
                                onTap: () {
                                  setState(() {
                                    medicalFollowUpExpanded =
                                    !medicalFollowUpExpanded;
                                  });
                                },
                                items: const [
                                  HomeItem(
                                    title: 'الفحوصات الطبية',
                                    icon: Icons.medical_services_rounded,
                                    iconColor: Color(0xff6E52A8),
                                    action: HomeAction.medicalExam,
                                  ),
                                  HomeItem(
                                    title: 'التذكيرات',
                                    icon: Icons.notifications_active_outlined,
                                    iconColor: Color(0xffB74A42),
                                    action: HomeAction.reminders,
                                  ),
                                ],
                              ),

                              const SizedBox(height: 25),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),

                  if (widget.showBottomNavigationBar)
                    bottomNavigationBar(
                      primaryColor,
                      isVerySmall,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // =====================================
  // الترحيب باسم ولي الأمر
  // =====================================

  Widget _buildHeader({
    required Color primaryColor,
    required bool isSmallScreen,
    required bool isTablet,
  }) {
    final Color textColor =
        Theme.of(context).colorScheme.onSurface;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.guardianName.trim().isEmpty
                    ? 'مرحباً بك'
                    : 'مرحباً بك، ${widget.guardianName.trim()}',
                style: TextStyle(
                  fontSize: isSmallScreen
                      ? 24
                      : isTablet
                      ? 31
                      : 27,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'تابع صحة طفلك بسهولة',
                style: TextStyle(
                  fontSize: isSmallScreen ? 13 : 15,
                  color: textColor.withOpacity(0.65),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),



        // =====================================
        // Notification Icon
        // =====================================

        Stack(
          clipBehavior: Clip.none,
          children: [
            _headerAction(
              icon: Icons.notifications_none_rounded,
              tooltip: 'الإشعارات',
              onTap: openNotifications,
            ),

            // النقطة تظهر فقط عند وجود إشعارات غير مقروءة

            if (hasUnreadNotifications)
              Positioned(
                top: 6,
                right: 7,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: primaryColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // =====================================
  // Header Action
  // =====================================

  Widget _headerAction({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final Color textColor =
        Theme.of(context).colorScheme.onSurface;

    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(30),
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(
            icon,
            size: 27,
            color: textColor,
          ),
        ),
      ),
    );
  }

  // =====================================
  // Child Card
  // =====================================

  Widget _buildChildCard({
    required int childAge,
    required Color primaryColor,
    required bool isVerySmall,
    required bool isTablet,
  }) {
    final ThemeData theme = Theme.of(context);
    final Color textColor = theme.colorScheme.onSurface;

    final double imageSize = isVerySmall
        ? 82
        : isTablet
        ? 105
        : 92;

    final Widget defaultChildImage = Icon(
      widget.gender == 'بنت'
          ? Icons.face_3_rounded
          : Icons.face_6_rounded,
      size: imageSize * 0.60,
      color: primaryColor,
    );

    // صورة الطفل المحلية

    final String? imagePath = currentChildImagePath;

    // صورة الطفل القادمة من Laravel

    final String? imageUrl =
        ChildStore.instance.selectedChild?.imageUrl;

    // صورة Laravel أو الأيقونة الافتراضية

    final Widget serverImage =
    imageUrl != null && imageUrl.isNotEmpty
        ? Image.network(
      imageUrl,
      width: imageSize,
      height: imageSize,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Center(
          child: defaultChildImage,
        );
      },
    )
        : Center(
      child: defaultChildImage,
    );

    // إذا توجد صورة محلية نعرضها أولاً

    final Widget displayImage =
    imagePath != null &&
        imagePath.isNotEmpty &&
        File(imagePath).existsSync()
        ? Image.file(
      File(imagePath),
      width: imageSize,
      height: imageSize,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return serverImage;
      },
    )
        : serverImage;

    final Widget childImage = Container(
      width: imageSize,
      height: imageSize,
      decoration: BoxDecoration(
        color: primaryColor.withOpacity(0.12),
        shape: BoxShape.circle,
        border: Border.all(
          color: primaryColor.withOpacity(0.35),
          width: 2,
        ),
      ),
      child: ClipOval(
        child: displayImage,
      ),
    );

    final Widget childDetails = Column(
      crossAxisAlignment: isVerySmall
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          widget.childName,
          textAlign:
          isVerySmall ? TextAlign.center : TextAlign.start,
          style: TextStyle(
            fontSize: isVerySmall
                ? 22
                : isTablet
                ? 28
                : 26,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),

        const SizedBox(height: 12),

        Wrap(
          alignment: isVerySmall
              ? WrapAlignment.center
              : WrapAlignment.start,
          spacing: 15,
          runSpacing: 10,
          children: [
            childInfoItem(
              icon: Icons.calendar_month_outlined,
              text: '$childAge سنوات',
              primaryColor: primaryColor,
            ),
            childInfoItem(
              icon: widget.gender == 'بنت'
                  ? Icons.female
                  : Icons.male,
              text: widget.gender,
              primaryColor: primaryColor,
            ),
          ],
        ),
      ],
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isVerySmall ? 15 : 18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: textColor.withOpacity(0.10),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: isVerySmall
          ? Column(
        children: [
          childImage,
          const SizedBox(height: 14),
          childDetails,
        ],
      )
          : Row(
        children: [
          childImage,
          const SizedBox(width: 18),
          Expanded(child: childDetails),
        ],
      ),
    );
  }

  // =====================================
  // Collapsible Section
  // =====================================

  Widget collapsibleSection({
    required String title,
    required bool isExpanded,
    required bool isVerySmall,
    required VoidCallback onTap,
    required List<HomeItem> items,
  }) {
    final Color textColor =
        Theme.of(context).colorScheme.onSurface;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 7,
              horizontal: 3,
            ),
            child: Row(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isVerySmall ? 17 : 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(width: 5),
                AnimatedRotation(
                  duration: const Duration(milliseconds: 250),
                  turns: isExpanded ? 0 : 0.5,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 23,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),

        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: Alignment.topCenter,
          child: isExpanded
              ? Padding(
            padding: const EdgeInsets.only(top: 10),
            child: _buildSectionItems(
              items,
              isVerySmall,
            ),
          )
              : const SizedBox(
            width: double.infinity,
            height: 0,
          ),
        ),
      ],
    );
  }

  // =====================================
  // Section Items
  // =====================================

  Widget _buildSectionItems(
      List<HomeItem> items,
      bool isVerySmall,
      ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const double spacing = 8;

        final double itemWidth =
            (constraints.maxWidth - spacing) / 2;

        return Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.start,
          spacing: spacing,
          runSpacing: 10,
          children: items.map((item) {
            return SizedBox(
              width: itemWidth,
              child: sectionItem(item),
            );
          }).toList(),
        );
      },
    );
  }

  // =====================================
  // Section Item
  // =====================================

  Widget sectionItem(HomeItem item) {
    final ThemeData theme = Theme.of(context);
    final Color textColor = theme.colorScheme.onSurface;

    return InkWell(
      onTap: () => openHomeItem(item),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: 5,
          vertical: 13,
        ),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: textColor.withOpacity(0.12),
            width: 1.2,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.icon,
              color: item.iconColor,
              size: 34,
            ),
            const SizedBox(height: 9),
            Text(
              item.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =====================================
  // Child Info Item
  // =====================================

  Widget childInfoItem({
    required IconData icon,
    required String text,
    required Color primaryColor,
  }) {
    final Color textColor =
        Theme.of(context).colorScheme.onSurface;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 19,
          color: primaryColor,
        ),
        const SizedBox(width: 5),
        Text(
          text,
          style: TextStyle(
            fontSize: 13,
            color: textColor.withOpacity(0.70),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // =====================================
  // Bottom Navigation Bar
  // =====================================

  Widget bottomNavigationBar(
      Color primaryColor,
      bool isVerySmall,
      ) {
    final ThemeData theme = Theme.of(context);
    final Color textColor = theme.colorScheme.onSurface;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isVerySmall ? 8 : 18,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          top: BorderSide(
            color: textColor.withOpacity(0.12),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            bottomItem(
              icon: Icons.home_rounded,
              label: 'الرئيسية',
              selected: true,
              primaryColor: primaryColor,
              isVerySmall: isVerySmall,
              onTap: () {},
            ),

            bottomItem(
              icon: Icons.bar_chart_rounded,
              label: 'التقارير',
              selected: false,
              primaryColor: primaryColor,
              isVerySmall: isVerySmall,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReportsScreen(
                      childName: widget.childName,
                      birthDate: widget.birthDate,
                      gender: widget.gender,
                      childImagePath: widget.childImagePath,
                    ),
                  ),
                );
              },
            ),

            bottomItem(
              icon: Icons.menu_book_rounded,
              label: 'السجلات',
              selected: false,
              primaryColor: primaryColor,
              isVerySmall: isVerySmall,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RecordsScreen(),
                  ),
                );
              },
            ),

            bottomItem(
              icon: Icons.person_outline_rounded,
              label: 'الملف الشخصي',
              selected: false,
              primaryColor: primaryColor,
              isVerySmall: isVerySmall,
              onTap: () async {
                final result =
                await Navigator.push<Map<String, dynamic>>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfileScreen(
                      childName: widget.childName,
                      birthDate: widget.birthDate,
                      gender: widget.gender,
                      childImagePath: currentChildImagePath,
                    ),
                  ),
                );

                if (!mounted || result == null) return;

                setState(() {
                  currentChildImagePath =
                      result['childImagePath'] as String? ??
                          currentChildImagePath;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  // =====================================
  // Bottom Navigation Item
  // =====================================

  Widget bottomItem({
    required IconData icon,
    required String label,
    required bool selected,
    required Color primaryColor,
    required bool isVerySmall,
    required VoidCallback onTap,
  }) {
    final Color textColor =
        Theme.of(context).colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 3,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: isVerySmall ? 22 : 25,
              color: selected
                  ? primaryColor
                  : textColor.withOpacity(0.55),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontSize: isVerySmall ? 10 : 11,
                color: selected
                    ? primaryColor
                    : textColor.withOpacity(0.55),
                fontWeight: selected
                    ? FontWeight.bold
                    : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =====================================
// Home Item Model
// =====================================

class HomeItem {
  final String title;
  final IconData icon;
  final Color iconColor;
  final HomeAction action;

  const HomeItem({
    required this.title,
    required this.icon,
    required this.iconColor,
    required this.action,
  });
}