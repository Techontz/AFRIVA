import 'package:material_ui/material_ui.dart';
import 'package:video_player/video_player.dart';

import '../../core/config.dart';
import '../../core/i18n.dart';
import '../../widgets/buttons.dart';
import '../player/video_surface.dart';

/// Full-screen trailer (always free to watch).
Future<void> showTrailer(BuildContext context, {required String url, required String title}) {
  return Navigator.of(context, rootNavigator: true).push(MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => _TrailerPage(url: url, title: title),
  ));
}

class _TrailerPage extends StatefulWidget {
  const _TrailerPage({required this.url, required this.title});
  final String url;
  final String title;

  @override
  State<_TrailerPage> createState() => _TrailerPageState();
}

class _TrailerPageState extends State<_TrailerPage> {
  VideoPlayerController? _controller;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final old = _controller;
    _controller = null;
    await old?.dispose();
    setState(() => _error = null);
    final c = VideoPlayerController.networkUrl(Uri.parse(AppConfig.resolveUrl(widget.url)));
    _controller = c;
    try {
      await c.initialize();
      if (!mounted) return;
      await c.play();
      setState(() {});
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final top = MediaQuery.paddingOf(context).top;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_error == null) VideoSurface(controller: c, loading: c == null || !c.value.isInitialized),
          if (_error != null)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.tr('The trailer could not be played.'), style: const TextStyle(color: Colors.white70)),
                  const SizedBox(height: 14),
                  PillButton(label: context.tr('Retry'), icon: Icons.refresh_rounded, height: 42, onPressed: _start),
                ],
              ),
            ),
          Positioned(
            top: top + 4,
            left: 8,
            right: 8,
            child: Row(
              children: [
                GlassIconButton(icon: Icons.close_rounded, onPressed: () => Navigator.of(context).pop()),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${context.tr('Trailer')} · ${widget.title}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall!.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          if (c != null && c.value.isInitialized)
            Positioned(left: 16, right: 16, bottom: bottom + 16, child: VideoProgressBar(controller: c)),
        ],
      ),
    );
  }
}
