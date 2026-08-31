import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../config/supabase_config.dart';

class FirebaseAiService {
  FirebaseAiService({
    GenerativeModel? model,
    FirebaseFirestore? firestore,
    sb.SupabaseClient? supabaseClient,
  })  : _model = model ??
            FirebaseAI.googleAI().generativeModel(
              model: 'gemini-3.7-flash',
            ),
        _firestore = firestore ?? FirebaseFirestore.instance,
        _supabase = supabaseClient ?? sb.Supabase.instance.client;

  final GenerativeModel _model;
  final FirebaseFirestore _firestore;
  final sb.SupabaseClient _supabase;

  // ============================================================
  // CURRENT SAFE PDF LIMIT
  //
  // Firebase AI Logic inline requests have an overall request
  // size limit. We use 14 MB as a safe raw-PDF limit.
  // ============================================================

  static const int _maximumPdfBytes =
      14 * 1024 * 1024;

  // ============================================================
  // CONNECTION TEST
  // ============================================================

  Future<String> testConnection() async {
    try {
      final GenerateContentResponse response =
          await _model.generateContent(
        [
          Content.text(
            'This is a Firebase AI Logic connectivity test for an '
            'e-learning application named CASLMS. '
            'Reply with exactly: CASLMS AI CONNECTED',
          ),
        ],
      );

      final String text =
          (response.text ?? '').trim();

      if (text.isEmpty) {
        throw FirebaseAiServiceException(
          'Gemini returned an empty response.',
        );
      }

      return text;
    } catch (e) {
      if (e is FirebaseAiServiceException) {
        rethrow;
      }

      throw FirebaseAiServiceException(
        'Unable to connect to Gemini: $e',
      );
    }
  }

  // ============================================================
  // ANALYZE PDF LEARNING MATERIAL
  // ============================================================

  Future<AiMaterialAnalysisResult>
      analyzePdfMaterial({
    required Map<String, dynamic> material,
    required String courseTitle,
    required String moduleTitle,
  }) async {
    final _PdfMaterialInfo info =
        _validatePdfMaterial(
      material,
    );

    final DocumentReference<
        Map<String, dynamic>>
        resourceReference =
        _firestore
            .collection(
              'moduleResources',
            )
            .doc(
              info.resourceId,
            );

    // ==========================================================
    // MARK MATERIAL AS PROCESSING
    // ==========================================================

    await resourceReference.update({
      'aiProcessingStatus':
          'processing',

      'aiError':
          null,

      'updatedAt':
          FieldValue.serverTimestamp(),
    });

    try {
      // ========================================================
      // DOWNLOAD PDF FROM SUPABASE
      // ========================================================

      final Uint8List bytes =
          await _downloadPdfBytes(
        info,
      );

      // ========================================================
      // ANALYSIS PROMPT
      // ========================================================

      final TextPart prompt =
          TextPart(
        '''
You are analyzing a learning material for CASLMS.

Use ONLY the attached PDF as your source.
Do not add facts that are not supported by the PDF.
If information is missing from the PDF, say that it is not provided.

Course: $courseTitle
Module: $moduleTitle
File: ${info.fileName}

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
''',
      );

      // ========================================================
      // ATTACH PDF
      //
      // InlineDataPart requires Uint8List.
      // ========================================================

      final InlineDataPart pdfPart =
          InlineDataPart(
        'application/pdf',
        bytes,
      );

      // ========================================================
      // SEND TO GEMINI
      // ========================================================

      final GenerateContentResponse
          response =
          await _model.generateContent(
        [
          Content.multi(
            [
              prompt,
              pdfPart,
            ],
          ),
        ],
      );

      final String analysis =
          (response.text ?? '')
              .trim();

      if (analysis.isEmpty) {
        throw FirebaseAiServiceException(
          'Gemini returned an empty analysis.',
        );
      }

      // ========================================================
      // SAVE SUCCESSFUL ANALYSIS
      // ========================================================

      await resourceReference.update({
        'aiProcessingStatus':
            'ready',

        'aiAnalysisSummary':
            analysis,

        'aiModel':
            'gemini-3.7-flash',

        'aiSourceBytes':
            bytes.length,

        'aiProcessedAt':
            FieldValue.serverTimestamp(),

        'aiError':
            null,

        'updatedAt':
            FieldValue.serverTimestamp(),
      });

      return AiMaterialAnalysisResult(
        resourceId:
            info.resourceId,

        fileName:
            info.fileName,

        analysis:
            analysis,

        sourceBytes:
            bytes.length,
      );
    } catch (e) {
      final String message =
          e is FirebaseAiServiceException
              ? e.message
              : 'Unable to analyze the PDF with Gemini: $e';

      // ========================================================
      // SAVE FAILURE
      // ========================================================

      try {
        await resourceReference.update({
          'aiProcessingStatus':
              'failed',

          'aiError':
              message,

          'aiProcessedAt':
              FieldValue.serverTimestamp(),

          'updatedAt':
              FieldValue.serverTimestamp(),
        });
      } catch (_) {}

      if (e is FirebaseAiServiceException) {
        rethrow;
      }

      throw FirebaseAiServiceException(
        message,
      );
    }
  }

