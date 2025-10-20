// lib/screens/home_screen.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'admin_panel_screen.dart';
import 'package:decanat_progect/admin/developer_tools_screen.dart';
import 'package:decanat_progect/constants.dart';
import 'package:decanat_progect/widgets/victory_banner.dart';
import 'webview_screen.dart';
import 'package:http/http.dart' as http;
import 'package:decanat_progect/admin/admin_schedule_editor.dart';
import 'package:decanat_progect/user/user_home_content.dart';
import 'package:decanat_progect/student/student_home_content.dart';
import 'package:decanat_progect/teacher/teacher_home_content.dart';
import 'package:decanat_progect/admin/admin_schedule_teacher_editor.dart';
import 'profile_drawer.dart';
import 'package:decanat_progect/utils/server_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import "package:package_info_plus/package_info_plus.dart";

// 👇 добавили твои кастомные тосты
import 'package:decanat_progect/ui/overlay_toast.dart';

/// Если на сервере ADMIN_API_KEY пуст/не задан — оставляем null.
const String? kAdminApiKey = null; // например: 'supersecret';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String _userRole = 'user';
  String? _userId;

  TabController? _tabController;
  int _currentTabIndex = 0;

  // триггер для принудительной перезагрузки виджетов
  int _refreshNonce = 0;

  // ---- Обновление / баннер
  static const String _kUpdateNotice = 'update_notice'; // ключ локального кэша
  Map<String, dynamic>? _updateNotice; // {title, link, description, targetVersion, createdAt}
  String _appVersion = '0.0.0';

  // ----- Время пар для карточек
  static const Map<int, String> _lessonTimes = {
    1: '8:00 - 9:35',
    2: '9:55 - 11:30',
    3: '11:50 - 13:25',
    4: '13:45 - 15:20',
    5: '15:30 - 17:05',
  };
  String _getLessonTime(dynamic n) {
    final i = n is int ? n : int.tryParse('$n') ?? 0;
    return _lessonTimes[i] ?? '';
  }

  // ----- Ключи якоря недели в SharedPreferences
  static const String _kWeekAnchorType = 'week_anchor_type'; // 'upper'/'lower'
  static const String _kWeekAnchorMonday = 'week_anchor_monday'; // 'yyyy-MM-dd'

  // ====== Быстрая панель расписания (автообновление без открытия экрана расписания)
  Timer? _todayTimer; // общий таймер для автообновления
  // — СТУДЕНТ
  bool _studentTodayLoading = false;
  Map<String, dynamic>? _studentToday; // {dayName, weekName, lessons: []}
  // — ПРЕПОДАВАТЕЛЬ
  bool _teacherTodayLoading = false;
  String? _teacherFullName;
  String _teacherWeekType = 'upper';
  List<Map<String, dynamic>> _teacherItems = [];

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadUpdateNotice();
    _loadAppVersion();
    _startTodayTimer(); // запускаем автообновление
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // при каждом заходе на экран тоже пробуем обновить
    _refreshTodayPanels();
    _loadUpdateNotice();
  }

  @override
  void dispose() {
    _tabController?.removeListener(_handleTabSelection);
    _tabController?.dispose();
    _todayTimer?.cancel();
    super.dispose();
  }

  // ======== Вспомогательные обёртки под твой OverlayToast ========
  void _toastInfo(String message) {
    OverlayToast.instance.info(message, position: ToastPosition.top);
  }

  void _toastError(String message) {
    OverlayToast.instance.error(message, position: ToastPosition.top);
  }

  // ======== АВТООБНОВЛЕНИЕ СЕГОДНЯШНЕЙ ПАНЕЛИ ========
  void _startTodayTimer() {
    _todayTimer?.cancel();
    // моментальный прогон
    _refreshTodayPanels();
    // затем периодически
    _todayTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _refreshTodayPanels();
    });
  }

  Future<void> _refreshTodayPanels() async {
    if (!mounted) return;

    // определяем актуальный type недели
    final now = DateTime.now();
    final weekType = await _getWeekTypeFor(now);

    // Студент (по выбранной группе)
    if (mounted) {
      setState(() => _studentTodayLoading = true);
    }
    final s = await _loadTodayScheduleOnlineOrCache(weekType: weekType);
    if (mounted) {
      setState(() {
        _studentToday = s;
        _studentTodayLoading = false;
      });
    }

    // Преподаватель
    if (mounted) {
      setState(() => _teacherTodayLoading = true);
    }
    await _loadTeacherToday(weekType: weekType);
    if (mounted) {
      setState(() {
        _teacherWeekType = weekType;
        _teacherTodayLoading = false;
      });
    }
  }

  // ====== FULL REFRESH на экране ============================================
  Future<void> _refreshAll() async {
    await _loadUserRole();
    await _loadUpdateNotice();
    await _loadAppVersion();
    await _refreshTodayPanels();
    if (!mounted) return;
    setState(() => _refreshNonce++);
    if (mounted) {
      _toastInfo('Данные обновлены');
    }
  }

  // --------------------------------------------------------------------------
  Future<void> _checkServerConnection() async {
    final ok = await pingServer(AppConfig.serverUrl);
    if (ok) {
      _toastInfo('Сервер доступен ✓');
    } else {
      _toastError('Сервер недоступен ✗');
    }
  }

  void refreshUserRole() => _loadUserRole();

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    _userId = prefs.getString('userId');

    String roleFromPrefs = prefs.getString('userRole') ?? 'user';

    if (_userId != null && _userId!.isNotEmpty) {
      try {
        final url = '${AppConfig.serverUrl}/api/users/$_userId/role';
        final response = await http.get(
          Uri.parse(url),
          headers: {'Cache-Control': 'no-cache'},
        );
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          roleFromPrefs = (data['role'] as String?)?.trim() ?? 'user';
          await SharedPreferences.getInstance()
              .then((p) => p.setString('userRole', roleFromPrefs));
        }
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _userRole = roleFromPrefs;
      _ensureTabs();
    });
  }

  // ====== Update Notice load/save ===========================================
  Future<void> _loadUpdateNotice() async {
    try {
      final fromServer = await _fetchUpdateNoticeFromServer();
      if (!mounted) return;
      setState(() => _updateNotice = fromServer);
      await _cacheNoticeLocally(fromServer);
    } catch (_) {
      final cached = await _readNoticeFromCache();
      if (!mounted) return;
      setState(() => _updateNotice = cached);
    }
  }

  Future<Map<String, dynamic>?> _fetchUpdateNoticeFromServer() async {
    final uri = Uri.parse('${AppConfig.serverUrl}/api/announcements/latest');
    final r = await http.get(uri, headers: {'Cache-Control': 'no-cache'});
    if (r.statusCode == 200) {
      return json.decode(r.body) as Map<String, dynamic>;
    } else if (r.statusCode == 404) {
      return null;
    } else {
      throw Exception('Server error ${r.statusCode}');
    }
  }

  Future<void> _cacheNoticeLocally(Map<String, dynamic>? notice) async {
    final prefs = await SharedPreferences.getInstance();
    if (notice == null) {
      await prefs.remove(_kUpdateNotice);
    } else {
      await prefs.setString(_kUpdateNotice, json.encode(notice));
    }
  }

  Future<Map<String, dynamic>?> _readNoticeFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kUpdateNotice);
    return raw != null ? json.decode(raw) as Map<String, dynamic> : null;
  }

  Future<void> _publishUpdateNoticeToServer(Map<String, dynamic> notice) async {
    final uri = Uri.parse('${AppConfig.serverUrl}/api/announcements/latest');

    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (kAdminApiKey != null) headers['X-ADMIN-KEY'] = kAdminApiKey!;

    final r = await http.put(uri, headers: headers, body: json.encode(notice));
    if (r.statusCode != 200) {
      throw Exception('Publish failed: ${r.statusCode}');
    }
  }

  Future<void> _clearUpdateNoticeOnServer() async {
    final uri = Uri.parse('${AppConfig.serverUrl}/api/announcements/latest');

    final headers = <String, String>{};
    if (kAdminApiKey != null) headers['X-ADMIN-KEY'] = kAdminApiKey!;

    final r = await http.delete(uri, headers: headers);
    if (r.statusCode != 200) {
      throw Exception('Delete failed: ${r.statusCode}');
    }
  }

  Future<void> _loadAppVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) return;
      setState(() => _appVersion = info.version);
    } catch (_) {}
  }

  // Сравнение версий вида "1.2.3"
  int _compareVersions(String a, String b) {
    List<int> pa = a.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> pb = b.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    while (pa.length < 3) pa.add(0);
    while (pb.length < 3) pb.add(0);
    for (int i = 0; i < 3; i++) {
      if (pa[i] != pb[i]) return pa[i].compareTo(pb[i]);
    }
    return 0;
  }

  bool _shouldShowUpdateBanner() {
    final n = _updateNotice;
    if (n == null) return false;
    final target = (n['targetVersion'] as String?)?.trim();
    if (target == null || target.isEmpty) return true;
    return _compareVersions(_appVersion, target) < 0;
  }

  // ---- UI: баннер уведомления об обновлении --------------------------------
  Widget _buildUpdateBanner() {
    if (!_shouldShowUpdateBanner()) return const SizedBox.shrink();

    final n = _updateNotice!;
    final title = (n['title'] as String?)?.trim() ?? 'Доступно обновление';
    final description = (n['description'] as String?)?.trim();
    final link = (n['link'] as String?)?.trim().isNotEmpty == true
        ? (n['link'] as String).trim()
        : 'https://www.rustore.ru/catalog/app/com.example.decanat_progect';

    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 12),
          child: child,
        ),
      ),
      child: Card(
        elevation: 6,
        margin: const EdgeInsets.only(bottom: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFFF7043), Color(0xFFEC407A)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.deepOrange.withOpacity(0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _BlinkingMegaphone(
                    color: Colors.white,
                    size: 26,
                    period: const Duration(milliseconds: 1300),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
              if (description != null && description.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  description,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14.5,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.deepOrange,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
                      ),
                      onPressed: () async {
                        final uri = Uri.parse(link);
                        try {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } catch (_) {
                          _toastError('Не удалось открыть ссылку');
                        }
                      },
                      icon: const Icon(Icons.system_update_alt_rounded, size: 22),
                      label: const Text(
                        'Обновить приложение',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15.5,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  if ((_updateNotice?['targetVersion'] as String?)?.trim().isNotEmpty == true)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(50),
                        border: Border.all(color: Colors.white.withOpacity(0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_rounded, size: 16, color: Colors.white),
                          const SizedBox(width: 6),
                          Text(
                            _updateNotice!['targetVersion'],
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------------------------
  void _ensureTabs() {
    if (_isAdminOrDeveloper) {
      if (_tabController == null) {
        _tabController = TabController(length: 3, vsync: this);
        _tabController!.addListener(_handleTabSelection);
      }
    } else {
      _tabController?.removeListener(_handleTabSelection);
      _tabController?.dispose();
      _tabController = null;
      _currentTabIndex = 0;
    }
  }

  void _handleTabSelection() {
    if (_tabController != null && _tabController!.indexIsChanging) {
      setState(() => _currentTabIndex = _tabController!.index);
    }
  }

  bool get _isAdminOrDeveloper =>
      _userRole == 'admin' || _userRole == 'developer';

  PreferredSizeWidget _buildAppBar() {
    final scheme = Theme.of(context).colorScheme;

    return AppBar(
      elevation: 0,
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.menu),
        tooltip: 'Открыть профиль',
        onPressed: () => _scaffoldKey.currentState?.openDrawer(),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Факультет ИСП',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
          ),
          const SizedBox(width: 8),
          if (_isAdminOrDeveloper) _buildServerStatusIndicator(),
        ],
      ),
      actions: [
        IconButton(
          tooltip: 'Обновить',
          icon: const Icon(Icons.refresh),
          onPressed: _refreshAll,
        ),
        if (_isAdminOrDeveloper)
          IconButton(
            icon: Icon(
              _userRole == 'developer'
                  ? Icons.developer_mode
                  : Icons.admin_panel_settings,
            ),
            onPressed: _showDeveloperTools,
            tooltip: 'Инструменты разработчика',
          ),
      ],
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.primary,
              Color.lerp(scheme.primary, scheme.secondary, 0.20)!,
            ],
          ),
        ),
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
      ),
    );
  }

  Widget _buildServerStatusIndicator() {
    return FutureBuilder<bool>(
      future: _checkServerStatus(),
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? false;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isOnline
                ? Colors.green.withOpacity(0.1)
                : Colors.red.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isOnline ? Colors.green : Colors.red,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isOnline ? Icons.wifi : Icons.wifi_off,
                  size: 14, color: isOnline ? Colors.green : Colors.red),
              const SizedBox(width: 4),
              Text(
                isOnline ? 'Онлайн' : 'Офлайн',
                style: TextStyle(
                  fontSize: 12,
                  color: isOnline ? Colors.green : Colors.red,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _checkServerStatus() async {
    try {
      final response = await http
          .get(Uri.parse('${AppConfig.serverUrl}/api/health'))
          .timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Widget _buildDivider(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Theme.of(context).colorScheme.primary.withOpacity(0.3),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// === ВЫЧИСЛЕНИЕ ТЕКУЩЕЙ НЕДЕЛИ (upper/lower) ===========================
  DateTime _mondayOf(DateTime d) {
    final wd = d.weekday; // 1..7
    return DateTime(d.year, d.month, d.day).subtract(Duration(days: wd - 1));
  }

  Future<String> _getCurrentWeekType() async {
    final prefs = await SharedPreferences.getInstance();
    String anchorType = prefs.getString(_kWeekAnchorType) ?? 'lower';
    final stored = prefs.getString(_kWeekAnchorMonday); // 'yyyy-MM-dd'

    DateTime anchorMonday;
    if (stored == null || stored.isEmpty) {
      anchorMonday = _mondayOf(DateTime.now());
      await prefs.setString(
          _kWeekAnchorMonday,
          '${anchorMonday.year.toString().padLeft(4, '0')}-'
              '${anchorMonday.month.toString().padLeft(2, '0')}-'
              '${anchorMonday.day.toString().padLeft(2, '0')}');
      await prefs.setString(_kWeekAnchorType, anchorType);
    } else {
      final parts = stored.split('-').map(int.parse).toList();
      anchorMonday = DateTime(parts[0], parts[1], parts[2]);
    }

    final nowMon = _mondayOf(DateTime.now());
    final weeks = nowMon.difference(anchorMonday).inDays ~/ 7;
    final isSameParity = weeks % 2 == 0;
    return isSameParity ? anchorType : (anchorType == 'upper' ? 'lower' : 'upper');
  }

  Future<String> _getWeekTypeFor(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final anchorType = prefs.getString(_kWeekAnchorType) ?? 'lower';
    final stored = prefs.getString(_kWeekAnchorMonday);

    DateTime anchorMonday;
    if (stored == null || stored.isEmpty) {
      anchorMonday = _mondayOf(DateTime.now());
      await prefs.setString(
        _kWeekAnchorMonday,
        '${anchorMonday.year.toString().padLeft(4, '0')}-'
            '${anchorMonday.month.toString().padLeft(2, '0')}-'
            '${anchorMonday.day.toString().padLeft(2, '0')}',
      );
      await prefs.setString(_kWeekAnchorType, anchorType);
      return anchorType;
    } else {
      final p = stored.split('-').map(int.parse).toList();
      anchorMonday = DateTime(p[0], p[1], p[2]);
    }

    final mondayOfDate = _mondayOf(date);
    final diffWeeks = mondayOfDate.difference(anchorMonday).inDays ~/ 7;
    final sameParity = diffWeeks % 2 == 0;
    return sameParity ? anchorType : (anchorType == 'upper' ? 'lower' : 'upper');
  }

  Future<void> _togglePrimaryWeek() async {
    final prefs = await SharedPreferences.getInstance();
    final oldType = prefs.getString(_kWeekAnchorType) ?? 'lower';
    final newType = oldType == 'upper' ? 'lower' : 'upper';
    final mon = _mondayOf(DateTime.now());
    await prefs.setString(_kWeekAnchorType, newType);
    await prefs.setString(
        _kWeekAnchorMonday,
        '${mon.year.toString().padLeft(4, '0')}-'
            '${mon.month.toString().padLeft(2, '0')}-'
            '${mon.day.toString().padLeft(2, '0')}');
    _toastInfo('Базовая неделя: ${newType == "upper" ? "Верхняя" : "Нижняя"} (с текущего понедельника)');
    if (mounted) setState(() {});
  }

  // ===== СЕГОДНЯ ДЛЯ СТУДЕНТА ===============================================
  Future<Map<String, dynamic>?> _loadTodayScheduleOnlineOrCache({
    required String weekType,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final group = prefs.getString('selectedGroup');
    if (group == null || group.trim().isEmpty) return null;

    DateTime now = DateTime.now();
    DateTime target = now.hour >= 18 ? now.add(const Duration(days: 1)) : now;
    // Если воскресенье — смещаем на понедельник
    if (target.weekday == DateTime.sunday) {
      target = target.add(const Duration(days: 1));
    }

    const days = [
      'Понедельник',
      'Вторник',
      'Среда',
      'Четверг',
      'Пятница',
      'Суббота',
    ];
    if (target.weekday < DateTime.monday || target.weekday > DateTime.saturday) {
      return null;
    }
    final dayName = days[target.weekday - 1];

    // Сначала пытаемся онлайн
    try {
      final url = Uri.parse(
        '${AppConfig.serverUrl}/api/schedule/$group/$weekType',
      );
      final r = await http.get(url, headers: {'Cache-Control': 'no-cache'});
      if (r.statusCode == 200) {
        final scheduleData = json.decode(r.body) as Map<String, dynamic>;

        // кэшируем (как делает экран расписания)
        await prefs.setString(
          'schedule_${group}_$weekType',
          json.encode(scheduleData),
        );

        final lessons = (scheduleData[dayName] ?? []) as List;
        return {
          'dayName': dayName,
          'weekName': weekType == 'upper' ? 'Верхняя неделя' : 'Нижняя неделя',
          'lessons': lessons,
        };
      }
    } catch (_) {
      // оффлайн/ошибка сети — игнорируем и берём из кэша ниже
    }

    // Оффлайн: читаем кэш
    final cached = prefs.getString('schedule_${group}_$weekType');
    if (cached == null) return null;
    final scheduleData = json.decode(cached) as Map<String, dynamic>;
    final lessons = (scheduleData[dayName] ?? []) as List;
    return {
      'dayName': dayName,
      'weekName': weekType == 'upper' ? 'Верхняя неделя' : 'Нижняя неделя',
      'lessons': lessons,
    };
  }

  // ===== СЕГОДНЯ ДЛЯ ПРЕПОДАВАТЕЛЯ ==========================================
  Future<void> _loadTeacherToday({required String weekType}) async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('userRole') ?? 'user';
    final userId = prefs.getString('userId');

    _teacherFullName = null;
    _teacherItems = [];
    if (role != 'teacher' || userId == null || userId.isEmpty) return;

    try {
      final tResp = await http.get(
        Uri.parse('${AppConfig.serverUrl}/api/teachers/$userId'),
      );
      if (tResp.statusCode == 200) {
        final data = json.decode(tResp.body) as Map<String, dynamic>;
        _teacherFullName = (data['full_name'] as String?)?.trim();
      }

      if (_teacherFullName != null && _teacherFullName!.isNotEmpty) {
        final todayRu = _todayRu();
        final url = Uri.parse(
          '${AppConfig.serverUrl}/api/teacher-schedule/${Uri.encodeComponent(_teacherFullName!)}/$weekType',
        );
        final r = await http.get(url, headers: {'Cache-Control': 'no-cache'});
        if (r.statusCode == 200) {
          final map = json.decode(r.body) as Map<String, dynamic>;
          final list = (map[todayRu] as List<dynamic>? ?? [])
              .map((e) => (e as Map).map((k, v) => MapEntry('$k', v)))
              .cast<Map<String, dynamic>>()
              .toList();
          _teacherItems = list;
        }
      }
    } catch (_) {}
  }

  String _todayRu() {
    const days = [
      'Понедельник',
      'Вторник',
      'Среда',
      'Четверг',
      'Пятница',
      'Суббота',
      'Воскресенье'
    ];
    return days[DateTime.now().weekday - 1];
  }

  // ========= ГЛОУ-ОБЁРТКА ДЛЯ ПАНЕЛЕЙ =======================================
  Widget _glowWrap({
    required Widget child,
    EdgeInsetsGeometry margin = const EdgeInsets.only(bottom: 14),
  }) {
    return _BreathingGlow(
      margin: margin,
      borderRadius: 18,
      stroke: 2.2,
      gradient: const LinearGradient(
        colors: [Color(0xFF7C4DFF), Color(0xFF42A5F5), Color(0xFF26C6DA)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      child: child,
    );
  }

  // ======= UI карточки «Сегодня» (СТУДЕНТ) ==================================
  Widget _buildStudentTodayCard() {
    final inner = _studentTodayLoading
        ? _buildLoadingCard(icon: Icons.today)
        : (_studentToday == null
        ? _buildEmptyCard(icon: Icons.info_outline, text: 'Сегодня занятий нет')
        : _buildStudentContentCard());

    return _glowWrap(child: inner);
  }

  Widget _buildLoadingCard({required IconData icon}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(icon, size: 28, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            const Expanded(child: LinearProgressIndicator()),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyCard({required IconData icon, required String text}) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Theme.of(context).cardColor,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(
              text,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentContentCard() {
    final dayName = _studentToday!['dayName'] as String;
    final weekName = _studentToday!['weekName'] as String;
    final List lessons = _studentToday!['lessons'] as List;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      color: Theme.of(context).cardColor,
      child: Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.today,
                    size: 28, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  '$dayName ($weekName)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onBackground,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (lessons.isEmpty)
              Text(
                'Сегодня занятий нет 🎉',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 14),
              )
            else
              Column(
                children: lessons.map((lesson) {
                  final ln = lesson['lesson_number'];
                  final time = _getLessonTime(ln);
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        '${ln ?? ''}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                    title: Text(
                      '${lesson['subject'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (time.isNotEmpty)
                          Text(
                            time,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        const SizedBox(height: 2),
                        Text(
                          '${lesson['teacher'] ?? ''} • ${lesson['classroom'] ?? ''}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                    trailing: Text(
                      '${lesson['type'] ?? ''}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 12.5,
                      ),
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  // ======= UI карточка «Сегодня» (ПРЕПОДАВАТЕЛЬ) ============================
  Widget _buildTeacherTodayCard() {
    // Панель должна быть у преподавателя даже если ФИО не подтянулось
    if (_userRole != 'teacher') return const SizedBox.shrink();

    Widget inner;
    if (_teacherTodayLoading) {
      inner = _buildLoadingCard(icon: Icons.calendar_today);
    } else if (_teacherFullName == null || _teacherFullName!.isEmpty) {
      inner = _buildEmptyCard(
        icon: Icons.person_search_rounded,
        text: 'Профиль преподавателя не найден',
      );
    } else {
      inner = Card(
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        color: Theme.of(context).cardColor,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_today,
                      size: 28, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${_todayRu()} (${_teacherWeekType == 'upper' ? 'Верхняя' : 'Нижняя'} неделя)',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onBackground,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (_teacherItems.isEmpty)
                Text(
                  'Сегодня занятий нет 🎉',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 14),
                )
              else
                Column(
                  children: _teacherItems.map((lesson) {
                    final lnRaw = lesson['lesson_number'];
                    final ln = int.tryParse('$lnRaw') ?? 0;
                    final time = _lessonTimes[ln] ?? '';
                    final subject = '${lesson['subject'] ?? ''}';
                    final group = '${lesson['group_name'] ?? ''}';
                    final room = '${lesson['classroom'] ?? ''}';
                    final type = '${lesson['type'] ?? ''}';

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        child: Text(
                          ln == 0 ? '' : '$ln',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        subject,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (time.isNotEmpty)
                            Text(
                              time,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                            ),
                          const SizedBox(height: 2),
                          Text(
                            [
                              if (group.isNotEmpty) group,
                              if (room.isNotEmpty) room,
                            ].join(' • '),
                            style: TextStyle(
                              color:
                              Theme.of(context).colorScheme.onSurface,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                      trailing: Text(
                        type,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 12.5,
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      );
    }

    return _glowWrap(child: inner);
  }

  // ---------- Заголовок + табы ----------
  Widget _buildHeaderWithOptionalTabs() {
    if (!_isAdminOrDeveloper || _tabController == null) {
      return const VictoryBanner();
    }

    final scheme = Theme.of(context).colorScheme;
    final palette = <Color>[
      scheme.primary.withOpacity(0.95),
      scheme.secondary.withOpacity(0.90),
      (scheme.tertiary ?? scheme.primary).withOpacity(0.85),
    ];

    return Column(
      children: [
        const VictoryBanner(),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 4),
          child: TabBar(
            controller: _tabController!,
            isScrollable: false,
            labelPadding: EdgeInsets.zero,
            labelColor: scheme.primary,
            unselectedLabelColor: scheme.primary.withOpacity(0.65),
            labelStyle: const TextStyle(fontWeight: FontWeight.w700),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
            indicator: FancyUnderlineGradientIndicator(
              controller: _tabController!,
              palette: palette,
              thickness: 4.0,
              horizontalPadding: 16.0,
              blurSigma: 1.5,
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            tabs: const [
              Tab(child: FittedBox(fit: BoxFit.scaleDown, child: Text('Пользователь'))),
              Tab(child: FittedBox(fit: BoxFit.scaleDown, child: Text('Студент'))),
              Tab(child: FittedBox(fit: BoxFit.scaleDown, child: Text('Преподаватель'))),
            ],
          ),
        ),
      ],
    );
  }

  // ---------- Контент ролей (быстрая панель ПЕРЕД кнопками) ----------
  Widget _roleContent(String role) {
    switch (role) {
      case 'student':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUpdateBanner(),
            // 👉 Панель «Сегодня» СВЕРХУ (видна студенту)
            _buildStudentTodayCard(),
            const SizedBox(height: 24),
            _buildDivider(context),
            const SizedBox(height: 24),
            // Кнопки и прочий контент студента — теперь ниже
            const StudentHomeContent(),
            const SizedBox(height: 28),
            _buildSectionTitle(context, 'Новости университета'),
            const SizedBox(height: 16),
            _buildNewsItem(context, 'День открытых дверей', '25 января 2025',
                Icons.calendar_today, AppColors.primary),
            const SizedBox(height: 12),
            _buildNewsItem(context, 'Научная конференция', '15 февраля 2025',
                Icons.science, Colors.blue[700]!),
            const SizedBox(height: 12),
            _buildNewsItem(context, 'Спортивные соревнования', '8 марта 2025',
                Icons.sports, Colors.green[700]!),
          ],
        );
      case 'teacher':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUpdateBanner(),
            // 👉 Панель «Сегодня» СВЕРХУ (видна преподавателю)
            _buildTeacherTodayCard(),
            const SizedBox(height: 24),
            _buildDivider(context),
            const SizedBox(height: 24),
            // Кнопки и прочее для преподавателя — ниже
            TeacherHomeContent(
              userRole: _userRole,
              userId: _userId,
              onRoleChanged: refreshUserRole,
            ),
            const SizedBox(height: 28),
            _buildSectionTitle(context, 'Новости университета'),
            const SizedBox(height: 16),
            _buildNewsItem(context, 'День открытых дверей', '25 января 2025',
                Icons.calendar_today, AppColors.primary),
            const SizedBox(height: 12),
            _buildNewsItem(context, 'Научная конференция', '15 февраля 2025',
                Icons.science, Colors.blue[700]!),
            const SizedBox(height: 12),
            _buildNewsItem(context, 'Спортивные соревнования', '8 марта 2025',
                Icons.sports, Colors.green[700]!),
          ],
        );
      default: // user (ГОСТЬ)
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildUpdateBanner(),
            // ❌ У пользователя (гость) — БЕЗ «быстрого расписания»
            const SizedBox(height: 14),
            const UserHomeContent(),
            const SizedBox(height: 28),
            _buildDivider(context),
            const SizedBox(height: 28),
            _buildSectionTitle(context, 'Новости университета'),
            const SizedBox(height: 16),
            _buildNewsItem(context, 'День открытых дверей', '25 января 2025',
                Icons.calendar_today, AppColors.primary),
            const SizedBox(height: 12),
            _buildNewsItem(context, 'Научная конференция', '15 февраля 2025',
                Icons.science, Colors.blue[700]!),
            const SizedBox(height: 12),
            _buildNewsItem(context, 'Спортивные соревнования', '8 марта 2025',
                Icons.sports, Colors.green[700]!),
          ],
        );
    }
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.onBackground,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  Widget _buildNewsItem(BuildContext context, String title, String date,
      IconData icon, Color color) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      color: Theme.of(context).cardColor,
      child: ListTile(
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
              color: color.withOpacity(0.08), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 20),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Theme.of(context).colorScheme.onBackground,
          ),
        ),
        subtitle: Text(
          date,
          style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface, fontSize: 12),
        ),
        trailing: Icon(Icons.arrow_forward_ios,
            size: 16, color: Theme.of(context).colorScheme.onSurface),
        onTap: () => _showNewsDetails(title, date),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  void _showNewsDetails(String title, String date) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(
            'Подробная информация о событии "$title", запланированном на $date. '
                'Для получения дополнительной информации посетите официальный сайт университета.',
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Закрыть')),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => WebViewScreen(
                      url: 'https://donntu.ru/news',
                      title: 'Новости ДонНТУ',
                    ),
                  ),
                );
              },
              child: const Text('Подробнее'),
            ),
          ],
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        );
      },
    );
  }

  Future<void> _updateUserRole(String userId, String newRole) async {
    if (_userRole != 'developer') {
      _toastError('Только разработчики могут изменять роли');
      return;
    }
    try {
      final response = await http.put(
        Uri.parse('${AppConfig.serverUrl}/api/users/role'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'user_id': userId, 'role': newRole}),
      );
      if (response.statusCode == 200) {
        _toastInfo('Роль пользователя обновлена');
      } else {
        _toastError('Ошибка обновления роли');
      }
    } catch (e) {
      _toastError('Ошибка сети: $e');
    }
  }

  // ---- BottomSheet «Инструменты разработчика»
  void _showDeveloperTools() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;

        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.60,
          maxChildSize: 0.90,
          minChildSize: 0.35,
          builder: (ctx, scrollController) {
            return SafeArea(
              top: false,
              child: Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(22),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        scheme.surface.withOpacity(.92),
                        scheme.surfaceVariant.withOpacity(.90),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(.25),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                    ],
                    border: Border.all(color: scheme.outline.withOpacity(.12)),
                  ),
                  child: ListView(
                    controller: scrollController,
                    padding: EdgeInsets.fromLTRB(
                      16,
                      12,
                      16,
                      16 + MediaQuery.of(ctx).padding.bottom,
                    ),
                    children: [
                      Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: scheme.outline.withOpacity(.35),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.developer_mode, color: scheme.primary),
                          const SizedBox(width: 8),
                          Text(
                            'Инструменты разработчика',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 18,
                              color: scheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Divider(
                          color: scheme.outline.withOpacity(.15), height: 1),
                      const SizedBox(height: 14),

                      if (_userRole == 'developer') ...[
                        DevActionButton(
                          icon: Icons.schedule,
                          label: 'Расписание студентов',
                          onTap: () async {
                            Navigator.pop(context);
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AdminScheduleEditor()),
                            );
                            // при возврате обновим панель «сегодня»
                            _refreshTodayPanels();
                          },
                        ),
                        DevActionButton(
                          icon: Icons.person,
                          label: 'Расписание преподавателей',
                          gradient: const [Color(0xFF7C4DFF), Color(0xFF536DFE)],
                          onTap: () async {
                            Navigator.pop(context);
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => AdminScheduleTeacherEditor()),
                            );
                            _refreshTodayPanels();
                          },
                        ),
                        DevActionButton(
                          icon: Icons.swap_horiz_rounded,
                          label: 'Сменить базовую неделю',
                          gradient: const [Color(0xFF00BCD4), Color(0xFF2196F3)],
                          onTap: () async {
                            Navigator.pop(context);
                            await _togglePrimaryWeek();
                            _refreshTodayPanels();
                          },
                        ),
                        DevActionButton(
                          icon: Icons.campaign_outlined,
                          label: 'Отправить уведомление об обновлении',
                          gradient: const [Color(0xFFFF9800), Color(0xFFF44336)],
                          onTap: _showSendUpdateNoticeDialog,
                        ),
                        DevActionButton(
                          icon: Icons.admin_panel_settings,
                          label: 'Назначить администратора',
                          gradient: const [Color(0xFF00C853), Color(0xFF00BFA5)],
                          onTap: () => _showRoleChangeDialog('admin'),
                        ),
                        DevActionButton(
                          icon: Icons.person_remove,
                          label: 'Снять права администратора',
                          gradient: const [Color(0xFFFF5252), Color(0xFFFF7043)],
                          onTap: _showRemoveAdminDialog,
                        ),
                      ],

                      DevActionButton(
                        icon: Icons.wifi,
                        label: 'Проверить соединение с сервером',
                        gradient: const [Color(0xFF29B6F6), Color(0xFF26C6DA)],
                        onTap: () async {
                          Navigator.pop(context);
                          await _checkServerConnection();
                        },
                      ),
                      DevActionButton(
                        icon: Icons.info,
                        label: 'Информация о пользователе',
                        gradient: const [Color(0xFF64B5F6), Color(0xFF7986CB)],
                        onTap: _showUserInfo,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==== Диалог "Отправить уведомление об обновлении" ========================
  void _showSendUpdateNoticeDialog() {
    final titleCtrl = TextEditingController();
    final linkCtrl = TextEditingController(
      text: 'https://www.rustore.ru/catalog/app/com.example.decanat_progect',
    );
    final descrCtrl = TextEditingController();
    final targetVersionCtrl = TextEditingController();

    final scheme = Theme.of(context).colorScheme;

    InputDecoration _dec({
      required String label,
      String? hint,
      required IconData icon,
    }) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: scheme.surfaceVariant.withOpacity(.25),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outline.withOpacity(.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary.withOpacity(.6), width: 1.6),
        ),
        prefixIcon: Icon(icon),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          clipBehavior: Clip.antiAlias,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ---------- HEADER
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        scheme.primary.withOpacity(.16),
                        scheme.secondary.withOpacity(.12),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: scheme.primary.withOpacity(.18),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.system_update_alt, color: scheme.primary),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Отправить уведомление',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: scheme.onSurface,
                            letterSpacing: -.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ---------- CONTENT
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: titleCtrl,
                          decoration: _dec(
                            label: 'Тема уведомления *',
                            hint: 'Например: Доступна версия 1.2.2',
                            icon: Icons.title,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: linkCtrl,
                          decoration: _dec(
                            label: 'Ссылка на обновление *',
                            hint: 'https://...',
                            icon: Icons.link,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: descrCtrl,
                          maxLines: 2,
                          decoration: _dec(
                            label: 'Описание (необязательно)',
                            hint: 'Что нового в обновлении?',
                            icon: Icons.description,
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: targetVersionCtrl,
                          decoration: _dec(
                            label: 'Целевая версия *',
                            hint: _appVersion.isNotEmpty
                                ? 'Текущая у вас: $_appVersion'
                                : 'Например: 1.2.2',
                            icon: Icons.verified,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ---------- ACTIONS
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                  child: Row(
                    children: [
                      // Очистить уведомление (DELETE на сервер)
                      Tooltip(
                        message: 'Удалить уведомление',
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.amber.shade600,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.all(12),
                            shape: const CircleBorder(),
                            elevation: 1,
                          ),
                          onPressed: () async {
                            try {
                              await _clearUpdateNoticeOnServer();
                              await _cacheNoticeLocally(null);
                              if (mounted) {
                                setState(() => _updateNotice = null);
                                Navigator.pop(ctx);
                                _toastInfo('Уведомление очищено (глобально)');
                              }
                            } catch (e) {
                              _toastError('Ошибка удаления: $e');
                            }
                          },
                          child: const Icon(Icons.delete_forever),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Отмена'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.send),
                        label: const Text('Опубликовать'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () async {
                          final title = titleCtrl.text.trim();
                          final link = linkCtrl.text.trim();
                          final description = descrCtrl.text.trim();
                          final target = targetVersionCtrl.text.trim();

                          if (title.isEmpty || link.isEmpty || target.isEmpty) {
                            _toastError('Заполните тему, ссылку и целевую версию');
                            return;
                          }

                          final notice = <String, dynamic>{
                            'title': title,
                            'link': link,
                            'description': description.isEmpty ? null : description,
                            'targetVersion': target,
                          };

                          try {
                            await _publishUpdateNoticeToServer(notice);
                            await _cacheNoticeLocally(notice);
                            if (mounted) {
                              setState(() => _updateNotice = notice);
                              Navigator.pop(ctx);
                              _toastInfo('Уведомление опубликовано (глобально)');
                            }
                          } catch (e) {
                            _toastError('Ошибка публикации: $e');
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showUserInfo() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Информация о пользователе'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ID: $_userId'),
              Text('Роль: $_userRole'),
              Text('Сервер: ${AppConfig.serverUrl}'),
              Text('Версия приложения: $_appVersion'),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'))
          ],
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        );
      },
    );
  }

  void _showRoleChangeDialog(String role) {
    final roleName = role == 'admin' ? 'администратора' : 'пользователя';
    String userId = '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Назначить $roleName'),
          content: TextField(
            decoration: const InputDecoration(
              labelText: 'ID пользователя',
              hintText: 'Введите ID пользователя',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => userId = value,
            keyboardType: TextInputType.number,
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена')),
            TextButton(
              onPressed: () {
                if (userId.isNotEmpty) {
                  _updateUserRole(userId, role);
                  Navigator.pop(context);
                } else {
                  _toastError('Введите ID пользователя');
                }
              },
              child: Text('Назначить $roleName'),
            ),
          ],
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        );
      },
    );
  }

  void _showRemoveAdminDialog() {
    String userId = '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Снять права администратора'),
          content: TextField(
            decoration: const InputDecoration(
              labelText: 'ID администратора',
              hintText: 'Введите ID пользователя',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => userId = value,
            keyboardType: TextInputType.number,
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Отмена')),
            TextButton(
              onPressed: () {
                if (userId.isNotEmpty) {
                  _updateUserRole(userId, 'user');
                  Navigator.pop(context);
                } else {
                  _toastError('Введите ID пользователя');
                }
              },
              child: const Text('Снять права'),
            ),
          ],
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        );
      },
    );
  }

  Widget _buildBody() {
    if (_isAdminOrDeveloper) {
      if (_tabController == null) {
        return NestedScrollView(
          headerSliverBuilder: (context, _) =>
          [SliverToBoxAdapter(child: _buildHeaderWithOptionalTabs())],
          body: const Center(child: CircularProgressIndicator()),
        );
      }

      return NestedScrollView(
        headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
          return [SliverToBoxAdapter(child: _buildHeaderWithOptionalTabs())];
        },
        body: TabBarView(
          controller: _tabController!,
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: _roleContent('user'),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: _roleContent('student'),
            ),
            SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: _roleContent('teacher'),
            ),
          ],
        ),
      );
    }

    return NestedScrollView(
      headerSliverBuilder: (BuildContext context, bool innerBoxIsScrolled) {
        return [SliverToBoxAdapter(child: _buildHeaderWithOptionalTabs())];
      },
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: _roleContent(_userRole),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawerEnableOpenDragGesture: true,
      drawerEdgeDragWidth: MediaQuery.of(context).size.width * 0.25,
      drawer: ProfileDrawer(
        userRole: _userRole,
        userId: _userId,
        serverUrl: AppConfig.serverUrl,
        checkServerStatus: _checkServerStatus,
        onOpenAdminPanel: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminPanelScreen()),
          );
          _refreshTodayPanels();
        },
        onOpenDeveloperTools: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DeveloperToolsScreen()),
          );
          _refreshTodayPanels();
        },
        onOpenStudentScheduleEditor: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AdminScheduleEditor()),
          );
          _refreshTodayPanels();
        },
        onOpenTeacherScheduleEditor: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AdminScheduleTeacherEditor()),
          );
          _refreshTodayPanels();
        },
        // 👇 пробрасываем тост как showSnackBar
        showSnackBar: (msg) => OverlayToast.instance.info(msg, position: ToastPosition.top),
        onUserDataChanged: ({required String role, required String? userId}) {
          if (!mounted) return;
          setState(() {
            _userRole = role;
            _userId = userId;
            _ensureTabs();
          });
          _refreshTodayPanels();
        },
      ),
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: _buildAppBar(),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: _buildBody(),
      ),
      floatingActionButton: _isAdminOrDeveloper
          ? FloatingActionButton(
        onPressed: () async {
          if (_userRole == 'developer') {
            await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const DeveloperToolsScreen()),
            );
          } else {
            await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const AdminPanelScreen()),
            );
          }
          _refreshTodayPanels();
        },
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: _userRole == 'developer'
                  ? [Colors.purple, Colors.blue]
                  : [Colors.blue, Colors.green],
            ),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Icon(
            _userRole == 'developer'
                ? Icons.developer_mode
                : Icons.admin_panel_settings_outlined,
            color: Colors.white,
            size: 30,
          ),
        ),
      )
          : null,
    );
  }
}

