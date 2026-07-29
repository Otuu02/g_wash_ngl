// lib/services/cloudinary_service.dart
import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';

class CloudinaryService {
  static final CloudinaryService _instance = CloudinaryService._internal();
  factory CloudinaryService() => _instance;
  CloudinaryService._internal();

  // Your Cloudinary credentials
  static const String cloudName = 'dijqk2arj';
  static const String apiKey = '862473269516361';
  static const String apiSecret = '4JpMPFJbMlHE3qulwj0_oe_8lJI';

  // ✅ CORRECT constructor for version 0.23.1 (only 2 arguments)
  final CloudinaryPublic _cloudinary = CloudinaryPublic(
    cloudName,
    apiKey,
  );

  Future<String?> uploadImage({
    required File image,
    required String folder,
  }) async {
    try {
      print('📤 Uploading to Cloudinary...');

      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          image.path,
          resourceType: CloudinaryResourceType.Image,
          folder: folder,
        ),
      );

      // ✅ CORRECT way to check response for this version
      if (response.secureUrl != null && response.secureUrl!.isNotEmpty) {
        print('✅ Upload successful: ${response.secureUrl}');
        return response.secureUrl;
      } else {
        print('❌ Upload failed: ${response.error ?? "Unknown error"}');
        return null;
      }
    } catch (e) {
      print('❌ Upload error: $e');
      return null;
    }
  }
}
