import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  const OcrService._();

  static Future<String> recognize(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result = await recognizer.processImage(InputImage.fromFilePath(imagePath));
      return result.text.trim();
    } finally {
      await recognizer.close();
    }
  }
}
