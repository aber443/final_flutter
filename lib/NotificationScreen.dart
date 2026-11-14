import 'package:flutter/material.dart';

import 'services/notification_service.dart';

enum NotificationType {
  appointment,
  medication,
  general,
}

class AppNotification {
  final int id;
  final NotificationType type;
  final String title;
  final String message;
  final DateTime createdAt;
  bool isRead;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.isRead,
  });

  factory AppNotification.fromJson(
      Map<String, dynamic> json,
      ) {
    final String typeValue =
        json['type']?.toString().toLowerCase() ?? '';

    NotificationType notificationType;

    switch (typeValue) {
      case 'appointment':
        notificationType = NotificationType.appointment;
        break;

      case 'medication':
        notificationType = NotificationType.medication;
        break;

      default:
        notificationType = NotificationType.general;
    }

    final dynamic readValue = json['is_read'];

    final bool read = readValue == true ||
        readValue == 1 ||
        readValue == '1';

    return AppNotification(
      id: int.parse(
        json['notification_id'].toString(),
      ),
      type: notificationType,
      title: json['title']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      createdAt: DateTime.tryParse(
        json['created_at']?.toString() ?? '',
      )?.toLocal() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      isRead: read,
    );
  }
}

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() =>
      _NotificationScreenState();
}

