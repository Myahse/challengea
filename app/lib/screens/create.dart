import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../chat_store.dart';
import '../feed.dart';
import '../stories.dart';
import '../theme.dart';
import '../widgets/avatar.dart';
import '../widgets/glass.dart';
import '../widgets/motion.dart';

/// Backgrounds for text posts and text stories.
const backgrounds = [
  [Color(0xFFFF3D7F), Color(0xFFFF8A3D)],
  [Color(0xFF3D7BFF), Color(0xFF8B6CF6)],
  [Color(0xFF00B894), Color(0xFF0984E3)],
  [Color(0xFF2B2D42), Color(0xFF8D99AE)],
  [Color(0xFFFFC53D), Color(0xFFFF6B3D)],
  [Color(0xFF6A4C93), Color(0xFFF06BA8)],
];

/// The center "+" of the menu: what do you want to create?
Future<void> showCreateMenu(
  BuildContext context,
  ChatStore store, {
  required VoidCallback onChallenge,
  required VoidCallback onNewGroup,
}) {
  final items = <(IconData, String, String, List<Color>, VoidCallback?)>[
    (
      Icons.edit_note_rounded,
      'Post',
      'Share with friends',
      backgrounds[0],
      () => openPostComposer(context, store),
    ),
    (
      Icons.auto_awesome_rounded,
      'Story',
      '24 h, then gone',
      backgrounds[5],
      () => openStoryCreator(context, store),
    ),
    (
      Icons.sports_esports_rounded,
      'Challenge',
      '1 vs 1 game',
      backgrounds[1],
      onChallenge,
    ),
    (
      Icons.group_add_rounded,
      'Group',
      'Merge friends',
      backgrounds[2],
      onNewGroup,
    ),
    (
      Icons.photo_camera_rounded,
      'Photo',
      'From your camera',
      backgrounds[4],
      () => openPostComposer(context, store, pickPhoto: true, camera: true),
    ),
    (Icons.sensors_rounded, 'Live', 'Coming soon', backgrounds[3], null),
  ];
  return showModalBottomSheet(
    context: context,
    showDragHandle: true,
    backgroundColor: AppColors.card,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Create', style: tx(34, weight: FontWeight.w600)),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: .92,
              children: [
                for (var i = 0; i < items.length; i++)
                  FadeSlideIn(
                    delay: Duration(milliseconds: 40 * i),
                    scale: .8,
                    child: Pressable(
                      onTap: items[i].$5 == null
                          ? null
                          : () {
                              Navigator.pop(ctx);
                              items[i].$5!();
                            },
                      child: Opacity(
                        opacity: items[i].$5 == null ? .5 : 1,
                        child: Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: AppColors.hero,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                right: -30,
                                top: -30,
                                child: Orb(
                                  color: items[i].$4.first,
                                  diameter: 96,
                                  glow: 30,
                                ),
                              ),
                              Positioned(
                                right: 10,
                                top: 10,
                                child: Icon(
                                  items[i].$1,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                              Positioned(
                                left: 12,
                                right: 12,
                                bottom: 12,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      items[i].$2,
                                      style: tx(
                                        17,
                                        weight: FontWeight.w600,
                                        color: AppColors.nightInk,
                                      ),
                                    ),
                                    Text(
                                      items[i].$3,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: tx(
                                        12,
                                        color: AppColors.nightMuted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
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

Future<Uint8List?> _pick(BuildContext context, {bool camera = false}) async {
  try {
    final f = await ImagePicker().pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 82,
    );
    return f == null ? null : await f.readAsBytes();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Couldn’t open the photos',
            style: tx(14, color: Colors.white),
          ),
        ),
      );
    }
    return null;
  }
}

// -------------------------------------------------------------- new post
Future<void> openPostComposer(
  BuildContext context,
  ChatStore store, {
  bool pickPhoto = false,
  bool camera = false,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) =>
          _PostComposer(store: store, pickPhoto: pickPhoto, camera: camera),
    ),
  );
}

class _PostComposer extends StatefulWidget {
  const _PostComposer({
    required this.store,
    required this.pickPhoto,
    required this.camera,
  });
  final ChatStore store;
  final bool pickPhoto;
  final bool camera;

  @override
  State<_PostComposer> createState() => _PostComposerState();
}

class _PostComposerState extends State<_PostComposer> {
  final _text = TextEditingController();
  Uint8List? _photo;
  int? _background; // index in [backgrounds]

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
    if (widget.pickPhoto) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _addPhoto(camera: widget.camera),
      );
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _addPhoto({bool camera = false}) async {
    final bytes = await _pick(context, camera: camera);
    if (bytes != null) setState(() => _photo = bytes);
  }

  bool get _canPost => _text.text.trim().isNotEmpty || _photo != null;
  bool get _asCard =>
      _background != null && _photo == null && _text.text.trim().length <= 120;

  void _post() {
    if (!_canPost) return;
    HapticFeedback.mediumImpact();
    final feed = widget.store.feed;
    feed.addPost(
      Post(
        id: 'mine-${DateTime.now().microsecondsSinceEpoch}',
        author: feed.me,
        caption: _text.text.trim(),
        colors: _asCard ? backgrounds[_background!] : const [],
        kind: PostKind.photo,
        photo: _photo,
        ago: 'Just now',
        textCard: _asCard,
      ),
    );
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Posted', style: tx(14, color: Colors.white)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.store.me;
    return Scaffold(
      backgroundColor: AppColors.card,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded),
        ),
        title: Text('Create post', style: tx(18, weight: FontWeight.w700)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: AnimatedOpacity(
              duration: Motion.fast,
              opacity: _canPost ? 1 : .4,
              child: Pressable(
                onTap: _canPost ? _post : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: AppColors.brandGradient),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Post',
                    style: tx(15, weight: FontWeight.w800, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                PersonAvatar(me, diameter: 44),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(me.name, style: tx(16, weight: FontWeight.w700)),
                    Container(
                      margin: const EdgeInsets.only(top: 3),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.page,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.people_alt_rounded, size: 13),
                          const SizedBox(width: 4),
                          Text(
                            'Friends',
                            style: tx(12, weight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  AnimatedContainer(
                    duration: Motion.normal,
                    curve: Motion.ease,
                    constraints: BoxConstraints(minHeight: _asCard ? 260 : 120),
                    alignment: _asCard ? Alignment.center : Alignment.topLeft,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(_asCard ? 20 : 0),
                      gradient: _asCard
                          ? LinearGradient(colors: backgrounds[_background!])
                          : null,
                    ),
                    padding: EdgeInsets.all(_asCard ? 24 : 0),
                    child: TextField(
                      controller: _text,
                      autofocus: !widget.pickPhoto,
                      maxLines: null,
                      textAlign: _asCard ? TextAlign.center : TextAlign.start,
                      style: _asCard
                          ? tx(26, weight: FontWeight.w800, color: Colors.white)
                          : tx(20),
                      cursorColor: _asCard ? AppColors.onInk : AppColors.ink,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: 'What’s on your mind?',
                        hintStyle: _asCard
                            ? tx(
                                26,
                                weight: FontWeight.w800,
                                color: Colors.white70,
                              )
                            : tx(20, color: AppColors.muted),
                      ),
                    ),
                  ),
                  if (_photo != null)
                    FadeSlideIn(
                      scale: .9,
                      child: Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: Image.memory(
                              _photo!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          ),
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Pressable(
                              onTap: () => setState(() => _photo = null),
                              child: const CircleAvatar(
                                backgroundColor: Colors.black54,
                                child: Icon(
                                  Icons.close_rounded,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Background colours + add photo.
          SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              child: Row(
                children: [
                  Pressable(
                    onTap: () => setState(() => _background = null),
                    child: Container(
                      width: 34,
                      height: 34,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: _background == null
                              ? AppColors.ink
                              : AppColors.line,
                          width: 2,
                        ),
                      ),
                      child: const Icon(Icons.text_fields_rounded, size: 18),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (var i = 0; i < backgrounds.length; i++)
                            Pressable(
                              onTap: () => setState(() => _background = i),
                              child: AnimatedContainer(
                                duration: Motion.fast,
                                width: 34,
                                height: 34,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  gradient: LinearGradient(
                                    colors: backgrounds[i],
                                  ),
                                  border: Border.all(
                                    color: _background == i
                                        ? AppColors.ink
                                        : Colors.white,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _addPhoto(),
                    icon: Icon(
                      Icons.photo_library_rounded,
                      color: AppColors.accent,
                    ),
                  ),
                  IconButton(
                    onPressed: () => _addPhoto(camera: true),
                    icon: const Icon(Icons.photo_camera_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -------------------------------------------------------------- new story
Future<void> openStoryCreator(BuildContext context, ChatStore store) {
  return Navigator.of(context).push(
    PageRouteBuilder(
      transitionDuration: Motion.normal,
      pageBuilder: (_, a, _) => FadeTransition(
        opacity: a,
        child: _StoryCreator(store: store),
      ),
    ),
  );
}

class _StoryCreator extends StatefulWidget {
  const _StoryCreator({required this.store});
  final ChatStore store;

  @override
  State<_StoryCreator> createState() => _StoryCreatorState();
}

class _StoryCreatorState extends State<_StoryCreator> {
  final _text = TextEditingController();
  int _bg = 0;
  Uint8List? _photo;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _share() {
    if (_photo == null && _text.text.trim().isEmpty) return;
    HapticFeedback.mediumImpact();
    widget.store.addToMyStory(
      StoryItem(
        colors: backgrounds[_bg],
        text: _text.text.trim().isEmpty ? null : _text.text.trim(),
        photo: _photo,
      ),
    );
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Added to your story',
          style: tx(14, color: Colors.white),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => setState(
                () => _bg = (_bg + 1) % backgrounds.length,
              ), // tap the background to change colour
              child: AnimatedContainer(
                duration: Motion.slow,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: backgrounds[_bg],
                  ),
                ),
                child: _photo == null
                    ? null
                    : Image.memory(_photo!, fit: BoxFit.cover),
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: TextField(
                controller: _text,
                autofocus: true,
                maxLines: null,
                textAlign: TextAlign.center,
                cursorColor: Colors.white,
                style: tx(32, weight: FontWeight.w800, color: Colors.white)
                    .copyWith(
                      shadows: const [
                        Shadow(color: Colors.black38, blurRadius: 12),
                      ],
                    ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: _photo == null
                      ? 'Type something…'
                      : 'Add a caption…',
                  hintStyle: tx(
                    32,
                    weight: FontWeight.w800,
                    color: Colors.white60,
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Photo',
                    onPressed: () async {
                      final b = await _pick(context);
                      if (b != null) setState(() => _photo = b);
                    },
                    icon: const Icon(
                      Icons.photo_library_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Camera',
                    onPressed: () async {
                      final b = await _pick(context, camera: true);
                      if (b != null) setState(() => _photo = b);
                    },
                    icon: const Icon(
                      Icons.photo_camera_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 16,
            child: SafeArea(
              child: Pressable(
                onTap: _share,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 20, 12),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      PersonAvatar(widget.store.me, diameter: 26),
                      const SizedBox(width: 8),
                      Text(
                        'Your story',
                        style: tx(15, weight: FontWeight.w800),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_forward_rounded, size: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
