import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../config/supabase_config.dart';

class FirebaseAiService {
  FirebaseAiService({
    GenerativeModel? model,
    FirebaseFirestore? firestore,
    sb.SupabaseClient? supabaseClient,
  }) : _model =
           model ??
           FirebaseAI.googleAI().generativeModel(model: 'gemini-3.7-flash'),
       _firestore = firestore ?? FirebaseFirestore.instance,
       _supabase = supabaseClient ?? sb.Supabase.instance.client;

  final GenerativeModel _model;
  final FirebaseFirestore _firestore;
  final sb.SupabaseClient _supabase;

  static const int _maximumPdfBytes = 14 * 1024 * 1024;

  // ============================================================
  // CONNECTION TEST
  // ============================================================

  Future<String> testConnection() async {
    try {
      final GenerateContentResponse response = await _model.generateContent([
        Content.text(
          'This is a Firebase AI Logic connectivity test for an '
          'e-learning application named CASLMS. '
          'Reply with exactly: CASLMS AI CONNECTED',
        ),
      ]);

      final String text = (response.text ?? '').trim();

      if (text.isEmpty) {
        throw FirebaseAiServiceException('Gemini returned an empty response.');
      }

      return text;
    } catch (e) {
      if (e is FirebaseAiServiceException) {
        rethrow;
      }

      throw FirebaseAiServiceException('Unable to connect to Gemini: $e');
    }
  }

  // ============================================================
  // ANALYZE PDF LEARNING MATERIAL
  //
  // Flow:
  // Firestore metadata
  //     ↓
  // Supabase Storage
  //     ↓
  // PDF bytes
  //     ↓
  // Firebase AI Logic
  //     ↓
  // Gemini
  //     ↓
  // Analysis saved back to Firestore
  //
  // IMPORTANT:
  // This first version supports PDF files only.
  // ============================================================

  Future<AiMaterialAnalysisResult> analyzePdfMaterial({
    required Map<String, dynamic> material,
    required String courseTitle,
    required String moduleTitle,
  }) async {
    final String resourceId = (material['resourceId'] ?? material['id'] ?? '')
        .toString()
        .trim();

    if (resourceId.isEmpty) {
      throw FirebaseAiServiceException('Learning material ID is missing.');
    }

    final String deliveryType = (material['deliveryType'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    if (deliveryType != 'uploaded_file') {
      throw FirebaseAiServiceException(
        'Only uploaded PDF files can currently be analyzed by AI.',
      );
    }

    if (material['aiEligible'] != true) {
      throw FirebaseAiServiceException(
        'This learning material is not AI-eligible.',
      );
    }

    final String fileName = (material['fileName'] ?? '').toString().trim();

    final String resourceType = (material['resourceType'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    final String mimeType = (material['mimeType'] ?? '')
        .toString()
        .trim()
        .toLowerCase();

    final bool isPdf =
        resourceType == 'pdf' ||
        mimeType == 'application/pdf' ||
        fileName.toLowerCase().endsWith('.pdf');

    if (!isPdf) {
      throw FirebaseAiServiceException(
        'Phase 13B currently supports PDF learning materials only.',
      );
    }

    final String storagePath = (material['storagePath'] ?? '')
        .toString()
        .trim();

    if (storagePath.isEmpty) {
      throw FirebaseAiServiceException('The Supabase storage path is missing.');
    }

    final int declaredSize = (material['sizeBytes'] as num?)?.toInt() ?? 0;

    if (declaredSize > _maximumPdfBytes) {
      throw FirebaseAiServiceException(
        'This PDF is too large for the current AI analysis limit. '
        'Use a PDF smaller than 14 MB.',
      );
    }

    final DocumentReference<Map<String, dynamic>> resourceReference = _firestore
        .collection('moduleResources')
        .doc(resourceId);

    // ==========================================================
    // MARK AS PROCESSING
    // ==========================================================

    await resourceReference.update({
      'aiProcessingStatus': 'processing',
      'aiError': null,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    try {
      // ========================================================
      // DOWNLOAD PDF FROM SUPABASE
      // ========================================================

      final bytes = await _supabase.storage
          .from(SupabaseConfig.learningMaterialsBucket)
          .download(storagePath);

      if (bytes.isEmpty) {
        throw FirebaseAiServiceException('The downloaded PDF is empty.');
      }

      if (bytes.length > _maximumPdfBytes) {
        throw FirebaseAiServiceException(
          'This PDF is too large for the current AI analysis limit. '
          'Use a PDF smaller than 14 MB.',
        );
      }

      // ========================================================
      // PROMPT
      //
      // Gemini must use only the attached material.
      // ========================================================

      final TextPart prompt = TextPart('''
You are analyzing a learning material for CASLMS.

Use ONLY the attached PDF as your source.
Do not add facts that are not supported by the PDF.
If information is missing from the PDF, say that it is not provided.

Course: $courseTitle
Module: $moduleTitle
File: $fileName

Return a concise analysis using exactly these sections:

MATERIAL UNDERSTOOD

MAIN TOPICS
- List the most important topics covered by the PDF.

BRIEF SUMMARY
Write a clear summary of the material in 1 to 3 short paragraphs.

KEY TERMS
- List important terms or concepts found in the PDF.

POSSIBLE LEARNING OBJECTIVES
- List learning objectives that are directly supported by the material.
''');

      final InlineDataPart pdfPart = InlineDataPart('application/pdf', bytes);

      // ========================================================
      // SEND PDF TO GEMINI
      // ========================================================

      final GenerateContentResponse response = await _model.generateContent([
        Content.multi([prompt, pdfPart]),
      ]);

      final String analysis = (response.text ?? '').trim();

      if (analysis.isEmpty) {
        throw FirebaseAiServiceException('Gemini returned an empty analysis.');
      }

      // ========================================================
      // SAVE SUCCESSFUL RESULT
      // ========================================================

      await resourceReference.update({
        'aiProcessingStatus': 'ready',
        'aiAnalysisSummary': analysis,
        'aiModel': 'gemini-3.7-flash',
        'aiSourceBytes': bytes.length,
        'aiProcessedAt': FieldValue.serverTimestamp(),
        'aiError': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return AiMaterialAnalysisResult(
        resourceId: resourceId,
        fileName: fileName,
        analysis: analysis,
        sourceBytes: bytes.length,
      );
    } catch (e) {
      final String message = e is FirebaseAiServiceException
          ? e.message
          : 'Unable to analyze the PDF with Gemini: $e';

      // Best effort: keep an error status in Firestore.
      try {
        await resourceReference.update({
          'aiProcessingStatus': 'failed',
          'aiError': message,
          'aiProcessedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}

      if (e is FirebaseAiServiceException) {
        rethrow;
      }

      throw FirebaseAiServiceException(message);
    }
  }
}

// ============================================================
// PDF ANALYSIS RESULT
// ============================================================

class AiMaterialAnalysisResult {
  AiMaterialAnalysisResult({
    required this.resourceId,
    required this.fileName,
    required this.analysis,
    required this.sourceBytes,
  });

  final String resourceId;
  final String fileName;
  final String analysis;
  final int sourceBytes;
}

// ============================================================
// CUSTOM EXCEPTION
// ============================================================

class FirebaseAiServiceException implements Exception {
  FirebaseAiServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}
