import 'package:flutter/material.dart';
import 'package:noor_new/screens/mapbox_safe_route.dart';
import 'package:noor_new/screens/mapbox_safe_route.dart'; // ✅ Updated import
import 'package:noor_new/screens/fake_call_setup.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart' show launchUrl, canLaunchUrl;
import 'widgets/emergency_card.dart';
import 'news_page.dart';
import 'circle_page.dart';
import 'profile_page.dart';
import 'dart:convert';
import 'package:noor_new/services/sos_service.dart';
import 'package:geolocator/geolocator.dart'; // ✅ Removed latlong2 (not needed here)
import 'news_page.dart';
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const HomePageContent(),
    const NewsPage(),
    const CirclePage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.background,
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Theme.of(context).colorScheme.background,
        currentIndex: _currentIndex,
        selectedItemColor: Theme.of(context).colorScheme.primary,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.house),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.compass),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person_2),
            label: 'Circle',
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

class HomePageContent extends StatelessWidget {
  const HomePageContent({super.key});

  Future<void> _callSOS(BuildContext context) async {
    try {
      String? locationLink;
      try {
        final position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5),
        );
        // ✅ FIXED: Removed extra spaces in Google Maps URL
        locationLink =
            'https://maps.google.com/?q=${position.latitude},${position.longitude}';
      } catch (e) {
        // Location is optional - SOS still works without it
        debugPrint('⚠️ Location not available for SOS: $e');
      }

      await SOSService.sendSOSSMS(locationLink);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🚨 SOS alert sent to trusted contacts!'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('SOS failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Load emergency cards from JSON
  Future<List<Widget>> _loadEmergencyCards(BuildContext context) async {
    try {
      final jsonString = await rootBundle.loadString(
        'assets/data/emergency_card.json',
      );
      final List<dynamic> jsonData = jsonDecode(jsonString);

      return jsonData.map((cardData) {
        return EmergencyCard(
          context: context,
          title: cardData['title'],
          subtitle: cardData['subtitle'],
          phoneNumber: cardData['phoneNumber'],
          icon: cardData['icon'],
          lightColors: (cardData['lightColors'] as List)
              .map((color) => Color(int.parse(color.substring(1), radix: 16)))
              .toList(),
          darkColors: (cardData['darkColors'] as List)
              .map((color) => Color(int.parse(color.substring(1), radix: 16)))
              .toList(),
        );
      }).toList();
    } catch (e) {
      debugPrint('❌ Error loading emergency cards: $e');
      // Return empty list if JSON fails to load
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final Color sosButtonColor = isDark
        ? const Color(0xFFC24A4A)
        : const Color(0xFFD05A5A);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Safe Sprout',
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quick Help',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),

              // JSON-LOADED EMERGENCY CARDS
              Container(
                clipBehavior: Clip.none,
                height: 178,
                child: FutureBuilder<List<Widget>>(
                  future: _loadEmergencyCards(context),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    } else if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error: ${snapshot.error}',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      );
                    } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const Center(child: Text('No emergency contacts'));
                    } else {
                      return ListView(
                        scrollDirection: Axis.horizontal,
                        children: snapshot.data!,
                      );
                    }
                  },
                ),
              ),

              const SizedBox(height: 48),

              // 🚨 SOS Button
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        _callSOS(context);
                      },
                      onLongPress: () {
                        // Optional: Show SOS instructions on long press
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text('SOS Help'),
                            content: const Text(
                              'Tap this button to instantly send your location '
                              'to your trusted contacts. They will receive an SMS '
                              'with a link to find you on Google Maps.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Got it'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: Container(
                        width: 176,
                        height: 176,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: sosButtonColor,
                          boxShadow: [
                            BoxShadow(
                              color: sosButtonColor.withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 0,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              CupertinoIcons.exclamationmark_triangle_fill,
                              color: Colors.white,
                              size: 48,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'SOS',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 2,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap for emergency alert',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // 📞 Fake Call Button
              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FakeCallSetup(),
                          ),
                        );
                      },
                      child: Container(
                        width: 176,
                        height: 176,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark
                              ? const Color(0xFF2D5A2D)
                              : const Color(0xFF4A7C4A),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  (isDark
                                          ? const Color(0xFF2D5A2D)
                                          : const Color(0xFF4A7C4A))
                                      .withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 0,
                              offset: const Offset(0, 8),
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.phone_callback_rounded,
                              color: Colors.white,
                              size: 48,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Fake Call',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Schedule or trigger fake call',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              // 🗺️ Safe Route Planner - UPDATED TO USE MAPBOX
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.location,
                      size: 18,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Plan Safe Route',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                const MapboxSafeRoute(), // ✅ Updated to new screen
                          ),
                        );
                      },
                      icon: const Icon(Icons.directions_walk, size: 18),
                      label: const Text('Walk'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Add transit routing later
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('🚧 Transit mode coming soon!'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                      },
                      icon: const Icon(Icons.directions_bus, size: 18),
                      label: const Text('Transit'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDark
                            ? const Color(0xFF2D2D2D)
                            : Colors.white,
                        foregroundColor: theme.colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: theme.colorScheme.primary.withOpacity(0.5),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}
