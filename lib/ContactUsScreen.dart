
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'services/api_config.dart';

// =====================================================
// الاتصال بخادم Laravel
// =====================================================

class _ContactApi {
  static const _storage = FlutterSecureStorage();
  static const _timeout = Duration(seconds: 20);

  static Future<Map<String, String>> _headers() async {
    final token = await _storage.read(key: 'auth_token');

    if (token == null || token.trim().isEmpty) {
      throw Exception(
        'انتهت جلسة تسجيل الدخول، يرجى تسجيل الدخول مجددًا.',
      );
    }

    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  static String _serverError(http.Response response) {
    if (response.statusCode == 401) {
      return 'انتهت جلسة تسجيل الدخول، يرجى تسجيل الدخول مجددًا.';
    }

    if (response.statusCode == 403) {
      return 'ليس لديك صلاحية لتنفيذ الطلب.';
    }

    if (response.statusCode == 422) {
      try {
        final data = jsonDecode(
          utf8.decode(response.bodyBytes),
        );

        if (data is Map && data['errors'] is Map) {
          final errors = data['errors'] as Map;

          for (final value in errors.values) {
            if (value is List && value.isNotEmpty) {
              return value.first.toString();
            }
          }
        }

        if (data is Map && data['message'] != null) {
          return data['message'].toString();
        }
      } catch (_) {}

      return 'تحققي من البيانات المدخلة ثم حاولي مجددًا.';
    }

    return 'تعذر إكمال الطلب (${response.statusCode}).';
  }

  // =====================================================
  // جلب الرسائل والردود من Laravel
  // =====================================================

  static Future<List<Map<String, dynamic>>> getMessages({
    int maxPages = 100,
  }) async {
    final headers = await _headers();
    final result = <Map<String, dynamic>>[];

    for (int page = 1; page <= maxPages; page++) {
      final uri = Uri.parse(
        '${ApiConfig.baseUrl}/contact-messages',
      ).replace(
        queryParameters: {'page': '$page'},
      );

      final response = await http
          .get(
        uri,
        headers: headers,
      )
          .timeout(_timeout);

      if (response.statusCode != 200) {
        throw Exception(_serverError(response));
      }

      final payload = jsonDecode(
        utf8.decode(response.bodyBytes),
      );

      if (payload is! Map || payload['data'] is! List) {
        throw const FormatException(
          'استجابة الرسائل غير صحيحة.',
        );
      }

      for (final item in payload['data'] as List) {
        if (item is Map) {
          result.add(
            Map<String, dynamic>.from(item),
          );
        }
      }

      final current = int.tryParse(
        '${payload['current_page'] ?? page}',
      ) ??
          page;

      final last = int.tryParse(
        '${payload['last_page'] ?? page}',
      ) ??
          page;

      if (current >= last) {
        break;
      }
    }

    return result;
  }

  // =====================================================
  // إرسال رسالة أو تقييم إلى Laravel
  // =====================================================

  static Future<void> postMessage({
    required String type,
    String? message,
    int? rating,
  }) async {
    final headers = await _headers();

    final body = <String, dynamic>{
      'type': type,
    };

    if (message != null) {
      body['message'] = message;
    }

    if (rating != null) {
      body['rating'] = rating;
    }

    final response = await http
        .post(
      Uri.parse(
        '${ApiConfig.baseUrl}/contact-messages',
      ),
      headers: headers,
      body: jsonEncode(body),
    )
        .timeout(_timeout);

    // يدعم إنشاء رسالة جديدة أو تحديث تقييم موجود
    if (response.statusCode != 200 &&
        response.statusCode != 201) {
      throw Exception(_serverError(response));
    }
  }
}

// =====================================================
// شاشة تواصل معنا
// =====================================================

class ContactUsScreen extends StatefulWidget {
  const ContactUsScreen({super.key});

  @override
  State<ContactUsScreen> createState() =>
      _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  final _formKey = GlobalKey<FormState>();

  final _messageController = TextEditingController();

  String? _selectedType;

  bool _checkingRating = false;
  bool _sendingMessage = false;

  String? _ratingLoadError;

  @override
  void initState() {
    super.initState();

    // إظهار التقييم كل مرة يدخل المستخدم هذه الصفحة
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkRating();
      }
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  // =====================================================
  // معالجة أخطاء الاتصال
  // =====================================================

