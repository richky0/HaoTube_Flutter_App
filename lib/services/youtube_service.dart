import 'dart:convert';
import 'package:http/http.dart' as http;

class YouTubeService {
  static const String _apiKey = 'AIzaSyDLqvCUzYm8qHjk0hGnw9z3KG-a3dY6KCg';
  static const String _baseUrl = 'https://www.googleapis.com/youtube/v3';

  static Future<List<YouTubeVideo>> getRandomPopularVideos() async {
    try {
      print('🚀 MEMUAT VIDEO TRENDING DARI YOUTUBE API...');

      final response = await http.get(
        Uri.parse(
          '$_baseUrl/videos?part=snippet,statistics,contentDetails&chart=mostPopular&regionCode=US&maxResults=20&key=$_apiKey',
        ),
      );

      print('📡 Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✅ DATA API DITERIMA: ${data['items']?.length ?? 0} video');

        final videos = _parseVideos(data);
        final validVideos = _filterValidVideos(videos);

        if (validVideos.isEmpty) {
          throw Exception('Tidak ada video valid yang ditemukan dari API');
        }

        print('🎉 BERHASIL: ${validVideos.length} video trending dimuat');
        return validVideos;
      } else {
        final errorData = json.decode(response.body);
        final errorMessage = errorData['error']['message'] ?? 'Unknown error';
        final errorCode = errorData['error']['code'] ?? response.statusCode;

        print('❌ API ERROR $errorCode: $errorMessage');

        // JANGAN gunakan fallback, lempar exception agar user tahu ada masalah
        throw Exception('YouTube API Error $errorCode: $errorMessage\n\n'
            'Pastikan:\n'
            '1. API Key valid\n'
            '2. YouTube Data API v3 sudah dienable\n'
            '3. Koneksi internet stabil');
      }
    } catch (e) {
      print('💥 CRITICAL ERROR: $e');

      // HANYA untuk debugging, tampilkan error detail
      throw Exception('GAGAL MEMUAT VIDEO TRENDING:\n$e\n\n'
          'Silakan periksa:\n'
          '- Koneksi internet\n'
          '- Konfigurasi API Key\n'
          '- Status YouTube Data API');
    }
  }

  static Future<List<YouTubeVideo>> searchVideos(String query) async {
    try {
      print('🔍 MENCARI: "$query"');

      final cleanQuery = Uri.encodeComponent(query.trim());

      final response = await http.get(
        Uri.parse(
          '$_baseUrl/search?part=snippet&type=video&maxResults=20&q=$cleanQuery&key=$_apiKey',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final searchResults = _parseSearchResults(data);

        if (searchResults.isEmpty) {
          throw Exception('Tidak ada hasil untuk "$query"');
        }

        final detailedVideos = await _getVideosDetails(searchResults);
        final validVideos = _filterValidVideos(detailedVideos);

        print('✅ DITEMUKAN: ${validVideos.length} video untuk "$query"');
        return validVideos;
      } else {
        final errorData = json.decode(response.body);
        throw Exception('Pencarian gagal: ${errorData['error']['message']}');
      }
    } catch (e) {
      print('❌ SEARCH ERROR: $e');
      rethrow; // Lempar exception ke UI
    }
  }

  static Future<List<YouTubeVideo>> _getVideosDetails(List<YouTubeVideo> videos) async {
    try {
      if (videos.isEmpty) return videos;

      final videoIds = videos.map((video) => video.id).join(',');

      final response = await http.get(
        Uri.parse(
          '$_baseUrl/videos?part=snippet,statistics,contentDetails&id=$videoIds&key=$_apiKey',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return _parseMultipleVideoDetails(data, videos);
      } else {
        return videos; // Return tanpa details jika gagal
      }
    } catch (e) {
      print('⚠️ Detail video error: $e');
      return videos;
    }
  }

  static List<YouTubeVideo> _parseVideos(Map<String, dynamic> data) {
    final List<YouTubeVideo> videos = [];

    for (var item in data['items']) {
      try {
        if (item['snippet'] == null || item['id'] == null) continue;

        final snippet = item['snippet'];
        final statistics = item['statistics'] ?? {};
        final contentDetails = item['contentDetails'] ?? {};

        final video = YouTubeVideo(
          id: item['id'] is String ? item['id'] : 'unknown',
          title: snippet['title']?.toString() ?? 'No Title',
          description: snippet['description']?.toString() ?? 'No description',
          thumbnailUrl: _getBestThumbnail(snippet['thumbnails']),
          channelTitle: snippet['channelTitle']?.toString() ?? 'Unknown Channel',
          publishedAt: snippet['publishedAt']?.toString() ?? '',
          viewCount: statistics['viewCount']?.toString() ?? '0',
          likeCount: statistics['likeCount']?.toString() ?? '0',
          duration: _parseDuration(contentDetails['duration'] ?? 'PT0M0S'),
        );

        videos.add(video);
      } catch (e) {
        print('⚠️ Parse error: $e');
        continue;
      }
    }

    return videos;
  }

  static List<YouTubeVideo> _parseSearchResults(Map<String, dynamic> data) {
    final List<YouTubeVideo> videos = [];

    for (var item in data['items']) {
      try {
        if (item['snippet'] == null || item['id'] == null) continue;

        final snippet = item['snippet'];

        videos.add(YouTubeVideo(
          id: item['id']['videoId'] ?? 'unknown',
          title: snippet['title']?.toString() ?? 'No Title',
          description: snippet['description']?.toString() ?? 'No description',
          thumbnailUrl: _getBestThumbnail(snippet['thumbnails']),
          channelTitle: snippet['channelTitle']?.toString() ?? 'Unknown Channel',
          publishedAt: snippet['publishedAt']?.toString() ?? '',
          viewCount: '0',
          likeCount: '0',
          duration: 'Loading...',
        ));
      } catch (e) {
        continue;
      }
    }

    return videos;
  }

  static List<YouTubeVideo> _parseMultipleVideoDetails(Map<String, dynamic> data, List<YouTubeVideo> originalVideos) {
    final Map<String, dynamic> videoDetailsMap = {};

    for (var item in data['items']) {
      videoDetailsMap[item['id']] = item;
    }

    return originalVideos.map((video) {
      final details = videoDetailsMap[video.id];
      if (details != null) {
        final snippet = details['snippet'];
        final statistics = details['statistics'] ?? {};
        final contentDetails = details['contentDetails'] ?? {};

        return YouTubeVideo(
          id: video.id,
          title: snippet['title']?.toString() ?? video.title,
          description: snippet['description']?.toString() ?? video.description,
          thumbnailUrl: _getBestThumbnail(snippet['thumbnails']),
          channelTitle: snippet['channelTitle']?.toString() ?? video.channelTitle,
          publishedAt: snippet['publishedAt']?.toString() ?? video.publishedAt,
          viewCount: statistics['viewCount']?.toString() ?? video.viewCount,
          likeCount: statistics['likeCount']?.toString() ?? video.likeCount,
          duration: _parseDuration(contentDetails['duration'] ?? 'PT0M0S'),
        );
      }
      return video;
    }).toList();
  }

  static String _getBestThumbnail(Map<String, dynamic>? thumbnails) {
    if (thumbnails == null) return '';

    if (thumbnails['maxres'] != null) return thumbnails['maxres']['url'] as String? ?? '';
    if (thumbnails['standard'] != null) return thumbnails['standard']['url'] as String? ?? '';
    if (thumbnails['high'] != null) return thumbnails['high']['url'] as String? ?? '';
    if (thumbnails['medium'] != null) return thumbnails['medium']['url'] as String? ?? '';
    if (thumbnails['default'] != null) return thumbnails['default']['url'] as String? ?? '';

    return '';
  }

  static String _parseDuration(String isoDuration) {
    try {
      if (isoDuration.isEmpty || isoDuration == 'PT0S') return '0:00';

      String duration = isoDuration.replaceFirst('PT', '');
      String hours = '0', minutes = '0', seconds = '0';

      if (duration.contains('H')) {
        final parts = duration.split('H');
        hours = parts[0];
        duration = parts.length > 1 ? parts[1] : '';
      }
      if (duration.contains('M')) {
        final parts = duration.split('M');
        minutes = parts[0];
        duration = parts.length > 1 ? parts[1] : '';
      }
      if (duration.contains('S')) {
        final parts = duration.split('S');
        seconds = parts[0];
      }

      final int h = int.tryParse(hours) ?? 0;
      final int m = int.tryParse(minutes) ?? 0;
      final int s = int.tryParse(seconds) ?? 0;

      if (h > 0) return '$h:${_padZero(m)}:${_padZero(s)}';
      if (m > 0) return '$m:${_padZero(s)}';
      return '0:${_padZero(s)}';
    } catch (e) {
      return '0:00';
    }
  }

  static String _padZero(dynamic number) {
    final num = int.tryParse(number.toString()) ?? 0;
    return num.toString().padLeft(2, '0');
  }

  static List<YouTubeVideo> _filterValidVideos(List<YouTubeVideo> videos) {
    return videos.where((video) {
      final lowerTitle = video.title.toLowerCase();
      return !lowerTitle.contains('deleted video') &&
          !lowerTitle.contains('private video') &&
          !lowerTitle.contains('unavailable') &&
          video.id != 'unknown' &&
          video.thumbnailUrl.isNotEmpty &&
          video.title.isNotEmpty &&
          video.title != 'No Title';
    }).toList();
  }
}

class YouTubeVideo {
  final String id;
  final String title;
  final String description;
  final String thumbnailUrl;
  final String channelTitle;
  final String publishedAt;
  final String viewCount;
  final String likeCount;
  final String duration;

  YouTubeVideo({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.channelTitle,
    required this.publishedAt,
    required this.viewCount,
    required this.likeCount,
    required this.duration,
  });

  @override
  String toString() {
    return 'YouTubeVideo{id: $id, title: $title, channel: $channelTitle}';
  }
}