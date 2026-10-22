/// Pure Dart models for the Japanese audio pronunciation pack.
///
/// Strictly free of Flutter UI widget imports to maintain unit-testability.
library;

/// The current status of the offline audio pack.
enum AudioPackStatus {
  notInstalled,
  downloading,
  extracting,
  installed,
  error,
}

/// Metadata describing an installed audio pack.
class AudioPackMeta {
  final String title;
  final String version;
  final int entryCount;
  final int totalSizeBytes;
  final DateTime installedAt;

  const AudioPackMeta({
    required this.title,
    required this.version,
    required this.entryCount,
    required this.totalSizeBytes,
    required this.installedAt,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'version': version,
    'entryCount': entryCount,
    'totalSizeBytes': totalSizeBytes,
    'installedAt': installedAt.toIso8601String(),
  };

  factory AudioPackMeta.fromJson(Map<String, dynamic> json) => AudioPackMeta(
    title: json['title'] as String? ?? 'Japanese Audio Pack',
    version: json['version'] as String? ?? '1.0.0',
    entryCount: json['entryCount'] as int? ?? 0,
    totalSizeBytes: json['totalSizeBytes'] as int? ?? 0,
    installedAt: DateTime.tryParse(json['installedAt'] as String? ?? '') ??
        DateTime.now(),
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioPackMeta &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          version == other.version &&
          entryCount == other.entryCount &&
          totalSizeBytes == other.totalSizeBytes &&
          installedAt == other.installedAt;

  @override
  int get hashCode => Object.hash(
        title,
        version,
        entryCount,
        totalSizeBytes,
        installedAt,
      );

  @override
  String toString() =>
      'AudioPackMeta(title: $title, v: $version, entries: $entryCount, bytes: $totalSizeBytes)';
}

/// Immutable state snapshot of the audio pack manager.
class AudioPackState {
  final AudioPackStatus status;
  final AudioPackMeta? meta;
  final double progress;
  final String? error;
  final String? successMessage;
  final bool isDeleting;

  const AudioPackState({
    this.status = AudioPackStatus.notInstalled,
    this.meta,
    this.progress = 0.0,
    this.error,
    this.successMessage,
    this.isDeleting = false,
  });

  bool get isInstalled => status == AudioPackStatus.installed;
  bool get isDownloading => status == AudioPackStatus.downloading;
  bool get isExtracting => status == AudioPackStatus.extracting;
  bool get isBusy => isDownloading || isExtracting || isDeleting;
  int get wordCount => meta?.entryCount ?? 0;
  int get totalSizeBytes => meta?.totalSizeBytes ?? 0;

  AudioPackState copyWith({
    AudioPackStatus? status,
    AudioPackMeta? meta,
    double? progress,
    String? error,
    String? successMessage,
    bool? isDeleting,
  }) {
    return AudioPackState(
      status: status ?? this.status,
      meta: meta ?? this.meta,
      progress: progress ?? this.progress,
      error: error,
      successMessage: successMessage,
      isDeleting: isDeleting ?? this.isDeleting,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioPackState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          meta == other.meta &&
          progress == other.progress &&
          error == other.error &&
          successMessage == other.successMessage &&
          isDeleting == other.isDeleting;

  @override
  int get hashCode => Object.hash(
        status,
        meta,
        progress,
        error,
        successMessage,
        isDeleting,
      );

  @override
  String toString() =>
      'AudioPackState(status: $status, words: $wordCount, progress: $progress, error: $error)';
}
