import 'package:flutter/material.dart';

/// Modern cinematic loading placeholder for the movie details page.
/// Shows an animated poster silhouette with pulsing gradient bars.
class DetailsLoadingView extends StatefulWidget {
  const DetailsLoadingView({Key? key}) : super(key: key);

  @override
  State<DetailsLoadingView> createState() => _DetailsLoadingViewState();
}

class _DetailsLoadingViewState extends State<DetailsLoadingView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400));
    _opacity = Tween<double>(begin: 0.35, end: 0.9).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
    _pulse.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090D),
      body: Stack(
        children: [
          // Animated ambient glow
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFE50914).withOpacity(0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF8E2DE2).withOpacity(0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _opacity,
              child: ListView(
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                children: [
                  // Backdrop placeholder
                  Container(
                    height: 320,
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A24),
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF1A1A24),
                          const Color(0xFF23233A),
                          const Color(0xFF1A1A24),
                        ],
                      ),
                    ),
                    child: const Center(
                      child: Icon(Icons.movie_filter_rounded,
                          color: Color(0xFF3A3A50), size: 64),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SkeletonBar(width: 220, height: 24),
                        SizedBox(height: 12),
                        _SkeletonBar(width: 140, height: 14),
                        SizedBox(height: 20),
                        _SkeletonBar(width: double.infinity, height: 13),
                        SizedBox(height: 8),
                        _SkeletonBar(width: 300, height: 13),
                        SizedBox(height: 8),
                        _SkeletonBar(width: 180, height: 13),
                        SizedBox(height: 28),
                        Row(
                          children: [
                            _SkeletonBar(width: 120, height: 46),
                            SizedBox(width: 14),
                            _SkeletonBar(width: 120, height: 46),
                          ],
                        ),
                        SizedBox(height: 30),
                        _SkeletonBar(width: 150, height: 16),
                        SizedBox(height: 14),
                        Row(
                          children: [
                            _PosterThumb(),
                            SizedBox(width: 12),
                            _PosterThumb(),
                            SizedBox(width: 12),
                            _PosterThumb(),
                          ],
                        ),
                      ],
                    ),
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

class _SkeletonBar extends StatelessWidget {
  final double width;
  final double height;

  const _SkeletonBar({required this.width, required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFF23233A),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class _PosterThumb extends StatelessWidget {
  const _PosterThumb();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      height: 120,
      decoration: BoxDecoration(
        color: const Color(0xFF23233A),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

/// Small pulse animation helper for loading states.
class PulseIndicator extends StatefulWidget {
  final Color color;
  final double size;

  const PulseIndicator({Key? key, this.color = const Color(0xFFE50914), this.size = 36})
      : super(key: key);

  @override
  State<PulseIndicator> createState() => _PulseIndicatorState();
}

class _PulseIndicatorState extends State<PulseIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.6, end: 1.0), weight: 1),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.6), weight: 1),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _opacity = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _ctrl.repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: FadeTransition(
        opacity: _opacity,
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [widget.color, widget.color.withOpacity(0.4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.5),
                blurRadius: 18,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: widget.size * 0.6),
        ),
      ),
    );
  }
}
