import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccessibilityService {
  static final AccessibilityService _instance = AccessibilityService._internal();
  factory AccessibilityService() => _instance;
  AccessibilityService._internal();

  static const String HIGH_CONTRAST_KEY = 'high_contrast_enabled';
  static const String LARGE_TEXT_KEY = 'large_text_enabled';
  static const String SCREEN_READER_KEY = 'screen_reader_enabled';
  static const String REDUCE_ANIMATIONS_KEY = 'reduce_animations_enabled';

  SharedPreferences? _prefs;
  
  bool _highContrastEnabled = false;
  bool _largeTextEnabled = false;
  bool _screenReaderEnabled = false;
  bool _reduceAnimationsEnabled = false;

  // Getters
  bool get isHighContrastEnabled => _highContrastEnabled;
  bool get isLargeTextEnabled => _largeTextEnabled;
  bool get isScreenReaderEnabled => _screenReaderEnabled;
  bool get isReduceAnimationsEnabled => _reduceAnimationsEnabled;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _loadSettings();
  }

  void _loadSettings() {
    if (_prefs != null) {
      _highContrastEnabled = _prefs!.getBool(HIGH_CONTRAST_KEY) ?? false;
      _largeTextEnabled = _prefs!.getBool(LARGE_TEXT_KEY) ?? false;
      _screenReaderEnabled = _prefs!.getBool(SCREEN_READER_KEY) ?? false;
      _reduceAnimationsEnabled = _prefs!.getBool(REDUCE_ANIMATIONS_KEY) ?? false;
    }
  }

  Future<void> setHighContrast(bool enabled) async {
    _highContrastEnabled = enabled;
    await _prefs?.setBool(HIGH_CONTRAST_KEY, enabled);
  }

  Future<void> setLargeText(bool enabled) async {
    _largeTextEnabled = enabled;
    await _prefs?.setBool(LARGE_TEXT_KEY, enabled);
  }

  Future<void> setScreenReader(bool enabled) async {
    _screenReaderEnabled = enabled;
    await _prefs?.setBool(SCREEN_READER_KEY, enabled);
  }

  Future<void> setReduceAnimations(bool enabled) async {
    _reduceAnimationsEnabled = enabled;
    await _prefs?.setBool(REDUCE_ANIMATIONS_KEY, enabled);
  }

  // Get accessible theme data
  ThemeData getAccessibleTheme(ThemeData baseTheme) {
    if (_highContrastEnabled) {
      return _getHighContrastTheme();
    }
    
    if (_largeTextEnabled) {
      return baseTheme.copyWith(
        textTheme: _getLargeTextTheme(baseTheme.textTheme),
      );
    }
    
    return baseTheme;
  }

  ThemeData _getHighContrastTheme() {
    return ThemeData(
      primarySwatch: Colors.blue,
      brightness: Brightness.dark,
      backgroundColor: Colors.black,
      scaffoldBackgroundColor: Colors.black,
      cardColor: Colors.grey[900],
      dividerColor: Colors.white,
      textTheme: const TextTheme(
        headlineSmall: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: Colors.white, fontSize: 16),
        bodyMedium: TextStyle(color: Colors.white, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: Colors.black,
          backgroundColor: Colors.white,
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        fillColor: Colors.white,
        filled: true,
        border: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.blue, width: 3),
        ),
      ),
    );
  }

  TextTheme _getLargeTextTheme(TextTheme baseTextTheme) {
    return baseTextTheme.copyWith(
      headlineSmall: baseTextTheme.headlineSmall?.copyWith(fontSize: 28),
      titleLarge: baseTextTheme.titleLarge?.copyWith(fontSize: 24),
      titleMedium: baseTextTheme.titleMedium?.copyWith(fontSize: 22),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(fontSize: 20),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(fontSize: 18),
      bodySmall: baseTextTheme.bodySmall?.copyWith(fontSize: 16),
    );
  }

  // Animation duration based on accessibility settings
  Duration getAnimationDuration(Duration defaultDuration) {
    if (_reduceAnimationsEnabled) {
      return Duration(milliseconds: 50); // Very fast animations
    }
    return defaultDuration;
  }
}

// Accessible button wrapper
class AccessibleButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final String? semanticLabel;
  final String? tooltip;
  final Color? backgroundColor;
  final Color? textColor;

  const AccessibleButton({
    Key? key,
    required this.text,
    this.onPressed,
    this.icon,
    this.semanticLabel,
    this.tooltip,
    this.backgroundColor,
    this.textColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget button = ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        minimumSize: const Size(48, 48), // Minimum touch target size
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 20),
            const SizedBox(width: 8),
          ],
          Text(text),
        ],
      ),
    );

    if (tooltip != null) {
      button = Tooltip(
        message: tooltip!,
        child: button,
      );
    }

    return Semantics(
      label: semanticLabel ?? text,
      button: true,
      enabled: onPressed != null,
      child: button,
    );
  }
}

// Accessible text field wrapper
class AccessibleTextField extends StatelessWidget {
  final String labelText;
  final String? hintText;
  final String? semanticLabel;
  final TextEditingController? controller;
  final String? Function(String?)? validator;
  final bool obscureText;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;