class _NotificationScreenState
    extends State<NotificationScreen> {

  bool showUnreadOnly = false;

  // ==========================================
  // ألوان التطبيق من main.dart
  // ==========================================

  Color get primaryColor =>
      Theme.of(context).primaryColor;

  Color get textColor =>
      Theme.of(context).colorScheme.onSurface;

  Color get cardColor =>
      Theme.of(context).cardColor;

  Color get borderColor =>
      textColor.withOpacity(0.12);

  Color get hintColor =>
      textColor.withOpacity(0.60);

  Color get errorColor =>
      Theme.of(context).colorScheme.error;

  // ==========================================
  // Notification API State
  // ==========================================

  final List<AppNotification> notifications = [];

  bool isLoading = true;
  bool isProcessing = false;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    loadNotifications();
  }

  // ==========================================
  // Load Notifications From Laravel
  // ==========================================

  Future<void> loadNotifications() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final List<dynamic> response =
      await NotificationService.getNotifications();

      final List<AppNotification> loadedNotifications = [];

      for (final item in response) {
        if (item is Map) {
          loadedNotifications.add(
            AppNotification.fromJson(
              Map<String, dynamic>.from(item),
            ),
          );
        }
      }

      if (!mounted) return;

      setState(() {
        notifications
          ..clear()
          ..addAll(loadedNotifications);

        isLoading = false;
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

  // ==========================================
  // Show Message
  // ==========================================

  void showMessage(String message) {
    if (!mounted) return;

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

  // ==========================================
  // Unread Count
  // ==========================================

  int get unreadCount {
    return notifications
        .where((notification) => !notification.isRead)
        .length;
  }

  // ==========================================
  // Visible Notifications
  // ==========================================

  List<AppNotification> get visibleNotifications {
    if (!showUnreadOnly) {
      return notifications;
    }

    return notifications
        .where((notification) => !notification.isRead)
        .toList();
  }

  // ==========================================
  // Mark Notification As Read
  // ==========================================

  Future<void> markAsRead(
      AppNotification notification,
      ) async {
    if (notification.isRead || isProcessing) {
      return;
    }

    setState(() {
      isProcessing = true;
    });

    try {
      await NotificationService.markAsRead(
        notificationId: notification.id,
      );

      if (!mounted) return;

      setState(() {
        notification.isRead = true;
      });
    } catch (error) {
      if (!mounted) return;

      showMessage(
        error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

  // ==========================================
  // Mark All As Read
  // ==========================================

  Future<void> markAllAsRead() async {
    if (unreadCount == 0 || isProcessing) {
      return;
    }

    setState(() {
      isProcessing = true;
    });

    try {
      await NotificationService.markAllAsRead();

      if (!mounted) return;

      setState(() {
        for (final notification in notifications) {
          notification.isRead = true;
        }
      });

      showMessage('تم تحديد جميع الإشعارات كمقروءة');
    } catch (error) {
      if (!mounted) return;

      showMessage(
        error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

  // ==========================================
  // Delete Notification
  // ==========================================

  Future<void> deleteNotification(
      AppNotification notification,
      ) async {
    if (isProcessing) return;

    setState(() {
      isProcessing = true;
    });

    try {
      await NotificationService.deleteNotification(
        notificationId: notification.id,
      );

      if (!mounted) return;

      setState(() {
        notifications.removeWhere(
              (item) => item.id == notification.id,
        );
      });

      showMessage('تم حذف الإشعار');
    } catch (error) {
      if (!mounted) return;

      showMessage(
        error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() {
          isProcessing = false;
        });
      }
    }
  }

  // ==========================================
  // Notification Icon
  // ==========================================

  IconData notificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.appointment:
        return Icons.event_available_outlined;

      case NotificationType.medication:
        return Icons.medication_outlined;

      case NotificationType.general:
        return Icons.notifications_none_rounded;
    }
  }

  // ==========================================
  // Notification Time
  // ==========================================

  String formatNotificationTime(DateTime date) {
    final DateTime now = DateTime.now();

    final DateTime today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final DateTime notificationDay = DateTime(
      date.year,
      date.month,
      date.day,
    );

    final int difference =
        today.difference(notificationDay).inDays;

    final int hour = date.hour > 12
        ? date.hour - 12
        : date.hour == 0
        ? 12
        : date.hour;

    final String minute =
    date.minute.toString().padLeft(2, '0');

    final String period =
    date.hour < 12 ? 'ص' : 'م';

    final String time = '$hour:$minute $period';

    if (difference == 0) {
      return 'اليوم • $time';
    }

    if (difference == 1) {
      return 'أمس • $time';
    }

    final String day =
    date.day.toString().padLeft(2, '0');

    final String month =
    date.month.toString().padLeft(2, '0');

    return '$day/$month/${date.year} • $time';
  }

  // ==========================================
  // Main Interface
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final List<AppNotification> displayedNotifications =
        visibleNotifications;

    final double screenWidth =
        MediaQuery.of(context).size.width;

    final double screenHeight =
        MediaQuery.of(context).size.height;

    final bool isVerySmall = screenWidth < 390;

    final bool isSmallScreen =
        screenWidth < 430 || screenHeight < 650;

    final bool isTablet = screenWidth >= 600;

    final double horizontalPadding = isVerySmall
        ? 14
        : isTablet
        ? 36
        : 20;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Directionality(
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
                            'الإشعارات',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: isVerySmall ? 19 : 22,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),

                          // Back Button

                          Align(
                            alignment:
                            AlignmentDirectional.centerStart,
                            child: Material(
                              color: cardColor,
                              borderRadius:
                              BorderRadius.circular(12),
                              child: InkWell(
                                onTap: () {
                                  Navigator.pop(context);
                                },
                                borderRadius:
                                BorderRadius.circular(12),
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    borderRadius:
                                    BorderRadius.circular(12),
                                    border: Border.all(
                                      color: borderColor,
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.arrow_back_ios_new_rounded,
                                    color: textColor,
                                    size: 19,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Mark All As Read

                          Align(
                            alignment:
                            AlignmentDirectional.centerEnd,
                            child: TextButton(
                              onPressed:
                              unreadCount == 0 || isProcessing
                                  ? null
                                  : markAllAsRead,
                              child: Text(
                                isVerySmall
                                    ? 'قراءة الكل'
                                    : 'تحديد الكل كمقروء',
                                style: TextStyle(
                                  fontSize: isVerySmall ? 11 : 12,
                                  fontWeight: FontWeight.w600,
                                  color:
                                  unreadCount == 0 || isProcessing
                                      ? hintColor
                                      : primaryColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    SizedBox(
                      height: isSmallScreen ? 22 : 30,
                    ),

                    // =====================
                    // Filters
                    // =====================

                    Row(
                      children: [

                        _filterButton(
                          text: 'الكل',
                          selected: !showUnreadOnly,
                        ),

                        const SizedBox(width: 8),

                        _unreadFilterButton(),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // =====================
                    // Notifications
                    // =====================

                    if (isLoading)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 50,
                        ),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: primaryColor,
                          ),
                        ),
                      )

                    else if (errorMessage != null)
                      _errorState()

                    else if (displayedNotifications.isEmpty)
                        _emptyState()

                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics:
                          const NeverScrollableScrollPhysics(),
                          itemCount: displayedNotifications.length,
                          separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final AppNotification notification =
                            displayedNotifications[index];

                            return _notificationCard(
                              notification: notification,
                            );
                          },
                        ),

                    const SizedBox(height: 25),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // Error State
  // ==========================================

  Widget _errorState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 32,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Column(
        children: [

          Icon(
            Icons.error_outline_rounded,
            color: errorColor,
            size: 38,
          ),

          const SizedBox(height: 12),

          Text(
            errorMessage ?? 'تعذر تحميل الإشعارات',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 14),

          ElevatedButton(
            onPressed: loadNotifications,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // All Filter Button
  // ==========================================

  Widget _filterButton({
    required String text,
    required bool selected,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          showUnreadOnly = false;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 9,
        ),
        decoration: BoxDecoration(
          color: selected ? primaryColor : cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? primaryColor : borderColor,
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : textColor,
          ),
        ),
      ),
    );
  }

  // ==========================================
  // Unread Filter Button
  // ==========================================

  Widget _unreadFilterButton() {
    return InkWell(
      onTap: () {
        setState(() {
          showUnreadOnly = true;
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: showUnreadOnly ? primaryColor : cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: showUnreadOnly
                ? primaryColor
                : borderColor,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [

            Text(
              'غير المقروء',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: showUnreadOnly
                    ? Colors.white
                    : textColor,
              ),
            ),

            if (unreadCount > 0) ...[
              const SizedBox(width: 7),

              Container(
                constraints: const BoxConstraints(
                  minWidth: 22,
                  minHeight: 22,
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                ),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: showUnreadOnly
                      ? Colors.white
                      : primaryColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$unreadCount',
                  style: TextStyle(
                    color: showUnreadOnly
                        ? primaryColor
                        : Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ==========================================
  // Notification Card
  // ==========================================

  Widget _notificationCard({
    required AppNotification notification,
  }) {
    return Material(
      color: notification.isRead
          ? cardColor
          : primaryColor.withOpacity(0.07),
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: () {
          markAsRead(notification);
        },
        borderRadius: BorderRadius.circular(17),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(
              color: notification.isRead
                  ? borderColor
                  : primaryColor.withOpacity(0.35),
              width: notification.isRead ? 1.1 : 1.4,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // Notification Icon

              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  notificationIcon(notification.type),
                  color: primaryColor,
                  size: 25,
                ),
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [

                    // Title

                    Row(
                      children: [

                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: notification.isRead
                                  ? FontWeight.w600
                                  : FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                        ),

                        if (!notification.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(
                              right: 6,
                            ),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 6),

                    // Message

                    Text(
                      notification.message,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.45,
                        color: textColor.withOpacity(0.75),
                      ),
                    ),

                    const SizedBox(height: 9),

                    // Date

                    Text(
                      formatNotificationTime(
                        notification.createdAt,
                      ),
                      style: TextStyle(
                        fontSize: 11,
                        color: hintColor,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 4),

              // Delete Button

              IconButton(
                tooltip: 'حذف الإشعار',
                onPressed: isProcessing
                    ? null
                    : () {
                  deleteNotification(notification);
                },
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: errorColor,
                  size: 21,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // Empty State
  // ==========================================

  Widget _emptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 38,
      ),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: Column(
        children: [

          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              showUnreadOnly
                  ? Icons.mark_email_read_outlined
                  : Icons.notifications_none_rounded,
              color: primaryColor,
              size: 34,
            ),
          ),

          const SizedBox(height: 15),

          Text(
            showUnreadOnly
                ? 'لا توجد إشعارات غير مقروءة'
                : 'لا توجد إشعارات',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            showUnreadOnly
                ? 'تمت قراءة جميع الإشعارات'
                : 'ستظهر هنا تذكيرات الأدوية والمواعيد الطبية',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: hintColor,
            ),
          ),
        ],
      ),
    );
  }
}