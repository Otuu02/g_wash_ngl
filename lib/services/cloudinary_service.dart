// lib/services/cloudinary_service.dart
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CloudinaryService {
  static const String cloudName = 'dijqk2arj';
  static const String apiKey = '862473269516361';
  static const String uploadPreset = 'ML default';

  static Future<String?> uploadImage({
    required File image,
    required String folder,
  }) async {
    try {
      print('📤 Uploading to Cloudinary via Base64...');

      // 1. Read image as bytes
      final bytes = await image.readAsBytes();
      
      // 2. Convert to Base64
      final base64Image = base64Encode(bytes);

      // 3. Send to Cloudinary as Base64
      final response = await http.post(
        Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'upload_preset': uploadPreset,
          'folder': folder,
          'api_key': apiKey,
          'file': 'data:image/jpeg;base64,$base64Image',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['secure_url'] != null) {
        print('✅ Upload successful: ${data['secure_url']}');
        return data['secure_url'];
      } else {
        print('❌ Upload failed: ${data['error']?['message'] ?? 'Unknown error'}');
        return null;
      }
    } catch (e) {
      print('❌ Upload error: $e');
      return null;
    }
  }
}
