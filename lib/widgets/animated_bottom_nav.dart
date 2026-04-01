import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class NavItem {
  final IconData icon;
  final String label;

  NavItem({required this.icon, required this.label});
}

class AnimatedBottomNav extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;
  final List<NavItem> items;

  const AnimatedBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  State<AnimatedBottomNav> createState() => _AnimatedBottomNavState();
}

class _AnimatedBottomNavState extends State<AnimatedBottomNav>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int _previousIndex = 0; // ✅ Track actual previous index

  @override
  void initState() {
    super.initState();
    _previousIndex = widget.currentIndex;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 750), // ✅ Smooth but noticeable
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void didUpdateWidget(AnimatedBottomNav oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _previousIndex = oldWidget.currentIndex; // ✅ Store actual previous index
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: CustomPaint(
            size: Size(MediaQuery.of(context).size.width - 32, 60),
            painter: CurvedBottomNavPainter(
              currentIndex: widget.currentIndex,
              previousIndex: _previousIndex, // ✅ Pass actual previous index
              itemCount: widget.items.length,
              animation: _animation,
            ),
            child: Stack(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(widget.items.length, (index) {
                    final item = widget.items[index];
                    final isActive = widget.currentIndex == index;

                    return Expanded(
                      child: GestureDetector(
                        onTap: () => widget.onTap(index),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                item.icon,
                                color: isActive ? Colors.black : Colors.white,
                                size: 22,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.label,
                                style: TextStyle(
                                  color: isActive ? Colors.black : Colors.white,
                                  fontSize: 11,
                                  fontWeight: isActive
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(duration: 500.ms)
        .slideY(begin: 0.3, end: 0, duration: 500.ms, curve: Curves.easeOut);
  }
}

// ✅ Custom Painter for the Curved Notch Effect
class CurvedBottomNavPainter extends CustomPainter {
  final int currentIndex;
  final int previousIndex;
  final int itemCount;
  final Animation<double> animation;

  CurvedBottomNavPainter({
    required this.currentIndex,
    required this.previousIndex,
    required this.itemCount,
    required this.animation,
  }) : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey[900]!
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true; // ✅ Added for smooth edges

    final notchWidth = size.width / itemCount;

    final currentNotchCenter = (currentIndex * notchWidth) + (notchWidth / 2);
    final prevNotchCenter = (previousIndex * notchWidth) + (notchWidth / 2);

    final animatedNotchCenter =
        prevNotchCenter +
        (currentNotchCenter - prevNotchCenter) * animation.value;

    final path = Path();

    // ✅ Circle dimensions
    final circleRadius = 33.0; // Large enough for icon + text
    final gap = 2.0; // ← 2px gap all around
    final curveRadius =
        circleRadius + gap + 5; // Curve follows circle + 2px gap

    path.moveTo(0, 0);

    // Top edge until curve starts
    path.lineTo(animatedNotchCenter - curveRadius, 0);

    // ✅ Left side of U-curve (smooth arc down)
    path.quadraticBezierTo(
      animatedNotchCenter - curveRadius - 5,
      0,
      animatedNotchCenter - curveRadius + 10,
      curveRadius + 15,
    );

    // ✅ Bottom of U-curve (follows circle contour)
    path.quadraticBezierTo(
      animatedNotchCenter,
      curveRadius * 2,
      animatedNotchCenter + curveRadius - 10,
      curveRadius + 15,
    );

    // ✅ Right side of U-curve (smooth arc up)
    path.quadraticBezierTo(
      animatedNotchCenter + curveRadius,
      curveRadius,
      animatedNotchCenter + curveRadius,
      0,
    );

    path.lineTo(size.width, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    canvas.drawPath(path, paint);

    // ✅ Draw white circle
    final circlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..isAntiAlias = true; // ✅ Added for smooth circle edges

    // ✅ Circle sits in U-cradle with 2px gap all around
    canvas.drawCircle(
      Offset(
        animatedNotchCenter,
        curveRadius - 15,
      ), // Circle center at curve radius depth
      circleRadius,
      circlePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CurvedBottomNavPainter oldDelegate) {
    return oldDelegate.currentIndex != currentIndex ||
        oldDelegate.previousIndex != previousIndex ||
        oldDelegate.animation != animation;
  }
}
