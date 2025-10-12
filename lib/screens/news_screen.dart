import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

// ✅ Добавили: единый синий AppBar как на всех экранах
import '../widgets/custom_app_bar.dart';

class NewsScreen extends StatefulWidget {
  const NewsScreen({super.key});

  @override
  State<NewsScreen> createState() => _NewsScreenState();
}

class _NewsScreenState extends State<NewsScreen> {
  List<dynamic> _newsList = [];
  bool _isLoading = true;
  bool _isOffline = false;
  String _userRole = 'user'; // роль пользователя

  static const int cacheLifetimeDays = 10;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
    _loadCachedNews().then((_) {
      _fetchNews();
    });
  }

  Future<void> _loadUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _userRole = prefs.getString('userRole') ?? 'user';
    });
  }

  Future<void> _loadCachedNews() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('cached_news');
    final cachedTimestamp = prefs.getInt('cached_news_timestamp');

    if (cached != null && cachedTimestamp != null) {
      final cachedDate =
      DateTime.fromMillisecondsSinceEpoch(cachedTimestamp);
      final now = DateTime.now();

      if (now.difference(cachedDate).inDays > cacheLifetimeDays) {
        await prefs.remove('cached_news');
        await prefs.remove('cached_news_timestamp');
        return;
      }

      setState(() {
        _newsList = json.decode(cached);
        _isLoading = false;
        _isOffline = true;
      });
    }
  }

  Future<void> _cacheNews(List<dynamic> news) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_news', json.encode(news));
    await prefs.setInt(
        'cached_news_timestamp', DateTime.now().millisecondsSinceEpoch);
  }

  Future<void> _fetchNews() async {
    setState(() {
      _isLoading = true;
      _isOffline = false;
    });

    try {
      final response =
      await http.get(Uri.parse('${AppConfig.serverUrl}/api/news'));

      if (response.statusCode == 200) {
        final List<dynamic> news = json.decode(response.body);
        setState(() {
          _newsList = news;
          _isLoading = false;
        });
        await _cacheNews(news);
      } else {
        throw Exception('Ошибка ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        if (_newsList.isNotEmpty) {
          _isOffline = true;
        }
      });
    }
  }

  Future<void> _deleteNews(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId') ?? '000000';

    try {
      final response = await http.delete(
        Uri.parse('${AppConfig.serverUrl}/api/news/$id?user_id=$userId'),
      );

      if (response.statusCode == 200) {
        setState(() {
          _newsList.removeWhere((news) => news['id'] == id);
        });
        await _cacheNews(_newsList);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Новость удалена')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка: $e')),
      );
    }
  }

  Future<void> _onRefresh() async {
    await _fetchNews();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,

      appBar: const CustomAppBar(
        title: 'Новости ДонНТУ',
        showBackButton: false,
      ),

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _newsList.isEmpty
          ? const Center(child: Text('Нет новостей'))
          : RefreshIndicator(
        onRefresh: _onRefresh,
        child: ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: _newsList.length + (_isOffline ? 1 : 0),
          itemBuilder: (context, index) {
            if (_isOffline && index == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Center(
                  child: Text(
                    'Показаны оффлайн-новости',
                    style: TextStyle(
                      color: Colors.orange[300],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              );
            }
            final news =
            _newsList[_isOffline ? index - 1 : index];
            return _buildNewsItem(context, news);
          },
          // красивый разделитель
          separatorBuilder: (context, index) => _buildFancyDivider(),
        ),
      ),
    );
  }

  Widget _buildNewsItem(BuildContext context, Map<String, dynamic> news) {
    final previewText =
    news['text'].toString().split('\n').take(5).join('\n');

    final List<String> images = [];
    if (news['image_url'] != null &&
        news['image_url'].toString().isNotEmpty) {
      if (news['image_url'] is List) {
        images.addAll(List<String>.from(news['image_url']));
      } else {
        images.add(news['image_url'].toString());
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: Theme.of(context).cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (images.isNotEmpty)
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FullScreenGallery(images: images),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                constraints: const BoxConstraints(
                  minHeight: 200,
                  maxHeight: 400,
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                  child: Image.network(
                    images.first,
                    fit: BoxFit.contain, // оставляем contain
                    width: double.infinity,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        height: 200,
                        color: Colors.grey[300],
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) => Container(
                      height: 200,
                      color: Colors.grey[300],
                      child: const Icon(
                        Icons.broken_image,
                        size: 64,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        news['title'] ?? 'Без названия',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (_userRole == 'admin' || _userRole == 'developer')
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        tooltip: 'Удалить новость',
                        onPressed: () => _deleteNews(news['id']),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  previewText,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),

                // 🔗 Ссылка на телеграм-канал
                InkWell(
                  onTap: () async {
                    final Uri url = Uri.parse("https://t.me/studdonntu");
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url,
                          mode: LaunchMode.externalApplication);
                    }
                  },
                  child: Text(
                    'Подробнее у нас в телеграм-канале',
                    style: TextStyle(
                      color: Colors.blue[400],
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Красивый разделитель с градиентными линиями и точкой
  Widget _buildFancyDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 3,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red, Colors.transparent],
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: CircleAvatar(
              radius: 5,
              backgroundColor: Colors.blue,
            ),
          ),
          Expanded(
            child: Container(
              height: 3,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.red, Colors.transparent],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Экран просмотра изображений
class FullScreenGallery extends StatefulWidget {
  final List<String> images;

  const FullScreenGallery({super.key, required this.images});

  @override
  State<FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<FullScreenGallery>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  int _currentIndex = 0;

  final TransformationController _transformationController =
  TransformationController();
  Animation<Matrix4>? _animation;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..addListener(() {
      _transformationController.value = _animation!.value;
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  /// Анимация к новой трансформации
  void _animateTo(Matrix4 endMatrix) {
    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: endMatrix,
    ).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
    _animationController.forward(from: 0);
  }

  /// Сброс масштаба
  void _resetAnimation() {
    _animateTo(Matrix4.identity());
  }

  /// Двойной тап: увеличить/уменьшить
  void _handleDoubleTap(TapDownDetails details) {
    final currentScale =
    _transformationController.value.getMaxScaleOnAxis();

    if (currentScale == 1.0) {
      // Увеличиваем ×2 и центрируем по тапу
      final position = details.localPosition;
      final zoomed = Matrix4.identity()
        ..translate(-position.dx, -position.dy)
        ..scale(2.0); // масштаб х2
      _animateTo(zoomed);
    } else {
      // Возврат к норме
      _resetAnimation();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withOpacity(0.2),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          "${_currentIndex + 1}/${widget.images.length}",
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.images.length,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
          _resetAnimation(); // при смене фото сброс
        },
        itemBuilder: (context, index) {
          return GestureDetector(
            onDoubleTapDown: _handleDoubleTap, // ловим координаты
            onScaleEnd: (_) => _resetAnimation(), // после жеста вернуть
            child: InteractiveViewer(
              transformationController: _transformationController,
              panEnabled: true,
              clipBehavior: Clip.none,
              minScale: 1,
              maxScale: 5,
              child: Image.network(
                widget.images[index],
                fit: BoxFit.contain, // оставляем contain
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                          : null,
                      color: Colors.white,
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) => Center(
                  child: Icon(
                    Icons.broken_image,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
