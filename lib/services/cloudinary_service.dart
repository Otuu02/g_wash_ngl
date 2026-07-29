// lib/services/cloudinary_service.dart
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CloudinaryService {
  // Your Cloudinary credentials
  static const String cloudName = 'dijqk2arj';
  static const String apiKey = '862473269516361';
  static const String apiSecret = '4JpMPFJbMlHE3qulwj0_oe_8lJI';

  /// Upload a single image to Cloudinary
  /// Works on web, mobile, and desktop
  static Future<String?> uploadImage({
    required File image,
    required String folder,
  }) async {
    try {
      print('📤 Uploading to Cloudinary...');
      print('📁 Folder: $folder');
      print('📄 File: ${image.path}');

      // Read file as bytes
      final bytes = await image.readAsBytes();
      
      // Check file size (max 10MB for free tier)
      if (bytes.length > 10 * 1024 * 1024) {
        throw Exception('Image too large. Max 10MB.');
      }

      // Create multipart request - WORKS ON WEB!
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload'),
      );

      // Add fields
      request.fields['upload_preset'] = 'ML default';  // Your preset name
      request.fields['folder'] = folder;
      request.fields['api_key'] = apiKey;
      request.fields['public_id'] = '${DateTime.now().millisecondsSinceEpoch}';

      // Add file
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          image.path,
        ),
      );

      // Send request
      var response = await request.send();
      var responseData = await response.stream.bytesToString();
      var jsonResponse = jsonDecode(responseData);

      if (jsonResponse['secure_url'] != null) {
        final url = jsonResponse['secure_url'];
        print('✅ Upload successful: $url');
        return url;
      } else {
        final errorMsg = jsonResponse['error']?['message'] ?? 'Unknown error';
        print('❌ Upload failed: $errorMsg');
        return null;
      }
    } catch (e) {
      print('❌ Upload error: $e');
      return null;
    }
  }

  /// Upload multiple images to Cloudinary
  static Future<List<String>> uploadMultipleImages({
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
