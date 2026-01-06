import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:youtube_player_flutter/youtube_player_flutter.dart';
import 'services/youtube_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HaoTube',
      theme: ThemeData(
        primaryColor: const Color(0xFF1a73e8),
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF1a73e8),
          secondary: Color(0xFFfbbc04),
          surface: Color(0xFFf8f9fa),
        ),
        scaffoldBackgroundColor: const Color(0xFFf8f9fa),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 1,
          titleTextStyle: GoogleFonts.poppins(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 20,
          ),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Color(0xFF1a73e8),
          unselectedItemColor: Color(0xFF5f6368),
        ),
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// VIDEO PLAYER MANAGER - Pendekatan yang Lebih Sederhana
class VideoPlayerManager {
  // Singleton instance
  static final VideoPlayerManager _instance = VideoPlayerManager._internal();
  factory VideoPlayerManager() => _instance;
  VideoPlayerManager._internal();

  // Single controller instance
  YoutubePlayerController? _controller;
  String? _currentVideoId;
  String? _currentVideoTitle;
  bool _isMiniPlayerVisible = false;

  // Callback untuk UI updates
  VoidCallback? _onUpdate;

  // Getters
  YoutubePlayerController? get controller => _controller;
  String? get currentVideoId => _currentVideoId;
  String? get currentVideoTitle => _currentVideoTitle;
  bool get isMiniPlayerVisible => _isMiniPlayerVisible;

  // Set callback untuk UI updates
  void setOnUpdate(VoidCallback callback) {
    _onUpdate = callback;
  }

  void _notify() {
    _onUpdate?.call();
  }

  // Initialize atau reuse controller
  void initializeController(String videoId, String videoTitle) {
    // Jika sudah ada controller untuk video yang sama, reuse
    if (_controller != null && _currentVideoId == videoId) {
      return;
    }

    // Dispose controller lama jika ada
    _controller?.dispose();

    // Buat controller baru
    _controller = YoutubePlayerController(
      initialVideoId: videoId,
      flags: const YoutubePlayerFlags(
        autoPlay: true,
        mute: false,
        forceHD: false,
        hideControls: false,
        controlsVisibleAtStart: true,
        enableCaption: false,
        isLive: false,
      ),
    );

    _currentVideoId = videoId;
    _currentVideoTitle = videoTitle;

    _notify();
  }

  // Show/hide miniplayer
  void showMiniPlayer() {
    _isMiniPlayerVisible = true;
    _notify();
  }

  void hideMiniPlayer() {
    _isMiniPlayerVisible = false;
    _notify();
  }

  // Toggle play/pause
  void togglePlayPause() {
    if (_controller != null) {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
      } else {
        _controller!.play();
      }
      _notify();
    }
  }

  // Cleanup
  void disposeController() {
    _controller?.dispose();
    _controller = null;
    _currentVideoId = null;
    _currentVideoTitle = null;
    _isMiniPlayerVisible = false;
    _notify();
  }
}

// Global instance
final videoManager = VideoPlayerManager();

// FULLSCREEN VIDEO PLAYER - Versi Stabil
class FullscreenVideoPlayer extends StatefulWidget {
  final String videoId;
  final String videoTitle;

  const FullscreenVideoPlayer({
    super.key,
    required this.videoId,
    required this.videoTitle,
  });

  @override
  State<FullscreenVideoPlayer> createState() => _FullscreenVideoPlayerState();
}

class _FullscreenVideoPlayerState extends State<FullscreenVideoPlayer> {
  bool _showTitle = false;
  Timer? _titleTimer;
  bool _isExiting = false;