  const AccessibleTextField({
    Key? key,
    required this.labelText,
    this.hintText,
    this.semanticLabel,
    this.controller,
    this.validator,
    this.obscureText = false,
    this.keyboardType,
    this.prefixIcon,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel ?? labelText,
      textField: true,
      child: TextFormField(
        controller: controller,
        validator: validator,
        obscureText: obscureText,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: labelText,
          hintText: hintText,
          prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}

// Accessible card wrapper
class AccessibleCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;
  final EdgeInsetsGeometry padding;

  const AccessibleCard({
    Key? key,
    required this.child,
    this.onTap,
    this.semanticLabel,
    this.padding = const EdgeInsets.all(16),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget card = Card(
      child: Padding(
        padding: padding,
        child: child,
      ),
    );

    if (onTap != null) {
      card = InkWell(
        onTap: onTap,
        child: card,
      );
    }

    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      child: card,
    );
  }
}

// Accessible list tile
class AccessibleListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? leading;
  final VoidCallback? onTap;
  final String? semanticLabel;

  const AccessibleListTile({
    Key? key,
    required this.title,
    this.subtitle,
    this.leading,
    this.onTap,
    this.semanticLabel,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String label = semanticLabel ?? title;
    if (subtitle != null) {
      label += '. $subtitle';
    }

    return Semantics(
      label: label,
      button: onTap != null,
      child: ListTile(
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        leading: leading != null ? Icon(leading) : null,
        onTap: onTap,
        minVerticalPadding: 16, // Increase touch target
      ),
    );
  }
}

// Screen reader announcements
class ScreenReaderAnnouncements {
  static void announce(String message, {Assertiveness assertiveness = Assertiveness.polite}) {
    final accessibilityService = AccessibilityService();
    if (accessibilityService.isScreenReaderEnabled) {
      SemanticsService.announce(message, TextDirection.ltr, assertiveness: assertiveness);
    }
  }

  static void announceNavigation(String screenName) {
    announce('Navigated to $screenName screen', assertiveness: Assertiveness.assertive);
  }

  static void announceAction(String action) {
    announce(action, assertiveness: Assertiveness.polite);
  }

  static void announceError(String error) {
    announce('Error: $error', assertiveness: Assertiveness.assertive);
  }

  static void announceSuccess(String message) {
    announce('Success: $message', assertiveness: Assertiveness.polite);
  }
}

// Accessibility settings screen
class AccessibilitySettingsScreen extends StatefulWidget {
  @override
  _AccessibilitySettingsScreenState createState() => _AccessibilitySettingsScreenState();
}

class _AccessibilitySettingsScreenState extends State<AccessibilitySettingsScreen> {
  final AccessibilityService _accessibilityService = AccessibilityService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accessibility Settings'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            AccessibleCard(
              semanticLabel: 'Visual accessibility settings',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Visual',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _buildSwitchTile(
                    title: 'High Contrast',
                    subtitle: 'Use high contrast colors for better visibility',
                    value: _accessibilityService.isHighContrastEnabled,
                    onChanged: (value) async {
                      await _accessibilityService.setHighContrast(value);
                      setState(() {});
                      ScreenReaderAnnouncements.announce(
                        value ? 'High contrast enabled' : 'High contrast disabled'
                      );
                    },
                  ),
                  _buildSwitchTile(
                    title: 'Large Text',
                    subtitle: 'Increase text size throughout the app',
                    value: _accessibilityService.isLargeTextEnabled,
                    onChanged: (value) async {
                      await _accessibilityService.setLargeText(value);
                      setState(() {});
                      ScreenReaderAnnouncements.announce(
                        value ? 'Large text enabled' : 'Large text disabled'
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AccessibleCard(
              semanticLabel: 'Motion accessibility settings',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Motion',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _buildSwitchTile(
                    title: 'Reduce Animations',
                    subtitle: 'Minimize motion effects and transitions',
                    value: _accessibilityService.isReduceAnimationsEnabled,
                    onChanged: (value) async {
                      await _accessibilityService.setReduceAnimations(value);
                      setState(() {});
                      ScreenReaderAnnouncements.announce(
                        value ? 'Reduced animations enabled' : 'Reduced animations disabled'
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            AccessibleCard(
              semanticLabel: 'Screen reader settings',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Screen Reader',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  _buildSwitchTile(
                    title: 'Enhanced Screen Reader Support',
                    subtitle: 'Provide additional audio feedback and descriptions',
                    value: _accessibilityService.isScreenReaderEnabled,
                    onChanged: (value) async {
                      await _accessibilityService.setScreenReader(value);
                      setState(() {});
                      ScreenReaderAnnouncements.announce(
                        value ? 'Enhanced screen reader support enabled' : 'Enhanced screen reader support disabled'
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Semantics(
      label: '$title. $subtitle. ${value ? "Enabled" : "Disabled"}',
      toggled: value,
      child: SwitchListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: onChanged,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}

// Focus management helper
class FocusHelper {
  static void requestFocus(BuildContext context, FocusNode focusNode) {
    Future.delayed(const Duration(milliseconds: 100), () {
      FocusScope.of(context).requestFocus(focusNode);
    });
  }

  static void nextFocus(BuildContext context) {
    FocusScope.of(context).nextFocus();
  }

  static void previousFocus(BuildContext context) {
    FocusScope.of(context).previousFocus();
  }

  static void unfocus(BuildContext context) {
    FocusScope.of(context).unfocus();
  }
}