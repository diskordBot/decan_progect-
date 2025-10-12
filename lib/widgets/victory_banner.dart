import 'package:decanat_progect/screens/news_screen.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants.dart';

class VictoryBanner extends StatefulWidget {
  const VictoryBanner({super.key});

  @override
  State<VictoryBanner> createState() => _VictoryBannerState();
}

class _VictoryBannerState extends State<VictoryBanner> {
  Map<String, dynamic>? _latestNews;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchLatestNews();
  }

  Future<void> _fetchLatestNews() async {
    try {
      final response = await http.get(
        Uri.parse('${AppConfig.serverUrl}/api/news/latest'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final news = json.decode(response.body);
        setState(() {
          _latestNews = news;
          _isLoading = false;
        });

        // Кэшируем последнюю новость
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('latest_news', json.encode(news));
        await prefs.setInt('latest_news_timestamp',
            DateTime.now().millisecondsSinceEpoch);
      } else {
        // Пробуем загрузить из кэша
        await _loadCachedNews();
      }
    } catch (e) {
      // Пробуем загрузить из кэша при ошибке
      await _loadCachedNews();
    }
  }

  Future<void> _loadCachedNews() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('latest_news');
    final cachedTimestamp = prefs.getInt('latest_news_timestamp');

    if (cached != null && cachedTimestamp != null) {
      final cachedDate = DateTime.fromMillisecondsSinceEpoch(cachedTimestamp);
      final now = DateTime.now();

      // Кэш действителен 1 день
      if (now.difference(cachedDate).inHours <= 24) {
        setState(() {
          _latestNews = json.decode(cached);
          _isLoading = false;
        });
        return;
      }
    }

    setState(() {
      _isLoading = false;
      _hasError = true;
    });
  }

  void _navigateToNewsScreen() {
    if (_latestNews != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const NewsScreen(),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _navigateToNewsScreen,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 5),
        decoration: BoxDecoration(
          color: AppColors.primary,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(15)),
        ),
        child: _buildBannerContent(),
      ),
    );
  }

  Widget _buildBannerContent() {
    if (_isLoading) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(height: 120),
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Загрузка новостей...',
            style: TextStyle(color: Colors.white),
          ),
        ],
      );
    }

    if (_hasError || _latestNews == null) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.asset(
              'assets/images/donnty.png',
              height: 240,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Мы встретили первокурсников!\nДобро пожаловать в ДонНТУ!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.3,
            ),
          ),
        ],
      );
    }

    final news = _latestNews!;
    final imageUrl = news['image_url'] is List && (news['image_url'] as List).isNotEmpty
        ? (news['image_url'] as List).first
        : news['image_url']?.toString();

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (imageUrl != null && imageUrl.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              imageUrl,
              height: 240,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  _buildDefaultImage(),
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  height: 240,
                  color: Colors.grey[300],
                  child: const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                );
              },
            ),
          )
        else
          _buildDefaultImage(),

        const SizedBox(height: 8),
        Text(
          news['title'] ?? 'Новая новость',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            height: 1.3,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          'Нажмите для подробностей',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.8),
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildDefaultImage() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        'assets/images/donnty.png',
        height: 240,
        fit: BoxFit.contain,
      ),
    );
  }
}