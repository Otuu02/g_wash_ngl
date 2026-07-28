// lib/services/cloudinary_service.dart
import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';

class CloudinaryService {
  static final CloudinaryService _instance = CloudinaryService._internal();
  factory CloudinaryService() => _instance;
  CloudinaryService._internal();

  // ✅ YOUR CREDENTIALS
  static const String cloudName = 'dijqk2arj';
  static const String apiKey = '862473269516361';
  static const String apiSecret = '4JpMPFJbMlHE3qulwj0_oe_8lJI';

  final CloudinaryPublic _cloudinary = CloudinaryPublic(
    cloudName,
    apiKey,
    apiSecret,
  );

  Future<String?> uploadImage({
    required File image,
    required String folder,
    String? fileName,
  }) async {
    try {
      print('📤 Uploading to Cloudinary...');
      
      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          image.path,
          folder: folder,
          resourceType: CloudinaryResourceType.Image,
          fileName: fileName ?? DateTime.now().millisecondsSinceEpoch.toString(),
        ),
      );

      if (response.isSuccessful) {
        print('✅ Upload successful: ${response.secureUrl}');
        return response.secureUrl;
      } else {
        print('❌ Upload failed: ${response.error?.message}');
        return null;
      }
    } catch (e) {
      print('❌ Upload error: $e');
      return null;
    }
  }

  Future<List<String>> uploadMultipleImages({
    required List<File> images,
    required String folder,
  }) async {
    List<String> urls = [];
    for (var image in images) {
      final url = await uploadImage(
        image: image,
        folder: folder,
      );
      if (url != null) {
        urls.add(url);
      }
    }
    return urls;
  }
}
