import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:url_launcher/url_launcher.dart' show launchUrl, canLaunchUrl;

class EmergencyCard extends StatelessWidget {
  final BuildContext context;
  final String title;
  final String subtitle;
  final String phoneNumber;
  final String icon; // Now a string
  final List<Color> lightColors;
  final List<Color> darkColors;

  const EmergencyCard({
    super.key,
    required this.context,
    required this.title,
    required this.subtitle,
    required this.phoneNumber,
    required this.icon,
    required this.lightColors,
    required this.darkColors,
  });

  Future<void> _callNumber() async {
    final Uri phoneUri = Uri.parse('tel:$phoneNumber');
    if (await canLaunchUrl(phoneUri)) {
      await launchUrl(phoneUri);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not call $phoneNumber')));
    }
  }

  // Map string icon names to CupertinoIcons
  IconData _getIcon(String iconName) {
    switch (iconName) {
      case 'doc_text_fill':
        return CupertinoIcons.doc_text_fill;
      case 'person_crop_circle_badge_exclam':
        return CupertinoIcons.person_crop_circle_badge_exclam;
      case 'heart_fill':
        return CupertinoIcons.heart_fill;
      default:
        return CupertinoIcons.phone_fill;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Choose colors based on theme
    final List<Color> cardColors = isDark ? darkColors : lightColors;
    final Color bgColor = cardColors[0]; // Use first color as solid background

    return GestureDetector(
      onTap: _callNumber,
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: bgColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              _getIcon(icon),
              size: 28,
              color: isDark ? Colors.white : const Color(0xFF171212),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark
                    ? const Color(0xFFE0E0E0)
                    : const Color(0xFF171212),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark
                    ? const Color(0xFFE0E0E0).withOpacity(0.8)
                    : const Color(0xFF5C4A4A),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  CupertinoIcons.phone_fill,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Text(
                  phoneNumber,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }
}
