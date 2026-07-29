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

  // ✅ CORRECT: Only cloudName and apiKey (no apiSecret)
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

      // ✅ CORRECT: Check if secureUrl exists
      if (response.secureUrl != null && response.secureUrl!.isNotEmpty) {
        print('✅ Upload successful: ${response.secureUrl}');
        return response.secureUrl;
      } else {
        print('❌ Upload failed');
        return null;
      }
    } catch (e) {
      print('❌ Upload error: $e');
      return null;
    }
  }
}
