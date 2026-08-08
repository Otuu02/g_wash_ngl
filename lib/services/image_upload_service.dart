// lib/services/image_upload_service.dart
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ImageUploadService {
  // âœ… YOUR IMGBB API KEY
  static const String apiKey = 'd06ac97ee8900090daf829a31655876c';

  static Future<String?> uploadImage({
    required File image,
    required String fileName,
  }) async {
    try {
      debugPrint('ðŸ“¤ Uploading to imgBB...');
      debugPrint('ðŸ“„ File: $fileName');

      // Read image as bytes
      final bytes = await image.readAsBytes();
      
      // Check file size (imgBB max is 16MB)
      if (bytes.length > 16 * 1024 * 1024) {
        throw Exception('Image too large. Max 16MB.');
      }
      
      // Convert to base64
      final base64Image = base64Encode(bytes);

      // Upload to imgBB
      final response = await http.post(
        Uri.parse('https://api.imgbb.com/1/upload'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'key': apiKey,
          'image': base64Image,
          'name': fileName,
          'expiration': '0', // 0 = never expires
        },
      );

      final data = jsonDecode(response.body);

      debugPrint('ðŸ“¡ Response status: ${response.statusCode}');

      if (data['success'] == true) {
        final imageUrl = data['data']['url'];
        final thumbUrl = data['data']['thumb']['url'];
        debugPrint('âœ… Upload successful: $imageUrl');
        debugPrint('âœ… Thumb URL: $thumbUrl');
        return imageUrl;
      } else {
        final errorMsg = data['error']?['message'] ?? 'Unknown error';
        debugPrint('âŒ Upload failed: $errorMsg');
        return null;
      }
    } catch (e) {
      debugPrint('âŒ Upload error: $e');
      return null;
    }
  }
}