  @override
  void initState() {
    super.initState();

    // Pastikan controller sudah ada
    if (videoManager.controller == null ||
        videoManager.currentVideoId != widget.videoId) {
      videoManager.initializeController(widget.videoId, widget.videoTitle);
    }

    // Set fullscreen mode
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setFullscreen();
    });

    _showTitleTemporarily();
  }

  void _setFullscreen() {
    // Landscape orientation
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    // Hide system UI
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
  }

  void _exitFullscreen() {
    // Restore portrait
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);

    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.edgeToEdge,
      overlays: SystemUiOverlay.values,
    );
  }

  void _showTitleTemporarily() {
    setState(() => _showTitle = true);
    _titleTimer?.cancel();
    _titleTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _showTitle = false);
      }
    });
  }

  @override
  void dispose() {
    _titleTimer?.cancel();
    _exitFullscreen();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = videoManager.controller;
    if (controller == null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF1a73e8)),
        ),
      );
    }

    return WillPopScope(
      onWillPop: () async {
        _handleExit();
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: GestureDetector(
          onTap: _showTitleTemporarily,
          child: Stack(
            children: [
              // Video Player
              YoutubePlayer(
                controller: controller,
                aspectRatio: 16 / 9,
                showVideoProgressIndicator: true,
                progressIndicatorColor: const Color(0xFF1a73e8),
                progressColors: const ProgressBarColors(
                  playedColor: Color(0xFF1a73e8),
                  handleColor: Color(0xFF1a73e8),
                  bufferedColor: Colors.grey,
                  backgroundColor: Colors.grey,
                ),
                bottomActions: [
                  CurrentPosition(),
                  ProgressBar(
                    isExpanded: true,
                    colors: const ProgressBarColors(
                      playedColor: Color(0xFF1a73e8),
                      handleColor: Color(0xFF1a73e8),
                    ),
                  ),
                  RemainingDuration(),
                  IconButton(
                    icon: Icon(Icons.fullscreen_exit, color: Colors.white),
                    onPressed: _handleExit,
                  ),
                ],
              ),

              // Back button
              if (_showTitle)
                Positioned(
                  top: 10,
                  left: 10,
                  child: GestureDetector(
                    onTap: _handleExit,
                    child: Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.arrow_back, color: Colors.white, size: 24),
                    ),
                  ),
                ),

              // Title
              if (_showTitle)
                Positioned(
                  top: 10,
                  left: 60,
                  right: 60,
                  child: Center(
                    child: Text(
                      widget.videoTitle,
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleExit() {
    if (_isExiting) return;
    _isExiting = true;

    Navigator.of(context).pop();
  }
}

// YOUTUBE PLAYER WIDGET - Sederhana
class YouTubePlayerWidget extends StatelessWidget {
  final String videoId;
  final String videoTitle;

  const YouTubePlayerWidget({
    super.key,
    required this.videoId,
    required this.videoTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(8),
      ),
      child: videoManager.controller != null &&
          videoManager.currentVideoId == videoId
          ? YoutubePlayer(
        controller: videoManager.controller!,
        aspectRatio: 16 / 9,
        showVideoProgressIndicator: true,
        progressIndicatorColor: const Color(0xFF1a73e8),
        progressColors: const ProgressBarColors(
          playedColor: Color(0xFF1a73e8),
          handleColor: Color(0xFF1a73e8),
          bufferedColor: Colors.grey,
          backgroundColor: Colors.grey,
        ),
        bottomActions: [
          CurrentPosition(),
          ProgressBar(
            isExpanded: true,
            colors: const ProgressBarColors(
              playedColor: Color(0xFF1a73e8),
              handleColor: Color(0xFF1a73e8),
            ),
          ),
          RemainingDuration(),
          IconButton(
            icon: Icon(Icons.fullscreen, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => FullscreenVideoPlayer(
                    videoId: videoId,
                    videoTitle: videoTitle,
                  ),
                  fullscreenDialog: true,
                ),
              );
            },
          ),
        ],
      )
          : Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF1a73e8)),
            SizedBox(height: 16),
            Text(
              'Memuat video...',
              style: GoogleFonts.poppins(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

// VIDEO THUMBNAIL
class VideoThumbnail extends StatelessWidget {
  final String thumbnailUrl;
  final String duration;

  const VideoThumbnail({
    super.key,
    required this.thumbnailUrl,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
            ),
            image: DecorationImage(
              image: NetworkImage(thumbnailUrl),
              fit: BoxFit.cover,
            ),
          ),
        ),
        Positioned(
          bottom: 8,
          right: 8,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.8),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              duration,
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: Center(
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// MAIN SCREEN
class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  late Future<List<YouTubeVideo>> _videosFuture;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadVideos();
    _searchFocusNode.addListener(_onSearchFocusChanged);

    // Setup update listener
    videoManager.setOnUpdate(() {
      if (mounted) setState(() {});
    });
  }

  void _onSearchFocusChanged() {
    if (!_searchFocusNode.hasFocus && _searchController.text.isEmpty) {
      setState(() => _isSearching = false);
    }
  }

  void _loadVideos() {
    _videosFuture = YouTubeService.getRandomPopularVideos();
  }

  void _refreshVideos() {
    setState(() => _loadVideos());
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _isSearching ? _buildSearchAppBar() : _buildNormalAppBar(),
      body: Stack(
        children: [
          _currentIndex == 0
              ? HomeScreen(
            videosFuture: _videosFuture,
            onRefresh: _refreshVideos,
          )
              : _buildLibraryScreen(),

          // MINI PLAYER
          if (videoManager.isMiniPlayerVisible && videoManager.controller != null)
            Positioned(
              bottom: 80,
              right: 16,
              child: _buildMiniPlayer(),
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(),
    );
  }

  Widget _buildLibraryScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.video_library, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Koleksi Video',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Fitur akan segera hadir',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavigationBar() {
    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: (index) => setState(() => _currentIndex = index),
      type: BottomNavigationBarType.fixed,
      selectedFontSize: 12,
      unselectedFontSize: 12,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Beranda',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.video_library_outlined),
          activeIcon: Icon(Icons.video_library),
          label: 'Koleksi',
        ),
      ],
    );
  }

  PreferredSizeWidget _buildNormalAppBar() {
    return AppBar(
      title: Row(
        children: [
          Text(
            'HaoTube',
            style: GoogleFonts.poppins(
              color: const Color(0xFF1a73e8),
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          SizedBox(width: 4),
          Icon(Icons.play_circle_fill, color: Color(0xFFfbbc04)),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.search, color: Colors.black),
          onPressed: () {
            setState(() => _isSearching = true);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _searchFocusNode.requestFocus();
            });
          },
        ),
        IconButton(
          icon: Icon(Icons.refresh, color: Colors.black),
          onPressed: _refreshVideos,
        ),
        SizedBox(width: 8),
      ],
    );
  }

  PreferredSizeWidget _buildSearchAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      leading: IconButton(
        icon: Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () {
          setState(() {
            _isSearching = false;
            _searchController.clear();
          });
        },
      ),
      title: Container(
        height: 40,
        decoration: BoxDecoration(
          color: Color(0xFFf8f9fa),
          borderRadius: BorderRadius.circular(20),
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          decoration: InputDecoration(
            hintText: 'Cari di HaoTube...',
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 16),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
              icon: Icon(Icons.clear, color: Colors.grey, size: 20),
              onPressed: () => _searchController.clear(),
            )
                : null,
          ),
          onSubmitted: (value) {
            if (value.isNotEmpty) _navigateToSearchScreen(value);
          },
          onChanged: (value) => setState(() {}),
        ),
      ),
      actions: [
        if (_searchController.text.isNotEmpty)
          TextButton(
            onPressed: () => _navigateToSearchScreen(_searchController.text),
            child: Text(
              'CARI',
              style: GoogleFonts.poppins(
                color: Color(0xFF1a73e8),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  void _navigateToSearchScreen(String query) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchScreen(searchQuery: query),
      ),
    ).then((_) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _searchController.clear();
        });
      }
    });
  }

  Widget _buildMiniPlayer() {
    final controller = videoManager.controller!;
    final isPlaying = controller.value.isPlaying;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoDetailScreen(
              video: YouTubeVideo(
                id: videoManager.currentVideoId!,
                title: videoManager.currentVideoTitle ?? 'Video',
                thumbnailUrl: '',
                channelTitle: '',
                viewCount: '',
                publishedAt: '',
                description: '',
                duration: '',
                likeCount: '',
              ),
            ),
          ),
        );
      },
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 140,
          height: 90,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 15,
                spreadRadius: 2,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Stack(
              children: [
                // Background
                Container(
                  color: Colors.grey[800],
                  child: Center(
                    child: Icon(
                      Icons.play_circle_fill,
                      color: Colors.white.withOpacity(0.7),
                      size: 40,
                    ),
                  ),
                ),

                // Play/Pause button
                Positioned.fill(
                  child: Center(
                    child: GestureDetector(
                      onTap: () {
                        videoManager.togglePlayPause();
                      },
                      child: Container(
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isPlaying ? Icons.pause : Icons.play_arrow,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),

                // Title
                Positioned(
                  bottom: 8,
                  left: 8,
                  right: 8,
                  child: Text(
                    videoManager.currentVideoTitle ?? 'Video',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // Close button
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () {
                      videoManager.hideMiniPlayer();
                      videoManager.disposeController();
                    },
                    child: Container(
                      padding: EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.close, color: Colors.white, size: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// HOME SCREEN
class HomeScreen extends StatelessWidget {
  final Future<List<YouTubeVideo>> videosFuture;
  final VoidCallback onRefresh;

  const HomeScreen({
    super.key,
    required this.videosFuture,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        onRefresh();
        await Future.delayed(Duration(milliseconds: 500));
      },
      child: FutureBuilder<List<YouTubeVideo>>(
        future: videosFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingIndicator();
          }

          if (snapshot.hasError) {
            return _buildErrorWidget(snapshot.error.toString());
          }

          final videos = snapshot.data ?? [];

          if (videos.isEmpty) {
            return _buildEmptyVideos();
          }

          return _buildVideoList(videos, context);
        },
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF1a73e8)),
          SizedBox(height: 16),
          Text(
            'Memuat video trending dari YouTube...',
            style: GoogleFonts.poppins(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, color: Color(0xFF1a73e8), size: 64),
            SizedBox(height: 16),
            Text(
              'Gagal memuat video trending',
              style: GoogleFonts.poppins(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: 8),
            Text(
              error,
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: onRefresh,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF1a73e8),
                foregroundColor: Colors.white,
              ),
              child: Text('Coba Lagi'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyVideos() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.video_library, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Tidak ada video trending',
            style: TextStyle(color: Colors.black, fontSize: 18),
          ),
          SizedBox(height: 8),
          Text(
            'Coba refresh atau periksa koneksi internet',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoList(List<YouTubeVideo> videos, BuildContext context) {
    return ListView.builder(
      itemCount: videos.length,
      itemBuilder: (context, index) {
        final video = videos[index];
        return VideoCard(video: video);
      },
    );
  }
}

// VIDEO CARD
class VideoCard extends StatelessWidget {
  final YouTubeVideo video;

  const VideoCard({
    super.key,
    required this.video,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VideoDetailScreen(video: video),
          ),
        );
      },
      child: Container(
        margin: EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            VideoThumbnail(
              thumbnailUrl: video.thumbnailUrl,
              duration: video.duration,
            ),
            Padding(
              padding: EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    backgroundColor: Color(0xFFfbbc04).withOpacity(0.2),
                    child: Text(
                      video.channelTitle.isNotEmpty ? video.channelTitle[0] : 'Y',
                      style: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          video.title,
                          style: GoogleFonts.poppins(
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Text(
                          '${video.channelTitle} • ${_formatViewCount(video.viewCount)} views • ${_formatTimeAgo(video.publishedAt)}',
                          style: GoogleFonts.poppins(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatViewCount(String viewCount) {
    final count = int.tryParse(viewCount) ?? 0;
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  String _formatTimeAgo(String publishedAt) {
    try {
      final date = DateTime.parse(publishedAt);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 365) {
        return '${(difference.inDays / 365).floor()} tahun lalu';
      } else if (difference.inDays > 30) {
        return '${(difference.inDays / 30).floor()} bulan lalu';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} hari lalu';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} jam lalu';
      } else {
        return 'Baru saja';
      }
    } catch (e) {
      return 'Beberapa waktu lalu';
    }
  }
}

// VIDEO DETAIL SCREEN
class VideoDetailScreen extends StatelessWidget {
  final YouTubeVideo video;

  const VideoDetailScreen({
    super.key,
    required this.video,
  });

  @override
  Widget build(BuildContext context) {
    // Initialize video player
    videoManager.initializeController(video.id, video.title);
    videoManager.showMiniPlayer();

    return Scaffold(
      backgroundColor: Color(0xFFf8f9fa),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'HaoTube',
          style: GoogleFonts.poppins(
            color: Color(0xFF1a73e8),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Video Player
            YouTubePlayerWidget(
              videoId: video.id,
              videoTitle: video.title,
            ),

            // Video Info
            Container(
              padding: EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 8),
                  Row(
                    children: [
                      Text(
                        '${_formatViewCount(video.viewCount)} views',
                        style: GoogleFonts.poppins(color: Colors.grey),
                      ),
                      SizedBox(width: 8),
                      Text('•', style: GoogleFonts.poppins(color: Colors.grey)),
                      SizedBox(width: 8),
                      Text(
                        _formatTimeAgo(video.publishedAt),
                        style: GoogleFonts.poppins(color: Colors.grey),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Color(0xFFfbbc04).withOpacity(0.2),
                        radius: 20,
                        child: Text(
                          video.channelTitle.isNotEmpty ? video.channelTitle[0] : 'C',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              video.channelTitle,
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'Channel',
                              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                        child: Text('Subscribe'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Description
            Container(
              margin: EdgeInsets.only(top: 8),
              padding: EdgeInsets.all(16),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Description',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    video.description.isNotEmpty ? video.description : 'No description available',
                    style: GoogleFonts.poppins(color: Colors.black, fontSize: 14),
                    maxLines: 10,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatViewCount(String viewCount) {
    final count = int.tryParse(viewCount) ?? 0;
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  String _formatTimeAgo(String publishedAt) {
    try {
      final date = DateTime.parse(publishedAt);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 365) {
        return '${(difference.inDays / 365).floor()} years ago';
      } else if (difference.inDays > 30) {
        return '${(difference.inDays / 30).floor()} months ago';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} days ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hours ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return 'Some time ago';
    }
  }
}

// SEARCH SCREEN
class SearchScreen extends StatelessWidget {
  final String searchQuery;

  const SearchScreen({super.key, required this.searchQuery});

  @override
  Widget build(BuildContext context) {
    final searchFuture = YouTubeService.searchVideos(searchQuery);

    return Scaffold(
      appBar: AppBar(
        title: Text('Hasil Pencarian: "$searchQuery"'),
      ),
      body: Stack(
        children: [
          FutureBuilder<List<YouTubeVideo>>(
            future: searchFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return _buildLoadingIndicator();
              }

              if (snapshot.hasError) {
                return _buildErrorWidget(snapshot.error.toString());
              }

              final videos = snapshot.data ?? [];

              if (videos.isEmpty) {
                return _buildEmptyResult();
              }

              return ListView.builder(
                itemCount: videos.length,
                itemBuilder: (context, index) {
                  final video = videos[index];
                  return VideoCard(video: video);
                },
              );
            },
          ),

          // Mini Player
          if (videoManager.isMiniPlayerVisible && videoManager.controller != null)
            Positioned(
              bottom: 80,
              right: 16,
              child: Container(
                width: 120,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Stack(
                    children: [
                      Container(
                        color: Colors.grey[800],
                        child: Center(
                          child: Icon(
                            Icons.play_circle_fill,
                            color: Colors.white.withOpacity(0.7),
                            size: 30,
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withOpacity(0.3),
                          child: Center(
                            child: GestureDetector(
                              onTap: () => videoManager.togglePlayPause(),
                              child: Icon(
                                videoManager.controller!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                                color: Colors.white,
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () {
                            videoManager.hideMiniPlayer();
                            videoManager.disposeController();
                          },
                          child: Container(
                            padding: EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.close, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Color(0xFF1a73e8)),
          SizedBox(height: 16),
          Text(
            'Mencari "$searchQuery"...',
            style: GoogleFonts.poppins(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Pencarian gagal',
            style: GoogleFonts.poppins(color: Colors.black, fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            error,
            style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyResult() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'Tidak ada hasil ditemukan',
            style: TextStyle(color: Colors.black, fontSize: 16),
          ),
          SizedBox(height: 8),
          Text(
            'Coba dengan kata kunci yang berbeda',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