// ==== INDICATOR ==============================================================
class FancyUnderlineGradientIndicator extends Decoration {
  final TabController controller;
  final List<Color> palette;
  final double thickness;
  final double horizontalPadding;
  final double blurSigma;

  const FancyUnderlineGradientIndicator({
    required this.controller,
    required this.palette,
    this.thickness = 3.0,
    this.horizontalPadding = 16.0,
    this.blurSigma = 0.0,
  });

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _FancyUnderlineGradientPainter(
      controller: controller,
      palette: palette,
      thickness: thickness,
      horizontalPadding: horizontalPadding,
      blurSigma: blurSigma,
    );
  }
}

class _FancyUnderlineGradientPainter extends BoxPainter {
  final TabController controller;
  final List<Color> palette;
  final double thickness;
  final double horizontalPadding;
  final double blurSigma;

  _FancyUnderlineGradientPainter({
    required this.controller,
    required this.palette,
    required this.thickness,
    required this.horizontalPadding,
    required this.blurSigma,
  });

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration config) {
    if (config.size == null) return;

    final rect = offset & config.size!;
    final lineRect = Rect.fromLTWH(
      rect.left + horizontalPadding,
      rect.bottom - thickness,
      rect.width - horizontalPadding * 2,
      thickness,
    );

    final double anim = controller.animation?.value ?? controller.index.toDouble();
    final int base = anim.floor().clamp(0, controller.length - 1);
    final int next = (base + 1).clamp(0, controller.length - 1);
    final double t = (anim - base).clamp(0.0, 1.0);

    final Color cBase = palette[base % palette.length];
    final Color cNext = palette[next % palette.length];

    final Color start = Color.lerp(cBase, cNext, t) ?? cBase;
    final Color end =
        Color.lerp(cBase.withOpacity(.6), cNext.withOpacity(.6), t) ?? cBase.withOpacity(.6);

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [start, end],
      ).createShader(lineRect)
      ..style = PaintingStyle.fill;

    if (blurSigma > 0) {
      paint.maskFilter = MaskFilter.blur(BlurStyle.normal, blurSigma);
    }

    final rrect = RRect.fromRectAndRadius(lineRect, Radius.circular(thickness / 2));
    canvas.drawRRect(rrect, paint);
  }
}

