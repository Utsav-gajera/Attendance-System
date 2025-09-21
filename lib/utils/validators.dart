import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class Validators {
  // Email validation
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    
    final trimmed = value.trim().toLowerCase();
    
    // Basic email regex pattern
    final emailRegExp = RegExp(
      r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+',
    );
    
    if (!emailRegExp.hasMatch(trimmed)) {
      return 'Please enter a valid email address';
    }
    
    // Check for valid domain endings
    if (!trimmed.endsWith('@student.com') && 
        !trimmed.endsWith('@teacher.com') && 
        !trimmed.endsWith('@admin.com')) {
      return 'Please use @student.com, @teacher.com, or @admin.com';
    }
    
    return null;
  }

  // Password validation
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    
    if (value.length < 6) {
      return 'Password must be at least 6 characters long';
    }
    
    if (value.length > 128) {
      return 'Password must be less than 128 characters';
    }
    
    // Check for at least one letter and one number for stronger passwords
    if (!RegExp(r'^(?=.*[a-zA-Z])(?=.*[0-9])').hasMatch(value)) {
      return 'Password must contain at least one letter and one number';
    }
    
    return null;
  }

  // Full name validation
  static String? validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Full name is required';
    }
    
    final trimmed = value.trim();
    
    if (trimmed.length < 2) {
      return 'Name must be at least 2 characters long';
    }
    
    if (trimmed.length > 50) {
      return 'Name must be less than 50 characters';
    }
    
    // Check for valid characters (letters, spaces, hyphens, apostrophes)
    if (!RegExp(r"^[a-zA-Z\s\-\'\.]+$").hasMatch(trimmed)) {
      return 'Name can only contain letters, spaces, hyphens, and apostrophes';
    }
    
    // Check for reasonable word count (2-4 names)
    final words = trimmed.split(' ').where((word) => word.isNotEmpty).toList();
    if (words.length < 2) {
      return 'Please enter your full name (first and last name)';
    }
    
    if (words.length > 4) {
      return 'Name should not exceed 4 words';
    }
    
    return null;
  }

  // Subject name validation
  static String? validateSubject(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Subject name is required';
    }
    
    final trimmed = value.trim();
    
    if (trimmed.length < 2) {
      return 'Subject name must be at least 2 characters long';
    }
    
    if (trimmed.length > 30) {
      return 'Subject name must be less than 30 characters';
    }
    
    // Allow letters, numbers, spaces, hyphens, and parentheses
    if (!RegExp(r"^[a-zA-Z0-9\s\-\(\)]+$").hasMatch(trimmed)) {
      return 'Subject name can only contain letters, numbers, spaces, hyphens, and parentheses';
    }
    
    return null;
  }

  // General text validation
  static String? validateText(String? value, {
    required String fieldName,
    int minLength = 1,
    int maxLength = 100,
    bool allowNumbers = true,
    bool allowSpecialChars = false,
  }) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    
    final trimmed = value.trim();
    
    if (trimmed.length < minLength) {
      return '$fieldName must be at least $minLength characters long';
    }
    
    if (trimmed.length > maxLength) {
      return '$fieldName must be less than $maxLength characters';
    }
    
    String pattern = r'^[a-zA-Z\s';
    if (allowNumbers) pattern += r'0-9';
    if (allowSpecialChars) pattern += r"\-\'\(\)\.";
    pattern += r']+$';
    
    if (!RegExp(pattern).hasMatch(trimmed)) {
      String allowed = 'letters and spaces';
      if (allowNumbers) allowed += ', numbers';
      if (allowSpecialChars) allowed += ', and basic punctuation';
      return '$fieldName can only contain $allowed';
    }
    
    return null;
  }

  // Sanitize input text
  static String sanitizeText(String input) {
    return input
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ') // Replace multiple spaces with single space
        .replaceAll(RegExp(r"[^\w\s\-\'\(\)\.]"), ''); // Remove unwanted characters
  }

  // Sanitize email
  static String sanitizeEmail(String email) {
    return email.trim().toLowerCase();
  }

  // Sanitize name (proper case)
  static String sanitizeName(String name) {
    final sanitized = sanitizeText(name);
    return sanitized.split(' ')
        .map((word) => word.isEmpty ? '' : 
            word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  // Check if string contains only safe characters
  static bool isSafeText(String text) {
    // Check for potential injection patterns or harmful content
    final harmfulPatterns = [
      '<script',
      'javascript:',
      'onclick',
      'onerror',
      'onload',
      'alert(',
      'eval(',
      'document.',
      'window.',
      'SELECT ',
      'INSERT ',
      'UPDATE ',
      'DELETE ',
      'DROP ',
      'CREATE ',
      'ALTER ',
    ];
    
    final lowerText = text.toLowerCase();
    for (final pattern in harmfulPatterns) {
      if (lowerText.contains(pattern.toLowerCase())) {
        return false;
      }
    }
    
    return true;
  }

  // Get a list of common input formatters
  static List<TextInputFormatter> getNameFormatters() {
    return [
      FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z\s\-\'\.]+$")),
      LengthLimitingTextInputFormatter(50),
    ];
  }

  static List<TextInputFormatter> getEmailFormatters() {
    return [
      FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z0-9@\.\-_]+")),
      LengthLimitingTextInputFormatter(254),
    ];
  }

  static List<TextInputFormatter> getSubjectFormatters() {
    return [
      FilteringTextInputFormatter.allow(RegExp(r"[a-zA-Z0-9\s\-\(\)]+")),
      LengthLimitingTextInputFormatter(30),
    ];
  }
}

// Custom input decoration with validation
class CustomInputDecoration {
  static InputDecoration getDecoration({
    required String labelText,
    String? hintText,
    IconData? prefixIcon,
    bool isRequired = true,
    String? errorText,
  }) {
    return InputDecoration(
      labelText: isRequired ? '$labelText *' : labelText,
      hintText: hintText,
      errorText: errorText,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.blue, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.red, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }
}

// Form validation helper
class FormValidator {
  static bool validateForm(GlobalKey<FormState> formKey) {
    return formKey.currentState?.validate() ?? false;
  }

  static void saveForm(GlobalKey<FormState> formKey) {
    formKey.currentState?.save();
  }

  static Map<String, String> sanitizeFormData(Map<String, String> data) {
    final sanitized = <String, String>{};
    
    data.forEach((key, value) {
      switch (key.toLowerCase()) {
        case 'email':
          sanitized[key] = Validators.sanitizeEmail(value);
          break;
        case 'name':
        case 'fullname':
        case 'full_name':
          sanitized[key] = Validators.sanitizeName(value);
          break;
        default:
          sanitized[key] = Validators.sanitizeText(value);
          break;
      }
    });
    
    return sanitized;
  }
}