  // ============================================================
  // PHASE 13C — GENERATE AI QUIZ DRAFT
  //
  // Gemini generates a structured multiple-choice quiz from the
  // selected PDF.
  //
  // This method DOES NOT save the assessment yet.
  // Instructor review comes first.
  // ============================================================

  Future<AiQuizDraft> generateQuizDraft({
    required Map<String, dynamic> material,
    required String courseTitle,
    required String moduleTitle,
    required int questionCount,
    required String difficulty,
  }) async {
    // ==========================================================
    // QUESTION COUNT
    // ==========================================================

    if (![5, 10, 15].contains(
      questionCount,
    )) {
      throw FirebaseAiServiceException(
        'Question count must be 5, 10, or 15.',
      );
    }

    // ==========================================================
    // DIFFICULTY
    // ==========================================================

    final String normalizedDifficulty =
        difficulty
            .trim()
            .toLowerCase();

    if (!{
      'easy',
      'medium',
      'hard',
    }.contains(
      normalizedDifficulty,
    )) {
      throw FirebaseAiServiceException(
        'Difficulty must be easy, medium, or hard.',
      );
    }

    // ==========================================================
    // VALIDATE PDF
    // ==========================================================

    final _PdfMaterialInfo info =
        _validatePdfMaterial(
      material,
    );

    // ==========================================================
    // MATERIAL MUST ALREADY BE AI READY
    // ==========================================================

    final String aiStatus =
        (material['aiProcessingStatus'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

    if (aiStatus != 'ready') {
      throw FirebaseAiServiceException(
        'Analyze this PDF first. Its AI status must be READY '
        'before generating a quiz.',
      );
    }

    // ==========================================================
    // DOWNLOAD PDF
    // ==========================================================

    final Uint8List bytes =
        await _downloadPdfBytes(
      info,
    );

    // ==========================================================
    // STRUCTURED OUTPUT SCHEMA
    // ==========================================================

    final Schema quizSchema =
        Schema.object(
      properties: {
        'title':
            Schema.string(),

        'instructions':
            Schema.string(),

        'questions':
            Schema.array(
          items:
              Schema.object(
            properties: {
              'question':
                  Schema.string(),

              'options':
                  Schema.array(
                items:
                    Schema.string(),
              ),

              'correctAnswerIndex':
                  Schema.integer(),

              'explanation':
                  Schema.string(),
            },
          ),
        ),
      },
    );

    // ==========================================================
    // QUIZ-SPECIFIC GEMINI MODEL
    //
    // Structured JSON response.
    // ==========================================================

    final GenerativeModel quizModel =
        FirebaseAI.googleAI()
            .generativeModel(
      model:
          'gemini-3.7-flash',

      generationConfig:
          GenerationConfig(
        responseMimeType:
            'application/json',

        responseSchema:
            quizSchema,
      ),
    );

    // ==========================================================
    // QUIZ PROMPT
    // ==========================================================

    final TextPart prompt =
        TextPart(
      '''
Create a multiple-choice quiz for CASLMS using ONLY the attached PDF.

Course: $courseTitle
Module: $moduleTitle
Source file: ${info.fileName}
Difficulty: $normalizedDifficulty
Number of questions: $questionCount

Requirements:
- Produce exactly $questionCount questions.
- Every question must be answerable from the attached PDF.
- Do not use outside knowledge.
- Each question must have exactly 4 answer options.
- There must be exactly one clearly correct answer.
- correctAnswerIndex must be 0, 1, 2, or 3 and must match the correct option.
- Distractors should be plausible but clearly incorrect based on the PDF.
- Avoid "All of the above" and "None of the above".
- Avoid trick questions and ambiguous wording.
- Keep explanations short and directly tied to the PDF.
- The quiz title should be appropriate for the material.
- Instructions should be one short sentence for students.

Difficulty guidance:
- easy: mostly direct recall and recognition
- medium: comprehension and simple application
- hard: deeper understanding, comparison, or application while remaining fully supported by the PDF
''',
    );

    // ==========================================================
    // ATTACH PDF
    //
    // bytes is Uint8List.
    // ==========================================================

    final InlineDataPart pdfPart =
        InlineDataPart(
      'application/pdf',
      bytes,
    );

    try {
      // ========================================================
      // GENERATE QUIZ
      // ========================================================

      final GenerateContentResponse
          response =
          await quizModel.generateContent(
        [
          Content.multi(
            [
              prompt,
              pdfPart,
            ],
          ),
        ],
      );

      final String rawJson =
          (response.text ?? '')
              .trim();

      if (rawJson.isEmpty) {
        throw FirebaseAiServiceException(
          'Gemini returned an empty quiz.',
        );
      }

      // ========================================================
      // PARSE JSON
      // ========================================================

      final dynamic decoded =
          jsonDecode(
        rawJson,
      );

      if (decoded is! Map) {
        throw FirebaseAiServiceException(
          'Gemini returned an invalid quiz format.',
        );
      }

      final Map<String, dynamic> data =
          Map<String, dynamic>.from(
        decoded,
      );

      // ========================================================
      // QUIZ TITLE
      // ========================================================

      final String title =
          (data['title'] ?? '')
              .toString()
              .trim();

      // ========================================================
      // INSTRUCTIONS
      // ========================================================

      final String instructions =
          (data['instructions'] ?? '')
              .toString()
              .trim();

      final dynamic rawQuestions =
          data['questions'];

      if (title.isEmpty ||
          instructions.isEmpty ||
          rawQuestions is! List) {
        throw FirebaseAiServiceException(
          'Gemini returned incomplete quiz data.',
        );
      }

      // ========================================================
      // VALIDATE QUESTIONS
      // ========================================================

      final List<AiQuizQuestion>
          questions = [];

      for (final dynamic rawQuestion
          in rawQuestions) {
        if (rawQuestion is! Map) {
          continue;
        }

        final Map<String, dynamic>
            questionData =
            Map<String, dynamic>.from(
          rawQuestion,
        );

        final String question =
            (questionData['question'] ?? '')
                .toString()
                .trim();

        final dynamic rawOptions =
            questionData['options'];

        final int? correctIndex =
            (questionData[
                        'correctAnswerIndex']
                    as num?)
                ?.toInt();

        final String explanation =
            (questionData['explanation'] ??
                    '')
                .toString()
                .trim();

        // ------------------------------------------------------
        // VALIDATE QUESTION
        // ------------------------------------------------------

        if (question.isEmpty ||
            rawOptions is! List ||
            rawOptions.length != 4 ||
            correctIndex == null ||
            correctIndex < 0 ||
            correctIndex > 3) {
          continue;
        }

        // ------------------------------------------------------
        // VALIDATE OPTIONS
        // ------------------------------------------------------

        final List<String> options =
            rawOptions
                .map(
                  (dynamic value) =>
                      value
                          .toString()
                          .trim(),
                )
                .toList();

        if (options.any(
          (String value) =>
              value.isEmpty,
        )) {
          continue;
        }

        // ------------------------------------------------------
        // ADD VALID QUESTION
        // ------------------------------------------------------

        questions.add(
          AiQuizQuestion(
            question:
                question,

            options:
                options,

            correctAnswerIndex:
                correctIndex,

            explanation:
                explanation,
          ),
        );
      }

      // ========================================================
      // EXACT QUESTION COUNT REQUIRED
      // ========================================================

      if (questions.length !=
          questionCount) {
        throw FirebaseAiServiceException(
          'Gemini generated ${questions.length} valid questions '
          'instead of $questionCount. Please try again.',
        );
      }

      // ========================================================
      // RETURN QUIZ DRAFT
      // ========================================================

      return AiQuizDraft(
        title:
            title,

        instructions:
            instructions,

        difficulty:
            normalizedDifficulty,

        sourceResourceId:
            info.resourceId,

        sourceFileName:
            info.fileName,

        questions:
            questions,
      );
    } on FirebaseAiServiceException {
      rethrow;
    } catch (e) {
      throw FirebaseAiServiceException(
        'Unable to generate the AI quiz: $e',
      );
    }
  }

  // ============================================================
  // PDF VALIDATION
  // ============================================================

  _PdfMaterialInfo _validatePdfMaterial(
    Map<String, dynamic> material,
  ) {
    // ==========================================================
    // RESOURCE ID
    // ==========================================================

    final String resourceId =
        (material['resourceId'] ??
                material['id'] ??
                '')
            .toString()
            .trim();

    if (resourceId.isEmpty) {
      throw FirebaseAiServiceException(
        'Learning material ID is missing.',
      );
    }

    // ==========================================================
    // DELIVERY TYPE
    // ==========================================================

    final String deliveryType =
        (material['deliveryType'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

    if (deliveryType !=
        'uploaded_file') {
      throw FirebaseAiServiceException(
        'Only uploaded PDF files can currently be used by AI.',
      );
    }

    // ==========================================================
    // AI ELIGIBILITY
    // ==========================================================

    if (material['aiEligible'] != true) {
      throw FirebaseAiServiceException(
        'This learning material is not AI-eligible.',
      );
    }

    // ==========================================================
    // FILE INFORMATION
    // ==========================================================

    final String fileName =
        (material['fileName'] ?? '')
            .toString()
            .trim();

    final String resourceType =
        (material['resourceType'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

    final String mimeType =
        (material['mimeType'] ?? '')
            .toString()
            .trim()
            .toLowerCase();

    // ==========================================================
    // PDF CHECK
    // ==========================================================

    final bool isPdf =
        resourceType == 'pdf' ||
            mimeType ==
                'application/pdf' ||
            fileName
                .toLowerCase()
                .endsWith(
                  '.pdf',
                );

    if (!isPdf) {
      throw FirebaseAiServiceException(
        'This AI feature currently supports PDF learning materials only.',
      );
    }

    // ==========================================================
    // SUPABASE STORAGE PATH
    // ==========================================================

    final String storagePath =
        (material['storagePath'] ?? '')
            .toString()
            .trim();

    if (storagePath.isEmpty) {
      throw FirebaseAiServiceException(
        'The Supabase storage path is missing.',
      );
    }

    // ==========================================================
    // FILE SIZE
    // ==========================================================

    final int declaredSize =
        (material['sizeBytes'] as num?)
                ?.toInt() ??
            0;

    if (declaredSize >
        _maximumPdfBytes) {
      throw FirebaseAiServiceException(
        'This PDF is too large for the current AI limit. '
        'Use a PDF smaller than 14 MB.',
      );
    }

    return _PdfMaterialInfo(
      resourceId:
          resourceId,

      fileName:
          fileName,

      storagePath:
          storagePath,
    );
  }

  // ============================================================
  // DOWNLOAD PDF
  //
  // IMPORTANT:
  // Supabase download returns Uint8List.
  //
  // InlineDataPart also requires Uint8List.
  // ============================================================

  Future<Uint8List> _downloadPdfBytes(
    _PdfMaterialInfo info,
  ) async {
    final Uint8List bytes =
        await _supabase.storage
            .from(
              SupabaseConfig
                  .learningMaterialsBucket,
            )
            .download(
              info.storagePath,
            );

    if (bytes.isEmpty) {
      throw FirebaseAiServiceException(
        'The downloaded PDF is empty.',
      );
    }

    if (bytes.length >
        _maximumPdfBytes) {
      throw FirebaseAiServiceException(
        'This PDF is too large for the current AI limit. '
        'Use a PDF smaller than 14 MB.',
      );
    }

    return bytes;
  }
}

// ============================================================
// MATERIAL ANALYSIS RESULT
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
// AI QUIZ DRAFT
// ============================================================

class AiQuizDraft {
  AiQuizDraft({
    required this.title,
    required this.instructions,
    required this.difficulty,
    required this.sourceResourceId,
    required this.sourceFileName,
    required this.questions,
  });

  final String title;
  final String instructions;
  final String difficulty;
  final String sourceResourceId;
  final String sourceFileName;
  final List<AiQuizQuestion> questions;

  // For now:
  // 1 question = 1 point.
  int get totalPoints =>
      questions.length;
}

// ============================================================
// AI QUIZ QUESTION
// ============================================================

class AiQuizQuestion {
  AiQuizQuestion({
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
    required this.explanation,
  });

  final String question;
  final List<String> options;
  final int correctAnswerIndex;
  final String explanation;
}

// ============================================================
// INTERNAL PDF INFORMATION
// ============================================================

class _PdfMaterialInfo {
  _PdfMaterialInfo({
    required this.resourceId,
    required this.fileName,
    required this.storagePath,
  });

  final String resourceId;
  final String fileName;
  final String storagePath;
}

// ============================================================
// CUSTOM EXCEPTION
// ============================================================

class FirebaseAiServiceException
    implements Exception {
  FirebaseAiServiceException(
    this.message,
  );

  final String message;

  @override
  String toString() =>
      message;
}