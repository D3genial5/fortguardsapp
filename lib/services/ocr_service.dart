import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class OcrValidationResult {
  const OcrValidationResult({
    required this.success,
    this.reason,
    this.idNumber,
    this.raw,
  });

  final bool success;
  final String? reason;
  final String? idNumber;
  final Map<String, dynamic>? raw;

  factory OcrValidationResult.failure(String reason) {
    return OcrValidationResult(success: false, reason: reason);
  }
}

class OcrService {
  OcrService({http.Client? client}) : _client = client ?? http.Client();

  static const String baseUrl = String.fromEnvironment(
    'OCR_API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000',
  );

  final http.Client _client;

  Future<OcrValidationResult> validateId({
    required File frontImage,
    required File backImage,
  }) async {
    final uri = Uri.parse('$baseUrl/process-id');
    final request = http.MultipartRequest('POST', uri)
      ..files.add(await http.MultipartFile.fromPath('front_image', frontImage.path))
      ..files.add(await http.MultipartFile.fromPath('back_image', backImage.path));

    final response = await _client.send(request);
    final body = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      return OcrValidationResult.failure('http_${response.statusCode}');
    }

    final data = jsonDecode(body) as Map<String, dynamic>;
    final success = data['success'] == true;
    final reason = data['reason']?.toString();

    String? idNumber;
    final front = data['front'];
    if (front is Map<String, dynamic>) {
      idNumber = front['value']?.toString();
    }

    return OcrValidationResult(
      success: success,
      reason: reason,
      idNumber: idNumber?.trim(),
      raw: data,
    );
  }
}