// ==== КНОПКА В ЛИСТЕ ДЕВ-ИНСТРУМЕНТОВ ======================================
class DevActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<Color>? gradient;
  final VoidCallback onTap;

  const DevActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              colors: gradient ??
                  [
                    AppColors.primary,
                    Color.lerp(AppColors.primary, scheme.secondary, .25)!
                  ],
            ),
            boxShadow: [
              BoxShadow(
                color:
                (gradient ?? [scheme.primary, scheme.secondary]).last.withOpacity(.25),
                blurRadius: 14,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withOpacity(.25)),
                ),
                child: Icon(icon, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .1,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white70),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// ==== Мигающий мегафон в баннере ============================================
class _BlinkingMegaphone extends StatefulWidget {
  const _BlinkingMegaphone({
    Key? key,
    required this.color,
    this.size = 24,
    this.period = const Duration(milliseconds: 1200),
  }) : super(key: key);

  final Color color;
  final double size;
  final Duration period;

  @override
  State<_BlinkingMegaphone> createState() => _BlinkingMegaphoneState();
}

class _BlinkingMegaphoneState extends State<_BlinkingMegaphone>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
  AnimationController(vsync: this, duration: widget.period)..repeat(reverse: true);
  late final Animation<double> _opacity =
  Tween(begin: 0.45, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Icon(Icons.campaign_rounded, color: widget.color, size: widget.size),
    );
  }
}

