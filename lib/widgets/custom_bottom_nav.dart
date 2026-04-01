// import 'package:flutter/material.dart';
// import 'package:flutter_animate/flutter_animate.dart';

// class AnimatedBottomNav extends StatefulWidget {
//   final int currentIndex;
//   final Function(int) onTap;
//   final List<NavItem> items;

//   const AnimatedBottomNav({
//     super.key,
//     required this.currentIndex,
//     required this.onTap,
//     required this.items,
//   });

//   @override
//   State<AnimatedBottomNav> createState() => _AnimatedBottomNavState();
// }

// class _AnimatedBottomNavState extends State<AnimatedBottomNav>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _controller;
//   late Animation<Offset> _offsetAnimation;

//   @override
//   void initState() {
//     super.initState();
//     _controller = AnimationController(
//       duration: const Duration(milliseconds: 400),
//       vsync: this,
//     );
//     _updateOffset();
//   }

//   void _updateOffset() {
//     final offset = widget.currentIndex * 1.0; // Move by 1 tab width
//     _offsetAnimation = Tween<Offset>(
//       begin: Offset(offset - 1, 0),
//       end: Offset(offset, 0),
//     ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));
//     _controller.forward(from: 0);
//   }

//   @override
//   void didUpdateWidget(AnimatedBottomNav oldWidget) {
//     super.didUpdateWidget(oldWidget);
//     if (oldWidget.currentIndex != widget.currentIndex) {
//       _updateOffset();
//     }
//   }

//   @override
//   void dispose() {
//     _controller.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//           margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//           padding: const EdgeInsets.all(8),
//           decoration: BoxDecoration(
//             color: Colors.grey[900], // Dark background like your inspiration
//             borderRadius: BorderRadius.circular(35),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.black.withOpacity(0.3),
//                 blurRadius: 20,
//                 offset: const Offset(0, 10),
//               ),
//             ],
//           ),
//           child: Stack(
//             children: [
//               // ✅ Moving Ball/Indicator
//               AnimatedBuilder(
//                 animation: _offsetAnimation,
//                 builder: (context, child) {
//                   return Positioned(
//                     left: 0,
//                     right: 0,
//                     child: SlideTransition(
//                       position: _offsetAnimation,
//                       child:
//                           Row(
//                             children: List.generate(widget.items.length, (
//                               index,
//                             ) {
//                               return Expanded(child: Container());
//                             }),
//                           ).transform(
//                             Matrix4.translationValues(
//                               (MediaQuery.of(context).size.width - 64) /
//                                   widget.items.length *
//                                   widget.currentIndex,
//                               0,
//                               0,
//                             ),
//                           ),
//                     ),
//                   );
//                 },
//               ),

//               // ✅ Icons & Labels
//               Row(
//                 mainAxisAlignment: MainAxisAlignment.spaceAround,
//                 children: List.generate(widget.items.length, (index) {
//                   final item = widget.items[index];
//                   final isActive = widget.currentIndex == index;

//                   return Expanded(
//                     child: GestureDetector(
//                       onTap: () => widget.onTap(index),
//                       child: Container(
//                         padding: const EdgeInsets.symmetric(vertical: 14),
//                         child: Column(
//                           mainAxisSize: MainAxisSize.min,
//                           children: [
//                             Icon(
//                               item.icon,
//                               color: isActive ? Colors.white : Colors.grey[400],
//                               size: 24,
//                             ),
//                             const SizedBox(height: 4),
//                             Text(
//                               item.label,
//                               style: TextStyle(
//                                 color: isActive
//                                     ? Colors.white
//                                     : Colors.grey[400],
//                                 fontSize: 11,
//                                 fontWeight: isActive
//                                     ? FontWeight.bold
//                                     : FontWeight.normal,
//                               ),
//                             ),
//                           ],
//                         ),
//                       ),
//                     ),
//                   );
//                 }),
//               ),
//             ],
//           ),
//         )
//         .animate()
//         .fadeIn(duration: 500.ms)
//         .slideY(begin: 0.3, end: 0, duration: 500.ms, curve: Curves.easeOut);
//   }
// }
