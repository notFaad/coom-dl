class CatalyexConfig {
  static const String ENGINE_NAME = 'Catalyex';
  static const int ENGINE_ID = 3;

  // Performance configuration
  static const int DEFAULT_THREADS = 6;
  static const int MAX_THREADS = 12;
  static const int MAX_RETRIES = 5;
  static const Duration RETRY_DELAY = Duration(seconds: 2);
  static const Duration CONNECT_TIMEOUT = Duration(seconds: 30);
  static const Duration RECEIVE_TIMEOUT = Duration(seconds: 60);

  // Site-specific optimizations
  static const Map<String, Map<String, dynamic>> SITE_CONFIGS = {
    'coomer': {
      'threads': 4,
      'delay': 1000, // ms between requests
      'strategy': 'conservative',
      'headers': {
        'Accept': 'text/css',
        'User-Agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Referer': 'https://coomer.st/',
      }
    },
    'kemono': {
      'threads': 4,
      'delay': 1000,
      'strategy': 'conservative',
      'headers': {
        'Accept': 'text/css',
        'User-Agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Referer': 'https://kemono.party/',
      }
    },
    'erome': {
      'threads': 6,
      'delay': 500,
      'strategy': 'aggressive',
      'headers': {
        'User-Agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      }
    },
    'fapello': {
      'threads': 8,
      'delay': 300,
      'strategy': 'aggressive',
      'headers': {
        'User-Agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      }
    },
    'cyberdrop': {
      'threads': 10,
      'delay': 200,
      'strategy': 'aggressive',
      'headers': {
        'User-Agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      }
    },
    'generic': {
      'threads': DEFAULT_THREADS,
      'delay': 1000,
      'strategy': 'balanced',
      'headers': {
        'User-Agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      }
    }
  };

  /// Detect site type from URL
  static String detectSiteType(String url) {
    url = url.toLowerCase();

    if (url.contains('coomer.')) {
      return 'coomer';
    } else if (url.contains('kemono.')) {
      return 'kemono';
    } else if (url.contains('erome.')) {
      return 'erome';
    } else if (url.contains('fapello.')) {
      return 'fapello';
    } else if (url.contains('cyberdrop.')) {
      return 'cyberdrop';
    } else {
      return 'generic';
    }
  }

  /// Get optimized settings for a specific URL/site
  static Map<String, dynamic> getOptimizedSettings(String url) {
    String siteType = detectSiteType(url);
    Map<String, dynamic> config =
        Map.from(SITE_CONFIGS[siteType] ?? SITE_CONFIGS['generic']!);

    // Add runtime optimizations
    config['site_type'] = siteType;
    config['max_retries'] = MAX_RETRIES;
    config['connect_timeout'] = CONNECT_TIMEOUT.inMilliseconds;
    config['receive_timeout'] = RECEIVE_TIMEOUT.inMilliseconds;

    return config;
  }

  /// Get optimized headers for a specific URL
  static Map<String, String> getOptimizedHeaders(String url) {
    String siteType = detectSiteType(url);
    Map<String, dynamic> config =
        SITE_CONFIGS[siteType] ?? SITE_CONFIGS['generic']!;

    Map<String, String> headers =
        Map<String, String>.from(config['headers'] ?? {});

    // Add dynamic headers based on URL
    if (url.contains('download.php')) {
      headers['Accept'] = 'text/css';
    }

    return headers;
  }

  /// Calculate optimal thread count based on system and site
  static int calculateOptimalThreads(String siteType, {int? systemCores}) {
    Map<String, dynamic> config =
        SITE_CONFIGS[siteType] ?? SITE_CONFIGS['generic']!;
    int baseThreads = config['threads'] ?? DEFAULT_THREADS;

    // Adjust based on system capabilities if provided
    if (systemCores != null) {
      int maxAllowed =
          (systemCores * 0.75).round(); // Use 75% of available cores
      return baseThreads > maxAllowed ? maxAllowed : baseThreads;
    }

    return baseThreads;
  }

  /// Get delay between requests for rate limiting
  static Duration getRequestDelay(String siteType) {
    Map<String, dynamic> config =
        SITE_CONFIGS[siteType] ?? SITE_CONFIGS['generic']!;
    int delayMs = config['delay'] ?? 1000;
    return Duration(milliseconds: delayMs);
  }

  /// Determine if site requires conservative approach
  static bool requiresConservativeApproach(String siteType) {
    Map<String, dynamic> config =
        SITE_CONFIGS[siteType] ?? SITE_CONFIGS['generic']!;
    String strategy = config['strategy'] ?? 'balanced';
    return strategy == 'conservative';
  }

  /// Get performance tier for site
  static String getPerformanceTier(String siteType) {
    Map<String, dynamic> config =
        SITE_CONFIGS[siteType] ?? SITE_CONFIGS['generic']!;
    return config['strategy'] ?? 'balanced';
  }
}
