import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:kyc_verification_app_demo/core/utils/toast_utils.dart';

class FilePickerHelper {
  /// Pick a single file with configurable options.
  static Future<File?> pickFile({
    required BuildContext context,
    required void Function(File file, String fileName, bool isImageFile)
        onFileSelected,
    List<String> supportedExtensions = const ['pdf', 'jpg', 'jpeg', 'png'],
    int maxFileSizeInBytes = 5 * 1024 * 1024, // default 5MB
    int? minFileSizeInBytes,
  }) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: supportedExtensions,
      );

      if (!context.mounted) return null;

      if (result != null) {
        final pickedFile = result.files.single;

        if (!_validateFileSize(
          context: context,
          size: pickedFile.size,
          max: maxFileSizeInBytes,
          min: minFileSizeInBytes,
        )) {
          return null;
        }

        final fileName = pickedFile.name;
        final selectedFile = File(pickedFile.path!);
        final isImageFile = _isImage(fileName);

        onFileSelected(selectedFile, fileName, isImageFile);
        return selectedFile;
      }
    } catch (e) {
      if (!context.mounted) return null;
      _showErrorToast(context, message: 'Failed to select file: $e');
    }

    return null;
  }

  /// Pick multiple files with configurable options.
  static Future<List<File>> pickFiles({
    required BuildContext context,
    required void Function(List<File> files) onFilesSelected,
    List<String> supportedExtensions = const ['pdf', 'jpg', 'jpeg', 'png'],
    int maxFileSizeInBytes = 5 * 1024 * 1024,
    int? minFileSizeInBytes,
  }) async {
    final List<File> validFiles = [];

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowMultiple: true,
        allowedExtensions: supportedExtensions,
      );

      if (!context.mounted) return [];

      if (result != null) {
        for (final pickedFile in result.files) {
          if (!_validateFileSize(
            context: context,
            size: pickedFile.size,
            max: maxFileSizeInBytes,
            min: minFileSizeInBytes,
          )) {
            continue;
          }

          final selectedFile = File(pickedFile.path!);
          validFiles.add(selectedFile);
        }

        if (validFiles.isNotEmpty) {
          onFilesSelected(validFiles);
        }
      }
    } catch (e) {
      if (!context.mounted) return [];
      _showErrorToast(context, message: 'Failed to select files: $e');
    }

    return validFiles;
  }

  /// ------------------------
  /// Helpers
  /// ------------------------

  static bool _validateFileSize({
    required BuildContext context,
    required int size,
    required int max,
    int? min,
  }) {
    if (size > max) {
      if (!context.mounted) return false;
      _showErrorToast(
        context,
        message: 'File size exceeds ${max ~/ (1024 * 1024)}MB limit',
      );
      return false;
    }

    if (min != null && size < min) {
      if (!context.mounted) return false;
      _showErrorToast(
        context,
        message:
            'File size is too small (min ${(min / 1024).toStringAsFixed(1)} KB)',
      );
      return false;
    }

    return true;
  }

  static bool _isImage(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    return ['jpg', 'jpeg', 'png'].contains(extension);
  }

  static void _showErrorToast(BuildContext context, {required String message}) {
    ToastUtil.showErrorToast(message);
  }
}