/// ======= ВИДЖЕТ ДЫШАЩЕГО СВЕТЯЩЕГОСЯ БОРДЕРА ===============================
class _BreathingGlow extends StatefulWidget {
  const _BreathingGlow({
    Key? key,
    required this.child,
    required this.gradient,
    this.borderRadius = 16,
    this.stroke = 2.0,
    this.margin = EdgeInsets.zero,
  }) : super(key: key);

  final Widget child;
  final Gradient gradient;
  final double borderRadius;
  final double stroke;
  final EdgeInsetsGeometry margin;

  @override
  State<_BreathingGlow> createState() => _BreathingGlowState();
}

class _BreathingGlowState extends State<_BreathingGlow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ac =
  AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
    ..repeat(reverse: true);
  late final Animation<double> _t =
  CurvedAnimation(parent: _ac, curve: Curves.easeInOut);

  @override
  void dispose() {
    _ac.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.borderRadius);
    return AnimatedBuilder(
      animation: _t,
      builder: (context, _) {
        final glowOpacity = 0.25 + 0.25 * _t.value; // 0.25..0.50
        final spread = 2.0 + 3.0 * _t.value;         // мягкое «дыхание»
        final blur = 10.0 + 10.0 * _t.value;

        return Container(
          margin: widget.margin,
          decoration: BoxDecoration(
            borderRadius: radius,
            boxShadow: [
              BoxShadow(
                color: Colors.blueAccent.withOpacity(glowOpacity),
                blurRadius: blur,
                spreadRadius: spread,
              ),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: radius,
              gradient: widget.gradient,
            ),
            padding: EdgeInsets.all(widget.stroke),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: radius.subtract(const BorderRadius.all(Radius.circular(2))),
              ),
              child: widget.child,
            ),
          ),
        );
      },
    );
  }
}