  String _friendlyError(Object error) {
    if (error is TimeoutException) {
      return 'انتهت مهلة الاتصال بالخادم، حاولي مجددًا.';
    }

    if (error is http.ClientException) {
      return 'تعذر الاتصال بالخادم، تحققي من الشبكة.';
    }

    if (error is FormatException) {
      return 'استجابة غير متوقعة من الخادم.';
    }

    final value = error
        .toString()
        .replaceFirst('Exception: ', '');

    if (value.contains('SocketException')) {
      return 'تعذر الاتصال بالخادم، تحققي من الشبكة.';
    }

    return value;
  }

  // =====================================================
  // عرض التقييم عند كل دخول إلى الصفحة
  // =====================================================

  Future<void> _checkRating() async {
    if (!mounted) return;

    setState(() {
      _checkingRating = false;
      _ratingLoadError = null;
    });

    await _showRatingDialog();
  }

  // =====================================================
  // عرض رسالة نجاح أو خطأ
  // =====================================================

  void _notice(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
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
  // نافذة تقييم التطبيق
  // =====================================================

  Future<void> _showRatingDialog() async {
    if (!mounted) return;

    int stars = 0;
    bool sending = false;
    String? errorText;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (dialogContext) {
        return PopScope(
          canPop: !sending,
          child: StatefulBuilder(
            builder: (dialogContext, update) {
              final theme = Theme.of(dialogContext);

              final primary = theme.primaryColor;
              final textColor =
                  theme.colorScheme.onSurface;

              return Directionality(
                textDirection: TextDirection.rtl,
                child: Dialog(
                  insetPadding:
                  const EdgeInsets.symmetric(
                    horizontal: 24,
                  ),
                  backgroundColor: theme.cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                    BorderRadius.circular(22),
                    side: BorderSide(
                      color: primary,
                      width: 1.8,
                    ),
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 370,
                    ),
                    child: Padding(
                      padding:
                      const EdgeInsets.fromLTRB(
                        16,
                        24,
                        16,
                        22,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.star_rounded,
                            color: primary,
                            size: 42,
                          ),

                          const SizedBox(height: 12),

                          Text(
                            'كيف تقيّم تجربتك مع TinyGuide؟',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight:
                              FontWeight.bold,
                              color: textColor,
                            ),
                          ),

                          const SizedBox(height: 18),

                          // عبارة التقييم فوق النجوم
                          Text(
                            stars == 0
                                ? 'اختار تقييمًا أولًا'
                                : 'تقييمك: $stars من 5',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 12),

                          // النجوم الخمس
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Row(
                              mainAxisAlignment:
                              MainAxisAlignment.center,
                              children: List.generate(
                                5,
                                    (index) {
                                  final value = index + 1;

                                  return IconButton(
                                    tooltip: '$value من 5',
                                    onPressed: sending
                                        ? null
                                        : () {
                                      update(() {
                                        stars = value;
                                        errorText = null;
                                      });
                                    },
                                    icon: Icon(
                                      value <= stars
                                          ? Icons.star_rounded
                                          : Icons
                                          .star_border_rounded,
                                      size: 38,
                                      color: value <= stars
                                          ? const Color(
                                        0xFFE5AA31,
                                      )
                                          : textColor
                                          .withOpacity(0.38),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          if (errorText != null) ...[
                            const SizedBox(height: 12),

                            Text(
                              errorText!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: theme.colorScheme.error,
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),

                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton(
                              onPressed: stars == 0 || sending
                                  ? null
                                  : () async {
                                update(() {
                                  sending = true;
                                  errorText = null;
                                });

                                try {
                                  await _ContactApi.postMessage(
                                    type: 'rating',
                                    rating: stars,
                                  );

                                  if (!dialogContext.mounted) {
                                    return;
                                  }

                                  Navigator.of(
                                    dialogContext,
                                  ).pop();

                                  _notice(
                                    'شكرًا لك، تم إرسال تقييمك بنجاح.',
                                  );
                                } catch (error) {
                                  if (!dialogContext.mounted) {
                                    return;
                                  }

                                  update(() {
                                    sending = false;
                                    errorText =
                                        _friendlyError(error);
                                  });
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primary,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                  BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                sending
                                    ? 'جارٍ إرسال التقييم...'
                                    : 'إرسال التقييم',
                              ),
                            ),
                          ),

                          const SizedBox(height: 10),

                          SizedBox(
                            width: double.infinity,
                            height: 42,
                            child: TextButton(
                              onPressed: sending
                                  ? null
                                  : () {
                                Navigator.of(
                                  dialogContext,
                                ).pop();
                              },
                              child: Text(
                                'ليس الآن',
                                style: TextStyle(
                                  color:
                                  textColor.withOpacity(0.7),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  // =====================================================
  // إرسال الاستفسار أو الاقتراح أو البلاغ
  // =====================================================

  Future<void> _submitMessage() async {
    if (_sendingMessage) return;

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final type = _selectedType;

    if (type == null) return;

    setState(() {
      _sendingMessage = true;
    });

    try {
      await _ContactApi.postMessage(
        type: type,
        message: _messageController.text.trim(),
      );

      if (!mounted) return;

      _messageController.clear();

      setState(() {
        _selectedType = null;
      });

      _notice(
        'تم إرسال رسالتك إلى الإدارة بنجاح.',
      );
    } catch (error) {
      _notice(_friendlyError(error));
    } finally {
      if (mounted) {
        setState(() {
          _sendingMessage = false;
        });
      }
    }
  }

  // =====================================================
  // تصميم خيار التواصل
  // =====================================================

  Widget _option({
    required String type,
    required String title,
    required String description,
    required IconData icon,
  }) {
    final theme = Theme.of(context);

    final primary = theme.primaryColor;
    final text = theme.colorScheme.onSurface;

    final selected = _selectedType == type;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () {
          setState(() {
            _selectedType = type;
            _messageController.clear();
          });
        },
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: selected
                ? primary.withOpacity(0.08)
                : theme.cardColor,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: selected
                  ? primary
                  : text.withOpacity(0.14),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: primary,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: text,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 12,
                        color: text.withOpacity(0.65),
                      ),
                    ),
                  ],
                ),
              ),

              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.arrow_back_ios_new_rounded,
                color: primary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // =====================================================
  // واجهة تواصل معنا
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final primary = theme.primaryColor;
    final text = theme.colorScheme.onSurface;
    final border = text.withOpacity(0.15);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: 650,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.stretch,
                  children: [
                    // =====================================================
                    // عنوان الصفحة وسهم الرجوع
                    // =====================================================

                    SizedBox(
                      height: 52,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(
                            'تواصل معنا',
                            style: TextStyle(
                              color: text,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          Align(
                            alignment:
                            AlignmentDirectional.centerStart,
                            child: IconButton(
                              onPressed: () =>
                                  Navigator.pop(context),
                              icon: Icon(
                                Icons.arrow_back_ios_new_rounded,
                                color: text,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // =====================================================
                    // بطاقة الترحيب
                    // =====================================================

                    Container(
                      padding: const EdgeInsets.all(17),
                      decoration: BoxDecoration(
                        color: primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.support_agent_rounded,
                            color: primary,
                            size: 36,
                          ),

                          const SizedBox(height: 8),

                          Text(
                            'يسعدنا تواصلك معنا',
                            style: TextStyle(
                              color: text,
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 5),

                          Text(
                            'اختار نوع الرسالة التي ترغبين في إرسالها',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: text.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 22),

                    if (_checkingRating)
                      const Padding(
                        padding: EdgeInsets.all(28),
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else if (_ratingLoadError != null) ...[
                      Text(
                        _ratingLoadError!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: theme.colorScheme.error,
                        ),
                      ),

                      const SizedBox(height: 12),

                      ElevatedButton(
                        onPressed: _checkRating,
                        child: const Text(
                          'إعادة المحاولة',
                        ),
                      ),
                    ] else ...[
                      // =====================================================
                      // الاستفسار
                      // =====================================================

                      _option(
                        type: 'inquiry',
                        title: 'استفسار',
                        description:
                        'اسأل عن طريقة استخدام التطبيق',
                        icon: Icons.help_outline_rounded,
                      ),

                      // =====================================================
                      // الاقتراح
                      // =====================================================

                      _option(
                        type: 'suggestion',
                        title: 'اقتراح',
                        description:
                        'شارك فكرة تساعدنا في تحسين التطبيق',
                        icon: Icons.lightbulb_outline_rounded,
                      ),

                      // =====================================================
                      // الإبلاغ عن مشكلة
                      // =====================================================

                      _option(
                        type: 'problem',
                        title: 'الإبلاغ عن مشكلة',
                        description:
                        'أخبرنا عن مشكلة واجهتك أثناء الاستخدام',
                        icon: Icons.report_problem_outlined,
                      ),

                      // =====================================================
                      // نموذج كتابة الرسالة
                      // =====================================================

                      if (_selectedType != null) ...[
                        const SizedBox(height: 8),

                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: border,
                            ),
                          ),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  _selectedType == 'inquiry'
                                      ? 'استفسار'
                                      : _selectedType == 'suggestion'
                                      ? 'اقتراح'
                                      : 'الإبلاغ عن مشكلة',
                                  style: TextStyle(
                                    color: text,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),

                                const SizedBox(height: 12),

                                TextFormField(
                                  controller: _messageController,
                                  minLines: 4,
                                  maxLines: 6,
                                  maxLength: 1000,
                                  textAlign: TextAlign.right,
                                  decoration: InputDecoration(
                                    hintText: _selectedType == 'inquiry'
                                        ? 'اكتب استفسارك هنا...'
                                        : _selectedType == 'suggestion'
                                        ? 'اكتب اقتراحك هنا...'
                                        : 'اشرح المشكلة التي واجهتك...',
                                    border: OutlineInputBorder(
                                      borderRadius:
                                      BorderRadius.circular(12),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius:
                                      BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: border,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius:
                                      BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: primary,
                                        width: 1.6,
                                      ),
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null ||
                                        value.trim().isEmpty) {
                                      return 'يرجى كتابة الرسالة';
                                    }

                                    return null;
                                  },
                                ),

                                const SizedBox(height: 10),

                                // =====================================================
                                // زر إرسال الرسالة
                                // الأيقونة على يسار النص
                                // =====================================================

                                SizedBox(
                                  height: 46,
                                  child: ElevatedButton.icon(
                                    iconAlignment: IconAlignment.end,
                                    onPressed: _sendingMessage
                                        ? null
                                        : _submitMessage,
                                    icon: const Icon(
                                      Icons.send_rounded,
                                    ),
                                    label: Text(
                                      _sendingMessage
                                          ? 'جارٍ إرسال الرسالة...'
                                          : 'إرسال الرسالة',
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primary,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 14),

                      // =====================================================
                      // زر رسائلي والردود
                      // الأيقونة على يسار النص
                      // =====================================================

                      SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          iconAlignment: IconAlignment.end,
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                const _MyMessagesScreen(),
                              ),
                            );
                          },
                          icon: const Icon(
                            Icons.mark_email_read_outlined,
                          ),
                          label: const Text(
                            'رسائلي والردود',
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primary,
                            side: BorderSide(
                              color: primary,
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
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

// =====================================================
// شاشة رسائلي والردود
// =====================================================

class _MyMessagesScreen extends StatefulWidget {
  const _MyMessagesScreen();

  @override
  State<_MyMessagesScreen> createState() =>
      _MyMessagesScreenState();
}

class _MyMessagesScreenState
    extends State<_MyMessagesScreen> {
  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  // =====================================================
  // جلب الرسائل من Laravel
  // =====================================================

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final messages = await _ContactApi.getMessages();

      if (!mounted) return;

      setState(() {
        _messages = messages
            .where(
              (item) => item['type'] != 'rating',
        )
            .toList();

        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = error
            .toString()
            .replaceFirst('Exception: ', '');
      });
    }
  }

  String _title(String? type) {
    switch (type) {
      case 'inquiry':
        return 'استفسار';

      case 'suggestion':
        return 'اقتراح';

      case 'problem':
        return 'الإبلاغ عن مشكلة';

      default:
        return 'رسالة';
    }
  }

  // =====================================================
  // واجهة رسائلي والردود
  // =====================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final text = theme.colorScheme.onSurface;
    final primary = theme.primaryColor;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('رسائلي والردود'),
        ),
        body: _loading
            ? const Center(
          child: CircularProgressIndicator(),
        )
            : _error != null
            ? Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _error!,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 10),

              ElevatedButton(
                onPressed: _refresh,
                child: const Text(
                  'إعادة المحاولة',
                ),
              ),
            ],
          ),
        )
            : RefreshIndicator(
          onRefresh: _refresh,
          child: _messages.isEmpty
              ? ListView(
            children: const [
              SizedBox(height: 160),

              Center(
                child: Text(
                  'لا توجد رسائل مرسلة بعد.',
                ),
              ),
            ],
          )
              : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            separatorBuilder: (_, __) =>
            const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = _messages[index];

              final reply = item['reply']
                  ?.toString()
                  .trim() ??
                  '';

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius:
                  BorderRadius.circular(16),
                  border: Border.all(
                    color: text.withOpacity(0.14),
                  ),
                ),
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title(
                        item['type']?.toString(),
                      ),
                      style: TextStyle(
                        color: primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      item['message']?.toString() ?? '',
                      style: TextStyle(
                        color: text,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      'الحالة: ${item['status'] ?? 'new'}',
                      style: TextStyle(
                        color: text.withOpacity(0.6),
                        fontSize: 12,
                      ),
                    ),

                    if (reply.isNotEmpty) ...[
                      const Divider(height: 24),

                      Text(
                        'رد الإدارة',
                        style: TextStyle(
                          color: primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Text(
                        reply,
                        style: TextStyle(
                          color: text,
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
