// lib/services/cloudinary_service.dart
import 'dart:io';
import 'package:http/http.dart' as http;
import 'dart:convert';

class CloudinaryService {
  static const String cloudName = 'dijqk2arj';
  static const String apiKey = '862473269516361';

  static Future<String?> uploadImage({
    required File image,
    required String folder,
  }) async {
    try {
      print('📤 Uploading to Cloudinary...');
      print('📁 Folder: $folder');
      print('📄 File size: ${await image.length()} bytes');

      // Create multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload'),
      );

      // Add required fields
      request.fields['upload_preset'] = 'ML default';
      request.fields['folder'] = folder;
      request.fields['api_key'] = apiKey;

      // Add file
      request.files.add(
        await http.MultipartFile.fromPath(
          'file',
          image.path,
        ),
      );

      // Send request with timeout
      var response = await request.send().timeout(const Duration(seconds: 30));
      var responseData = await response.stream.bytesToString();
      var jsonResponse = jsonDecode(responseData);

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body: $responseData');

      if (response.statusCode == 200 && jsonResponse['secure_url'] != null) {
        final url = jsonResponse['secure_url'];
        print('✅ Upload successful: $url');
        return url;
      } else {
        final errorMsg = jsonResponse['error']?['message'] ?? 'Upload failed';
        print('❌ Upload failed: $errorMsg');
        return null;
      }
    } catch (e) {
      print('❌ Upload error: $e');
      return null;
    }
  }
}
