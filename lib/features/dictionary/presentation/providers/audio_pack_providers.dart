import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/audio_pack_models.dart';
import '../../data/services/audio_pack_manager.dart';

/// Provider for the singleton instance of [AudioPackManager].
final audioPackManagerProvider = Provider<AudioPackManager>((ref) {
  return AudioPackManager();
});

/// Riverpod notifier managing audio pack installation, downloads, and custom zip imports.
class AudioPackNotifier extends Notifier<AudioPackState> {
  @override
  AudioPackState build() {
    final manager = ref.watch(audioPackManagerProvider);
    // Initialize status asynchronously without blocking build
    Future.microtask(() => checkStatus());
    return AudioPackState(
      status: manager.isInstalled
          ? AudioPackStatus.installed
          : AudioPackStatus.notInstalled,
      meta: manager.meta,
    );
  }

  /// Checks the filesystem for an installed audio pack and synchronizes state.
  Future<void> checkStatus() async {
    try {
      final manager = ref.read(audioPackManagerProvider);
      await manager.initialize();
      state = state.copyWith(
        status: manager.isInstalled
            ? AudioPackStatus.installed
            : AudioPackStatus.notInstalled,
        meta: manager.meta,
        error: null,
      );
    } catch (e) {
      debugPrint('[AudioPackNotifier] Failed to check status: $e');
    }
  }

  /// Downloads the curated Japanese word audio pack with progress updates.
  Future<void> download({String? url}) async {
    if (state.isBusy) return;

    state = state.copyWith(
      status: AudioPackStatus.downloading,
      progress: 0.0,
      error: null,
      successMessage: null,
    );

    try {
      final manager = ref.read(audioPackManagerProvider);
      final count = await manager.downloadPack(
        url: url,
        onProgress: (progress) {
          state = state.copyWith(
            status: progress < 0.85
                ? AudioPackStatus.downloading
                : AudioPackStatus.extracting,
            progress: progress,
          );
        },
      );

      state = AudioPackState(
        status: AudioPackStatus.installed,
        meta: manager.meta,
        progress: 1.0,
        successMessage: 'Audio pack installed ($count words).',
      );
    } catch (e) {
      state = state.copyWith(
        status: state.meta != null
            ? AudioPackStatus.installed
            : AudioPackStatus.notInstalled,
        error: 'Audio pack download failed: $e',
      );
    }
  }

  /// Imports and extracts a custom community audio pack `.zip` file.
  Future<void> importFromFile(File file) async {
    if (state.isBusy) return;

    state = state.copyWith(
      status: AudioPackStatus.extracting,
      progress: 0.0,
      error: null,
      successMessage: null,
    );

    try {
      final manager = ref.read(audioPackManagerProvider);
      final count = await manager.importZip(
        file,
        onProgress: (progress) {
          state = state.copyWith(
            status: AudioPackStatus.extracting,
            progress: progress,
          );
        },
      );

      state = AudioPackState(
        status: AudioPackStatus.installed,
        meta: manager.meta,
        progress: 1.0,
        successMessage: 'Audio pack imported ($count words).',
      );
    } catch (e) {
      state = state.copyWith(
        status: state.meta != null
            ? AudioPackStatus.installed
            : AudioPackStatus.notInstalled,
        error: 'Failed to import audio pack: $e',
      );
    }
  }

  /// Deletes the installed audio pack and frees storage.
  Future<void> delete() async {
    if (state.isBusy) return;

    state = state.copyWith(
      isDeleting: true,
      error: null,
      successMessage: null,
    );

    try {
      final manager = ref.read(audioPackManagerProvider);
      await manager.deletePack();
      state = const AudioPackState(
        status: AudioPackStatus.notInstalled,
        meta: null,
        successMessage: 'Audio pack deleted.',
      );
    } catch (e) {
      state = state.copyWith(
        isDeleting: false,
        error: 'Failed to delete audio pack: $e',
      );
    }
  }

  /// Clears transient error or success banners.
  void clearMessages() {
    state = state.copyWith(error: null, successMessage: null);
  }
}

/// Global provider for audio pack installation and download state.
final audioPackProvider =
    NotifierProvider<AudioPackNotifier, AudioPackState>(
  AudioPackNotifier.new,
);

/// Alias for [audioPackProvider] matching architecture specification.
final audioPackStateProvider = audioPackProvider;
