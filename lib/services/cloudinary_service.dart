// FILE: lib/services/cloudinary_service.dart
// PURPOSE: Direct signed image upload to Cloudinary using API Key and Secret

import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import '../config/env.dart';

class CloudinaryService {
  static final CloudinaryService _instance = CloudinaryService._internal();
  factory CloudinaryService() => _instance;
  CloudinaryService._internal();

  /// Uploads an image file to Cloudinary using signed authentication
  Future<String?> uploadImage({
    required XFile imageFile,
    String folder = 'profile_pictures',
    String? customCloudName,
    String? customApiKey,
    String? customApiSecret,
  }) async {
    try {
      final cloudName = (customCloudName ?? Env.cloudinaryCloudName).trim();
      final apiKey = (customApiKey ?? Env.cloudinaryApiKey).trim();
      final apiSecret = (customApiSecret ?? Env.cloudinaryApiSecret).trim();

      if (cloudName.isEmpty) {
        throw Exception('Cloudinary configuration error: Cloud Name is missing.');
      }

      final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
      final request = http.MultipartRequest('POST', uri);

      final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();

      if (apiKey.isNotEmpty && apiSecret.isNotEmpty) {
        // Generate SHA-1 signature: folder=...&timestamp=...<apiSecret>
        final toSign = 'folder=$folder&timestamp=$timestamp$apiSecret';
        final signature = sha1.convert(utf8.encode(toSign)).toString();

        request.fields['api_key'] = apiKey;
        request.fields['timestamp'] = timestamp;
        request.fields['signature'] = signature;
        request.fields['folder'] = folder;
      } else {
        // Simple direct upload with timestamp if API key/secret not set yet
        request.fields['timestamp'] = timestamp;
        request.fields['folder'] = folder;
      }

      // Add image file bytes
      final bytes = await imageFile.readAsBytes();
      final multipartFile = http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: imageFile.name.isNotEmpty ? imageFile.name : 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      request.files.add(multipartFile);

      debugPrint('☁️ Uploading image to Cloudinary ($cloudName)...');

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> responseData = jsonDecode(response.body);
        final String? secureUrl = responseData['secure_url'];

        if (secureUrl != null && secureUrl.isNotEmpty) {
          debugPrint('✅ Cloudinary Upload Success: $secureUrl');
          return secureUrl;
        } else {
          throw Exception('No secure URL returned from Cloudinary response.');
        }
      } else {
        final Map<String, dynamic> errorData = jsonDecode(response.body);
        final errorMessage = errorData['error']?['message'] ?? 'Upload failed with status ${response.statusCode}';
        throw Exception('Cloudinary error: $errorMessage');
      }
    } catch (e) {
      debugPrint('❌ Cloudinary Upload Error: $e');
      rethrow;
    }
  }
}
