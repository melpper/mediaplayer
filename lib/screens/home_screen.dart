import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path/path.dart' as p;
import 'player_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<String> _videoPaths = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _loadSavedPaths();
  }

  Future<void> _loadSavedPaths() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList('video_paths') ?? [];
    // Filter out files that no longer exist
    final valid = saved.where((path) => File(path).existsSync()).toList();
    setState(() => _videoPaths = valid);
    if (valid.length != saved.length) {
      prefs.setStringList('video_paths', valid);
    }
  }

  Future<void> _savePaths() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('video_paths', _videoPaths);
  }

  Future<void> _addVideos() async {
    setState(() => _isLoading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp4', 'mkv', 'mov', 'avi', 'webm', 'm4v'],
        allowMultiple: true,
      );
      if (result != null) {
        final newPaths = result.paths
            .whereType<String>()
            .where((path) => !_videoPaths.contains(path))
            .toList();
        setState(() => _videoPaths.addAll(newPaths));
        await _savePaths();
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _removeVideo(int index) {
    setState(() => _videoPaths.removeAt(index));
    _savePaths();
  }

  void _reorderVideos(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    setState(() {
      final item = _videoPaths.removeAt(oldIndex);
      _videoPaths.insert(newIndex, item);
    });
    _savePaths();
  }

  void _playFrom(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PlayerScreen(
          videoPaths: _videoPaths,
          startIndex: index,
        ),
      ),
    );
  }

  String _fileName(String path) => p.basenameWithoutExtension(path);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _videoPaths.isEmpty
                  ? _buildEmptyState()
                  : _buildPlaylist(),
            ),
            if (_videoPaths.isNotEmpty) _buildPlayAllButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 16, 8),
      child: Row(
        children: [
          const Text(
            'LOOP\nPLAYER',
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              height: 1.1,
              letterSpacing: 4,
            ),
          ),
          const Spacer(),
          _isLoading
              ? const SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white38,
                      ),
                    ),
                  ),
                )
              : IconButton(
                  onPressed: _addVideos,
                  icon: const Icon(Icons.add, color: Colors.white, size: 28),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white12,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white12, width: 1.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.video_library_outlined,
              color: Colors.white24,
              size: 36,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No videos yet',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 16,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Tap + to add MP4 files',
            style: TextStyle(
              color: Colors.white24,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaylist() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _videoPaths.length,
      onReorder: _reorderVideos,
      proxyDecorator: (child, index, animation) => child,
      itemBuilder: (context, index) {
        final path = _videoPaths[index];
        return _VideoTile(
          key: ValueKey(path),
          index: index,
          name: _fileName(path),
          onPlay: () => _playFrom(index),
          onRemove: () => _removeVideo(index),
        );
      },
    );
  }

  Widget _buildPlayAllButton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      child: SizedBox(
        width: double.infinity,
        child: TextButton.icon(
          onPressed: () => _playFrom(0),
          icon: const Icon(Icons.play_arrow_rounded, size: 22),
          label: Text(
            'PLAY ALL  •  ${_videoPaths.length} VIDEO${_videoPaths.length == 1 ? '' : 'S'}  •  LOOPING',
            style: const TextStyle(
              letterSpacing: 1.5,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          style: TextButton.styleFrom(
            foregroundColor: Colors.black,
            backgroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoTile extends StatelessWidget {
  final int index;
  final String name;
  final VoidCallback onPlay;
  final VoidCallback onRemove;

  const _VideoTile({
    super.key,
    required this.index,
    required this.name,
    required this.onPlay,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white07,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
        leading: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${index + 1}',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        title: Text(
          name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              onPressed: onPlay,
              icon: const Icon(Icons.play_circle_outline_rounded,
                  color: Colors.white70, size: 26),
            ),
            IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded,
                  color: Colors.white30, size: 20),
            ),
            const Icon(Icons.drag_handle_rounded,
                color: Colors.white24, size: 20),
            const SizedBox(width: 4),
          ],
        ),
        onTap: onPlay,
      ),
    );
  }
}
