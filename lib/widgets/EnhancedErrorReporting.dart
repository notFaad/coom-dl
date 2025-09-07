import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../constant/appcolors.dart';

enum ErrorSeverity { low, medium, high, critical }

class ErrorDetails {
  final String message;
  final String? code;
  final ErrorSeverity severity;
  final DateTime timestamp;
  final String? stackTrace;
  final Map<String, dynamic>? context;
  final String? suggestion;

  ErrorDetails({
    required this.message,
    this.code,
    this.severity = ErrorSeverity.medium,
    DateTime? timestamp,
    this.stackTrace,
    this.context,
    this.suggestion,
  }) : timestamp = timestamp ?? DateTime.now();
}

class EnhancedErrorDialog extends StatelessWidget {
  final ErrorDetails error;
  final VoidCallback? onRetry;
  final VoidCallback? onIgnore;

  const EnhancedErrorDialog({
    Key? key,
    required this.error,
    this.onRetry,
    this.onIgnore,
  }) : super(key: key);

  Color _getSeverityColor() {
    switch (error.severity) {
      case ErrorSeverity.low:
        return Colors.blue[400]!;
      case ErrorSeverity.medium:
        return Colors.orange[400]!;
      case ErrorSeverity.high:
        return Colors.red[400]!;
      case ErrorSeverity.critical:
        return Colors.red[700]!;
    }
  }

  IconData _getSeverityIcon() {
    switch (error.severity) {
      case ErrorSeverity.low:
        return Icons.info;
      case ErrorSeverity.medium:
        return Icons.warning;
      case ErrorSeverity.high:
        return Icons.error;
      case ErrorSeverity.critical:
        return Icons.dangerous;
    }
  }

