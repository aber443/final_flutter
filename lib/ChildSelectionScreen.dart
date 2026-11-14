import 'dart:io';
import 'package:flutter/material.dart';

import 'ChildStore.dart';
import 'ChildInfoScreen.dart';
import 'MainNavigationScreen.dart';

class ChildSelectionScreen extends StatefulWidget {
  const ChildSelectionScreen({super.key});

  @override
  State<ChildSelectionScreen> createState() =>
      _ChildSelectionScreenState();
}

class _ChildSelectionScreenState
    extends State<ChildSelectionScreen> {
  bool openingChild = false;
  bool isAddingChild = false;

  // حالة جلب الأطفال من Laravel
  bool isLoadingChildren = true;
  String? loadingError;

  // =====================================
  // عند فتح الشاشة
  // =====================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        loadChildren();
      }
    });
  }

  // =====================================
  // جلب الأطفال من Laravel
  // =====================================

  Future<void> loadChildren() async {
    if (!mounted) return;

    setState(() {
      isLoadingChildren = true;
      loadingError = null;
    });

    try {
      await ChildStore.instance.loadChildrenFromApi();
    } catch (error) {
      if (!mounted) return;

      setState(() {
        loadingError = error
            .toString()
            .replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoadingChildren = false;
        });
      }
    }
  }

  // =====================================
  // عرض صورة الطفل
  // =====================================

  Widget buildChildImage(
      ChildModel child,
      Color primaryColor,
      ) {
    final String? localPath = child.imagePath;
    final String? serverUrl = child.imageUrl;

    final placeholder = Icon(
      Icons.child_care_rounded,
      color: primaryColor,
      size: 32,
    );

    Widget buildServerImage() {
      if (serverUrl == null || serverUrl.trim().isEmpty) {
        return placeholder;
      }

      return Image.network(
        serverUrl,
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return placeholder;
        },
      );
    }

    Widget imageWidget;

    if (localPath != null && localPath.trim().isNotEmpty) {
      imageWidget = Image.file(
        File(localPath),
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return buildServerImage();
        },
      );
    } else {
      imageWidget = buildServerImage();
    }

    return CircleAvatar(
      radius: 28,
      backgroundColor: primaryColor.withOpacity(0.15),
      child: ClipOval(
        child: imageWidget,
      ),
    );
  }

  // =====================================
  // فتح الطفل المختار
  // =====================================

  void openChild(ChildModel child) {
    if (openingChild ||
        isLoadingChildren ||
        !mounted) {
      return;
    }

    openingChild = true;

    ChildStore.instance.selectChild(child.localId);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MainNavigationScreen(
          childName: child.fullName,
          birthDate: child.birthDate,
          gender: child.gender,
          childImagePath: child.imagePath,
        ),
      ),
    );
  }

  // =====================================
  // إضافة طفل جديد
  // =====================================

  Future<void> addChild() async {
    if (isAddingChild ||
        isLoadingChildren ||
        openingChild) {
      return;
    }

    setState(() {
      isAddingChild = true;
    });

    try {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const ChildInfoScreen(
            showBackButton: true,
            returnToProfileAfterSave: true,
          ),
        ),
      );

      if (!mounted) return;

      await loadChildren();
    } finally {
      if (mounted) {
        setState(() {
          isAddingChild = false;
        });
      }
    }
  }

  // =====================================
  // Main Screen
  // =====================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final primaryColor = theme.primaryColor;
    final textColor = theme.colorScheme.onSurface;

    final secondaryTextColor =
    textColor.withOpacity(0.65);

    final isDark =
        theme.brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,

        appBar: AppBar(
          title: const Text('اختيار الطفل'),
          automaticallyImplyLeading: false,
          backgroundColor:
          theme.appBarTheme.backgroundColor,
          foregroundColor:
          theme.appBarTheme.foregroundColor,
        ),

        body: AnimatedBuilder(
          animation: ChildStore.instance,
          builder: (context, _) {
            final children =
                ChildStore.instance.children;

            // =====================================
            // Loading
            // =====================================

            if (isLoadingChildren) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      color: primaryColor,
                    ),

                    const SizedBox(height: 16),

                    Text(
                      'جاري تحميل بيانات الأطفال...',
                      style: TextStyle(
                        color: textColor,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              );
            }

            // =====================================
            // Error
            // =====================================

            if (loadingError != null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 65,
                        color: primaryColor,
                      ),

                      const SizedBox(height: 16),

                      Text(
                        loadingError!,
                        style: TextStyle(
                          fontSize: 15,
                          color: textColor,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 20),

                      ElevatedButton.icon(
                        onPressed: loadChildren,
                        icon: const Icon(
                          Icons.refresh_rounded,
                        ),
                        label: const Text(
                          'إعادة المحاولة',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // =====================================
            // طفل واحد: فتحه تلقائيًا
            // =====================================

            if (children.length == 1 && !openingChild) {
              WidgetsBinding.instance
                  .addPostFrameCallback((_) {
                if (!mounted ||
                    openingChild ||
                    isLoadingChildren ||
                    loadingError != null) {
                  return;
                }

                openChild(children.first);
              });

              return Center(
                child: CircularProgressIndicator(
                  color: primaryColor,
                ),
              );
            }

            // =====================================
            // لا يوجد أطفال
            // =====================================

            if (children.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.child_care_rounded,
                        size: 70,
                        color: primaryColor,
                      ),

                      const SizedBox(height: 16),

                      Text(
                        'أضيفي بيانات طفلك للبدء',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                        textAlign: TextAlign.center,
                      ),

                      const SizedBox(height: 20),

                      ElevatedButton.icon(
                        onPressed:
                        isAddingChild ? null : addChild,
                        icon: const Icon(
                          Icons.person_add,
                        ),
                        label: const Text(
                          'إضافة طفل',
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // =====================================
            // قائمة الأطفال
            // =====================================

            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'أطفالي',
                  style: TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'اختاري الطفل لعرض بياناته الصحية',
                  style: TextStyle(
                    color: secondaryTextColor,
                  ),
                ),

                const SizedBox(height: 20),

                // =====================================
                // Child Cards
                // =====================================

                ...children.map((child) {
                  return Card(
                    color: theme.cardColor,
                    elevation: isDark ? 0 : 1,
                    margin: const EdgeInsets.only(
                      bottom: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: textColor.withOpacity(
                          isDark ? 0.14 : 0.08,
                        ),
                      ),
                    ),

                    child: ListTile(
                      contentPadding:
                      const EdgeInsets.all(12),

                      // صورة الطفل
                      leading: buildChildImage(
                        child,
                        primaryColor,
                      ),

                      // اسم الطفل
                      title: Text(
                        child.fullName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),

                      // معلومات الطفل
                      subtitle: Text(
                        '${child.gender} • '
                            '${child.birthDate.year}',
                        style: TextStyle(
                          color: secondaryTextColor,
                          fontSize: 13,
                        ),
                      ),

                      // السهم
                      trailing: Icon(
                        Icons.chevron_left_rounded,
                        color: primaryColor,
                      ),

                      onTap: openingChild
                          ? null
                          : () => openChild(child),
                    ),
                  );
                }),

                const SizedBox(height: 10),

                // =====================================
                // Add Another Child
                // =====================================

                OutlinedButton.icon(
                  onPressed:
                  isAddingChild ? null : addChild,
                  icon: const Icon(
                    Icons.person_add_alt_1,
                  ),
                  label: const Text(
                    'إضافة طفل',
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}