import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// Real backing for every "Tap to change photo" / "Edit avatar" button in
/// the app — was previously either a no-op (`onPressed: () {}`) or a
/// placeholder dialog saying "Photo picker would open here."
///
/// Requires `image_picker` in pubspec.yaml, plus the platform permission
/// strings: iOS needs `NSPhotoLibraryUsageDescription` (and
/// `NSCameraUsageDescription` if [showCameraOption] is used) in
/// Info.plist; Android needs the READ_MEDIA_IMAGES / READ_EXTERNAL_STORAGE
/// permission for API level < 33 devices (image_picker's own docs cover
/// the exact manifest entries).
///
/// Only picks the file and hands it back — callers are responsible for
/// actually persisting it (e.g. via `ProfileRepository.uploadAvatar`,
/// which uploads to Firebase Storage and saves the resulting URL to the
/// profile doc's `photoUrl` field). Previously nothing called that, so a
/// newly picked photo only ever lived in local, in-session `File` state
/// and quietly reverted on the next app restart.
Future<File?> pickAvatarPhoto(BuildContext context) async {
  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Text('📷', style: TextStyle(fontSize: 20)),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(context).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Text('🖼️', style: TextStyle(fontSize: 20)),
              title: const Text('Choose from library'),
              onTap: () => Navigator.of(context).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    ),
  );
  if (source == null) return null;

  final picker = ImagePicker();
  final picked = await picker.pickImage(source: source, maxWidth: 800, maxHeight: 800, imageQuality: 85);
  if (picked == null) return null;
  return File(picked.path);
}