  String _getSeverityText() {
    switch (error.severity) {
      case ErrorSeverity.low:
        return 'INFO';
      case ErrorSeverity.medium:
        return 'WARNING';
      case ErrorSeverity.high:
        return 'ERROR';
      case ErrorSeverity.critical:
        return 'CRITICAL';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Appcolors.appBackgroundColor,
          border: Border.all(
            color: _getSeverityColor().withOpacity(0.3),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: _getSeverityColor().withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: _getSeverityColor().withOpacity(0.1),
                  ),
                  child: Icon(
                    _getSeverityIcon(),
                    color: _getSeverityColor(),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getSeverityText(),
                        style: TextStyle(
                          color: _getSeverityColor(),
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Error occurred during operation',
                        style: TextStyle(
                          color: Appcolors.appPrimaryColor.withOpacity(0.7),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close,
                    color: Appcolors.appPrimaryColor.withOpacity(0.7),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Error message
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Appcolors.appAccentColor.withOpacity(0.05),
                border: Border.all(
                  color: Appcolors.appAccentColor.withOpacity(0.1),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Error Message:',
                    style: TextStyle(
                      color: Appcolors.appPrimaryColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    error.message,
                    style: TextStyle(
                      color: Appcolors.appPrimaryColor.withOpacity(0.9),
                      fontSize: 11,
                    ),
                  ),
                  if (error.code != null) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          'Error Code: ',
                          style: TextStyle(
                            color: Appcolors.appPrimaryColor.withOpacity(0.7),
                            fontSize: 10,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: _getSeverityColor().withOpacity(0.1),
                          ),
                          child: Text(
                            error.code!,
                            style: TextStyle(
                              color: _getSeverityColor(),
                              fontSize: 10,
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            // Suggestion
            if (error.suggestion != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.blue[50]?.withOpacity(0.1),
                  border: Border.all(
                    color: Colors.blue[300]!.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          color: Colors.blue[400],
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Suggestion:',
                          style: TextStyle(
                            color: Colors.blue[400],
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      error.suggestion!,
                      style: TextStyle(
                        color: Appcolors.appPrimaryColor.withOpacity(0.8),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Context information
            if (error.context != null && error.context!.isNotEmpty) ...[
              const SizedBox(height: 12),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  'Technical Details',
                  style: TextStyle(
                    color: Appcolors.appPrimaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: Appcolors.appAccentColor.withOpacity(0.05),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: error.context!.entries
                          .map((entry) => Padding(
                                padding: const EdgeInsets.only(bottom: 2),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${entry.key}: ',
                                      style: TextStyle(
                                        color: Appcolors.appPrimaryColor
                                            .withOpacity(0.7),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        entry.value.toString(),
                                        style: TextStyle(
                                          color: Appcolors.appPrimaryColor
                                              .withOpacity(0.8),
                                          fontSize: 10,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 16),

            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Copy button
                TextButton.icon(
                  onPressed: () {
                    final errorText = '''
Error: ${error.message}
Code: ${error.code ?? 'N/A'}
Severity: ${_getSeverityText()}
Time: ${error.timestamp}
${error.suggestion != null ? 'Suggestion: ${error.suggestion}' : ''}
''';
                    Clipboard.setData(ClipboardData(text: errorText));
                    Get.showSnackbar(
                      GetSnackBar(
                        message: 'Error details copied to clipboard',
                        duration: const Duration(seconds: 2),
                        backgroundColor: Colors.green.withOpacity(0.8),
                        snackPosition: SnackPosition.TOP,
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy'),
                  style: TextButton.styleFrom(
                    foregroundColor: Appcolors.appPrimaryColor.withOpacity(0.7),
                  ),
                ),

                if (onIgnore != null) ...[
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onIgnore!();
                    },
                    child: const Text('Ignore'),
                    style: TextButton.styleFrom(
                      foregroundColor:
                          Appcolors.appPrimaryColor.withOpacity(0.7),
                    ),
                  ),
                ],

                if (onRetry != null) ...[
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      onRetry!();
                    },
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Retry'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _getSeverityColor(),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],

                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Appcolors.appAccentColor,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ErrorReportingService {
  static void showError(
    BuildContext context,
    ErrorDetails error, {
    VoidCallback? onRetry,
    VoidCallback? onIgnore,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => EnhancedErrorDialog(
        error: error,
        onRetry: onRetry,
        onIgnore: onIgnore,
      ),
    );
  }

  static void showDownloadError(
    BuildContext context, {
    required String message,
    String? url,
    String? fileName,
    int? httpCode,
    VoidCallback? onRetry,
  }) {
    final error = ErrorDetails(
      message: message,
      code: httpCode?.toString(),
      severity: httpCode != null && httpCode >= 500
          ? ErrorSeverity.high
          : ErrorSeverity.medium,
      context: {
        if (url != null) 'URL': url,
        if (fileName != null) 'File': fileName,
        if (httpCode != null) 'HTTP Code': httpCode,
      },
      suggestion: _getDownloadSuggestion(httpCode),
    );

    showError(context, error, onRetry: onRetry);
  }

  static void showScrapingError(
    BuildContext context, {
    required String message,
    String? url,
    String? siteType,
    VoidCallback? onRetry,
  }) {
    final error = ErrorDetails(
      message: message,
      severity: ErrorSeverity.high,
      context: {
        if (url != null) 'Source URL': url,
        if (siteType != null) 'Site Type': siteType,
      },
      suggestion: 'Check if the URL is correct and the site is accessible. '
          'Some sites may have changed their structure or require login.',
    );

    showError(context, error, onRetry: onRetry);
  }

  static String _getDownloadSuggestion(int? httpCode) {
    switch (httpCode) {
      case 403:
        return 'Access denied. The server may be blocking requests or the content is restricted.';
      case 404:
        return 'File not found. The media may have been removed or the link is invalid.';
      case 429:
        return 'Too many requests. Try reducing the number of concurrent downloads.';
      case 500:
      case 502:
      case 503:
        return 'Server error. The hosting service may be experiencing issues. Try again later.';
      default:
        return 'Check your internet connection and try again. If the problem persists, the source may be unavailable.';
    }
  }
}
