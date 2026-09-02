import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:flutter/foundation.dart';
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
  // CURRENT CASLMS AI LIMITS
  // ============================================================

  // Firebase AI Logic inline multimodal requests have a total
  // request-size limit. Keep native media below this conservative
  // raw-file limit because base64 encoding increases the request.
  static const int _maximumInlineFileBytes =
      14 * 1024 * 1024;

  // Firebase documents a lower per-file base64 image limit.
  static const int _maximumImageBytes =
      5 * 1024 * 1024;

  // Modern Office files are ZIP containers. They are not sent
  // directly to Gemini. CASLMS extracts readable text locally.
  static const int _maximumOfficeArchiveBytes =
      25 * 1024 * 1024;

  // Limit extracted text so one huge Office document does not
  // consume an excessive number of tokens or time out.
  static const int _maximumExtractedCharacters =
      120000;

  static const int _maximumAiAttempts = 3;

  // Shared by all FirebaseAiService instances in the app.
  // When Gemini tells us to wait because of quota, CASLMS avoids
  // sending another request until the cooldown has passed.
  static DateTime? _quotaBlockedUntil;

  // When Gemini explicitly reports a per-day free-tier quota,
  // stop sending more AI requests for the rest of this app session.
  // Restarting the app clears this local flag, but Gemini itself
  // will only accept requests again after its daily quota resets.
  static bool _dailyQuotaExhaustedForSession = false;

  // ============================================================
  // AI-SUPPORTED MATERIAL TYPES IN THIS CLIENT ARCHITECTURE
  // ============================================================
  //
  // Direct Firebase AI Logic input:
  // - PDF
  // - plain text
  // - JPG/JPEG/PNG/WEBP
  // - MP4/WEBM
  //
  // Local text extraction before Gemini:
  // - DOCX
  // - PPTX
  // - XLSX
  //
  // Legacy binary Office files (.doc/.ppt/.xls) are intentionally
  // not included because Firebase AI Logic does not accept those
  // document MIME types directly and reliable conversion would
  // require a backend/native office converter.
  // ============================================================

  static const Set<String> supportedAiExtensions = {
    'pdf',
    'txt',
    'docx',
    'pptx',
    'xlsx',
    'jpg',
    'jpeg',
    'png',
    'webp',
    'mp4',
    'webm',
  };

  // ============================================================
  // CONNECTION TEST
  // ============================================================

  Future<String> testConnection() async {
    try {
      final GenerateContentResponse response =
          await _generateContentWithRetry(
        model: _model,
        contents: [
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
        'Unable to connect to Gemini right now. Please try again.',
      );
    }
  }

  // ============================================================
  // ANALYZE ANY SUPPORTED LEARNING MATERIAL
  // ============================================================

  Future<AiMaterialAnalysisResult>
      analyzeMaterial({
    required Map<String, dynamic> material,
    required String courseTitle,
    required String moduleTitle,
  }) async {
    final _AiMaterialInfo info =
        _validateAiMaterial(
      material,
    );

    final DocumentReference<
        Map<String, dynamic>>
        resourceReference =
        _firestore
            .collection('moduleResources')
            .doc(info.resourceId);

    await resourceReference.update({
      'aiProcessingStatus':
          'processing',
      'aiError':
          null,
      'updatedAt':
          FieldValue.serverTimestamp(),
    });

    try {
      final _PreparedAiInput prepared =
          await _prepareAiInput(
        info,
      );

      final TextPart prompt =
          TextPart(
        '''
You are analyzing a learning material for CASLMS.

Use ONLY the attached or extracted learning material as your source.
Do not add facts that are not supported by the material.
If information is missing, say that it is not provided.

Course: $courseTitle
Module: $moduleTitle
File: ${info.fileName}
Material type: ${info.extension.toUpperCase()}

Return a concise analysis using exactly these sections:

MATERIAL UNDERSTOOD

MAIN TOPICS
- List the most important topics covered by the material.

BRIEF SUMMARY
Write a clear summary of the material in 1 to 3 short paragraphs.

KEY TERMS
- List important terms or concepts found in the material.

POSSIBLE LEARNING OBJECTIVES
- List learning objectives that are directly supported by the material.
''',
      );

      final GenerateContentResponse
          response =
          await _generateContentWithRetry(
        model: _model,
        contents: [
          _buildContent(
            prepared,
            prompt,
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

      await resourceReference.update({
        'aiProcessingStatus':
            'ready',
        'aiAnalysisSummary':
            analysis,
        'aiModel':
            'gemini-3.7-flash',
        'aiSourceBytes':
            prepared.sourceBytes,
        'aiInputMode':
            prepared.inputMode,
        'aiTextExtracted':
            prepared.textExtracted,
        'aiTextLength':
            prepared.textLength,
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
            prepared.sourceBytes,
      );
    } catch (e) {
      final FirebaseAiServiceException error =
          e is FirebaseAiServiceException
              ? e
              : FirebaseAiServiceException(
                  'Unable to analyze this learning material with Gemini. '
                  'Please check your connection and try again.',
                );

      try {
        await resourceReference.update({
          // Quota cooldowns and temporary Gemini outages do not
          // mean the uploaded file itself is invalid.
          'aiProcessingStatus':
              error.isTemporary
                  ? 'pending'
                  : 'failed',
          'aiError':
              error.message,
          'aiProcessedAt':
              FieldValue.serverTimestamp(),
          'updatedAt':
              FieldValue.serverTimestamp(),
        });
      } catch (_) {}

      throw error;
    }
  }

  // ============================================================
  // BACKWARD-COMPATIBLE PDF METHOD
  //
  // Existing screens that still call analyzePdfMaterial() will
  // continue working while the UI is migrated to analyzeMaterial().
  // ============================================================

  Future<AiMaterialAnalysisResult>
      analyzePdfMaterial({
    required Map<String, dynamic> material,
    required String courseTitle,
    required String moduleTitle,
  }) {
    return analyzeMaterial(
      material: material,
      courseTitle: courseTitle,
      moduleTitle: moduleTitle,
    );
  }

  // ============================================================
  // GENERATE AI QUIZ DRAFT FROM ANY AI-READY MATERIAL
  // ============================================================

  Future<AiQuizDraft> generateQuizDraft({
    required Map<String, dynamic> material,
    required String courseTitle,
    required String moduleTitle,
    required int questionCount,
    required String difficulty,
  }) async {
    if (![5, 10, 15].contains(
      questionCount,
    )) {
      throw FirebaseAiServiceException(
        'Question count must be 5, 10, or 15.',
      );
    }

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

    final _AiMaterialInfo info =
        _validateAiMaterial(
      material,
    );

    final String aiStatus =
        (material['aiProcessingStatus'] ??
                '')
            .toString()
            .trim()
            .toLowerCase();

    if (aiStatus != 'ready' &&
        aiStatus != 'completed') {
      throw FirebaseAiServiceException(
        'Analyze this learning material first. '
        'Its AI status must be READY before generating a quiz.',
      );
    }

    final _PreparedAiInput prepared =
        await _prepareAiInput(
      info,
    );

    // Firebase AI Logic structured output schema.
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

    final TextPart prompt =
        TextPart(
      '''
Create a multiple-choice quiz for CASLMS using ONLY the provided learning material.

Course: $courseTitle
Module: $moduleTitle
Source file: ${info.fileName}
Source type: ${info.extension.toUpperCase()}
Difficulty: $normalizedDifficulty
Number of questions: $questionCount

Requirements:
- Produce exactly $questionCount questions.
- Every question must be answerable from the provided material.
- Do not use outside knowledge.
- Each question must have exactly 4 answer options.
- There must be exactly one clearly correct answer.
- correctAnswerIndex must be 0, 1, 2, or 3 and must match the correct option.
- Distractors should be plausible but clearly incorrect based on the material.
- Avoid "All of the above" and "None of the above".
- Avoid trick questions and ambiguous wording.
- Keep explanations short and directly tied to the material.
- The quiz title should be appropriate for the material.
- Instructions should be one short sentence for students.

Difficulty guidance:
- easy: mostly direct recall and recognition
- medium: comprehension and simple application
- hard: deeper understanding, comparison, or application while remaining fully supported by the material
''',
    );

    try {
      final GenerateContentResponse
          response =
          await _generateContentWithRetry(
        model: quizModel,
        contents: [
          _buildContent(
            prepared,
            prompt,
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

      final String title =
          (data['title'] ?? '')
              .toString()
              .trim();

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
            (questionData['question'] ??
                    '')
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
            (questionData[
                        'explanation'] ??
                    '')
                .toString()
                .trim();

        if (question.isEmpty ||
            rawOptions is! List ||
            rawOptions.length != 4 ||
            correctIndex == null ||
            correctIndex < 0 ||
            correctIndex > 3) {
          continue;
        }

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

      if (questions.length !=
          questionCount) {
        throw FirebaseAiServiceException(
          'Gemini generated ${questions.length} valid questions '
          'instead of $questionCount. Please try again.',
        );
      }

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
    } catch (_) {
      throw FirebaseAiServiceException(
        'Unable to generate the AI quiz right now. '
        'Please try again.',
      );
    }
  }

  // ============================================================
  // BUILD GEMINI CONTENT
  // ============================================================

  Content _buildContent(
    _PreparedAiInput prepared,
    TextPart prompt,
  ) {
    final InlineDataPart? inlinePart =
        prepared.inlinePart;

    if (inlinePart != null) {
      // Firebase recommends placing a single media/document file
      // before the text prompt.
      return Content.multi(
        [
          inlinePart,
          prompt,
        ],
      );
    }

    final String text =
        prepared.extractedText ??
            '';

    return Content.multi(
      [
        prompt,
        TextPart(
          'EXTRACTED LEARNING MATERIAL CONTENT:\n\n$text',
        ),
      ],
    );
  }

  // ============================================================
  // PREPARE INPUT BY FILE TYPE
  // ============================================================

  Future<_PreparedAiInput>
      _prepareAiInput(
    _AiMaterialInfo info,
  ) async {
    final Uint8List bytes =
        await _downloadMaterialBytes(
      info,
    );

    switch (info.extension) {
      // --------------------------------------------------------
      // PDF — Gemini reads the actual document.
      // --------------------------------------------------------
      case 'pdf':
        _requireInlineSize(
          bytes,
          label: 'PDF',
        );

        return _PreparedAiInput(
          sourceBytes:
              bytes.length,
          inlinePart:
              InlineDataPart(
            'application/pdf',
            bytes,
          ),
          inputMode:
              'native_pdf',
          textExtracted:
              false,
          textLength:
              0,
        );

      // --------------------------------------------------------
      // PLAIN TEXT
      // --------------------------------------------------------
      case 'txt':
        final String text =
            _normalizeExtractedText(
          utf8.decode(
            bytes,
            allowMalformed: true,
          ),
        );

        _requireExtractedText(
          text,
          info.fileName,
        );

        return _PreparedAiInput(
          sourceBytes:
              bytes.length,
          extractedText:
              text,
          inputMode:
              'extracted_text',
          textExtracted:
              true,
          textLength:
              text.length,
        );

      // --------------------------------------------------------
      // WORD DOCX — extract OOXML text locally.
      // --------------------------------------------------------
      case 'docx':
        _requireOfficeArchiveSize(
          bytes,
          'Word document',
        );

        final String text =
            _extractDocxText(
          bytes,
        );

        _requireExtractedText(
          text,
          info.fileName,
        );

        return _PreparedAiInput(
          sourceBytes:
              bytes.length,
          extractedText:
              text,
          inputMode:
              'docx_text_extraction',
          textExtracted:
              true,
          textLength:
              text.length,
        );

      // --------------------------------------------------------
      // POWERPOINT PPTX — extract slide text locally.
      // --------------------------------------------------------
      case 'pptx':
        _requireOfficeArchiveSize(
          bytes,
          'PowerPoint presentation',
        );

        final String text =
            _extractPptxText(
          bytes,
        );

        _requireExtractedText(
          text,
          info.fileName,
        );

        return _PreparedAiInput(
          sourceBytes:
              bytes.length,
          extractedText:
              text,
          inputMode:
              'pptx_text_extraction',
          textExtracted:
              true,
          textLength:
              text.length,
        );

      // --------------------------------------------------------
      // EXCEL XLSX — extract cell values locally.
      // --------------------------------------------------------
      case 'xlsx':
        _requireOfficeArchiveSize(
          bytes,
          'Excel workbook',
        );

        final String text =
            _extractXlsxText(
          bytes,
        );

        _requireExtractedText(
          text,
          info.fileName,
        );

        return _PreparedAiInput(
          sourceBytes:
              bytes.length,
          extractedText:
              text,
          inputMode:
              'xlsx_text_extraction',
          textExtracted:
              true,
          textLength:
              text.length,
        );

      // --------------------------------------------------------
      // IMAGES — Gemini reads the actual image.
      // --------------------------------------------------------
      case 'jpg':
      case 'jpeg':
        _requireImageSize(
          bytes,
        );

        return _PreparedAiInput(
          sourceBytes:
              bytes.length,
          inlinePart:
              InlineDataPart(
            'image/jpeg',
            bytes,
          ),
          inputMode:
              'native_image',
          textExtracted:
              false,
          textLength:
              0,
        );

      case 'png':
        _requireImageSize(
          bytes,
        );

        return _PreparedAiInput(
          sourceBytes:
              bytes.length,
          inlinePart:
              InlineDataPart(
            'image/png',
            bytes,
          ),
          inputMode:
              'native_image',
          textExtracted:
              false,
          textLength:
              0,
        );

      case 'webp':
        _requireImageSize(
          bytes,
        );

        return _PreparedAiInput(
          sourceBytes:
              bytes.length,
          inlinePart:
              InlineDataPart(
            'image/webp',
            bytes,
          ),
          inputMode:
              'native_image',
          textExtracted:
              false,
          textLength:
              0,
        );

      // --------------------------------------------------------
      // VIDEO — Gemini reads the actual video.
      // --------------------------------------------------------
      case 'mp4':
        _requireInlineSize(
          bytes,
          label: 'video',
        );

        return _PreparedAiInput(
          sourceBytes:
              bytes.length,
          inlinePart:
              InlineDataPart(
            'video/mp4',
            bytes,
          ),
          inputMode:
              'native_video',
          textExtracted:
              false,
          textLength:
              0,
        );

      case 'webm':
        _requireInlineSize(
          bytes,
          label: 'video',
        );

        return _PreparedAiInput(
          sourceBytes:
              bytes.length,
          inlinePart:
              InlineDataPart(
            'video/webm',
            bytes,
          ),
          inputMode:
              'native_video',
          textExtracted:
              false,
          textLength:
              0,
        );

      default:
        throw FirebaseAiServiceException(
          _unsupportedAiMessage(
            info.extension,
          ),
        );
    }
  }

  // ============================================================
  // VALIDATE AI MATERIAL
  // ============================================================

  _AiMaterialInfo _validateAiMaterial(
    Map<String, dynamic> material,
  ) {
    final String resourceId =
        (material['resourceId'] ??
                material['materialId'] ??
                material['id'] ??
                '')
            .toString()
            .trim();

    if (resourceId.isEmpty) {
      throw FirebaseAiServiceException(
        'Learning material ID is missing.',
      );
    }

    final String deliveryType =
        (material['deliveryType'] ??
                '')
            .toString()
            .trim()
            .toLowerCase();

    if (deliveryType !=
        'uploaded_file') {
      throw FirebaseAiServiceException(
        'AI analysis currently supports uploaded learning materials only.',
      );
    }

    final String fileName =
        (material['fileName'] ?? '')
            .toString()
            .trim();

    if (fileName.isEmpty) {
      throw FirebaseAiServiceException(
        'The uploaded file name is missing.',
      );
    }

    final String extension =
        _extensionFromFileName(
      fileName,
    );

    if (!supportedAiExtensions.contains(
      extension,
    )) {
      throw FirebaseAiServiceException(
        _unsupportedAiMessage(
          extension,
        ),
      );
    }

    final String storagePath =
        (material['storagePath'] ?? '')
            .toString()
            .trim();

    if (storagePath.isEmpty) {
      throw FirebaseAiServiceException(
        'The Supabase storage path is missing.',
      );
    }

    return _AiMaterialInfo(
      resourceId:
          resourceId,
      fileName:
          fileName,
      storagePath:
          storagePath,
      extension:
          extension,
    );
  }

  String _unsupportedAiMessage(
    String extension,
  ) {
    if ({
      'doc',
      'ppt',
      'xls',
    }.contains(
      extension,
    )) {
      return 'Legacy .$extension files can be uploaded, but this '
          'direct Flutter AI setup cannot reliably read them. '
          'Save the file as ${extension == 'doc' ? '.docx' : extension == 'ppt' ? '.pptx' : '.xlsx'} '
          'or export it as PDF, then analyze it again.';
    }

    if (extension == 'gif') {
      return 'GIF files can be uploaded, but Gemini analysis in this '
          'CASLMS setup supports JPG, PNG, or WEBP images. '
          'Convert the GIF to a supported image format first.';
    }

    return 'This file type is not supported by CASLMS AI analysis yet.';
  }

  String _extensionFromFileName(
    String fileName,
  ) {
    final String clean =
        fileName.trim();

    if (!clean.contains('.')) {
      return '';
    }

    return clean
        .split('.')
        .last
        .trim()
        .toLowerCase();
  }

  // ============================================================
  // DOWNLOAD FROM SUPABASE
  // ============================================================

  Future<Uint8List>
      _downloadMaterialBytes(
    _AiMaterialInfo info,
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
        'The downloaded learning material is empty.',
      );
    }

    return bytes;
  }

  // ============================================================
  // SIZE CHECKS
  // ============================================================

  void _requireInlineSize(
    Uint8List bytes, {
    required String label,
  }) {
    if (bytes.length >
        _maximumInlineFileBytes) {
      throw FirebaseAiServiceException(
        'This $label is too large for the current inline AI request. '
        'Use a file smaller than 14 MB or split it into smaller parts.',
      );
    }
  }

  void _requireImageSize(
    Uint8List bytes,
  ) {
    if (bytes.length >
        _maximumImageBytes) {
      throw FirebaseAiServiceException(
        'This image is too large for the current AI request. '
        'Use an image smaller than 5 MB.',
      );
    }
  }

  void _requireOfficeArchiveSize(
    Uint8List bytes,
    String label,
  ) {
    if (bytes.length >
        _maximumOfficeArchiveBytes) {
      throw FirebaseAiServiceException(
        'This $label is too large for local AI text extraction. '
        'Use a file smaller than 25 MB or export it as a smaller PDF.',
      );
    }
  }

  void _requireExtractedText(
    String text,
    String fileName,
  ) {
    if (text.trim().isEmpty) {
      throw FirebaseAiServiceException(
        'CASLMS could not extract readable text from "$fileName". '
        'Try exporting the material as a text-based PDF.',
      );
    }
  }

  // ============================================================
  // DOCX TEXT EXTRACTION
  // ============================================================

  String _extractDocxText(
    Uint8List bytes,
  ) {
    final Archive archive =
        _decodeOfficeArchive(
      bytes,
      'Word document',
    );

    final List<ArchiveFile> files =
        archive
            .where(
              (ArchiveFile file) =>
                  file.isFile &&
                  (
                    file.name ==
                        'word/document.xml' ||
                    RegExp(
                      r'^word/(header|footer)\d+\.xml$',
                    ).hasMatch(
                      file.name,
                    )
                  ),
            )
            .toList();

    files.sort(
      (
        ArchiveFile a,
        ArchiveFile b,
      ) {
        if (a.name ==
            'word/document.xml') {
          return -1;
        }

        if (b.name ==
            'word/document.xml') {
          return 1;
        }

        return a.name.compareTo(
          b.name,
        );
      },
    );

    final StringBuffer buffer =
        StringBuffer();

    for (final ArchiveFile file
        in files) {
      final Uint8List? content =
          file.readBytes();

      if (content == null ||
          content.isEmpty) {
        continue;
      }

      final String xml =
          utf8.decode(
        content,
        allowMalformed: true,
      );

      final String text =
          _xmlToReadableText(
        xml,
        paragraphClosingTags: const [
          '</w:p>',
          '</w:tr>',
        ],
        tabClosingTags: const [
          '</w:tc>',
        ],
      );

      if (text.isNotEmpty) {
        buffer
          ..writeln(text)
          ..writeln();
      }
    }

    return _normalizeExtractedText(
      buffer.toString(),
    );
  }

  // ============================================================
  // PPTX TEXT EXTRACTION
  // ============================================================

  String _extractPptxText(
    Uint8List bytes,
  ) {
    final Archive archive =
        _decodeOfficeArchive(
      bytes,
      'PowerPoint presentation',
    );

    final RegExp slidePattern =
        RegExp(
      r'^ppt/slides/slide(\d+)\.xml$',
    );

    final List<ArchiveFile> slides =
        archive
            .where(
              (ArchiveFile file) =>
                  file.isFile &&
                  slidePattern.hasMatch(
                    file.name,
                  ),
            )
            .toList();

    slides.sort(
      (
        ArchiveFile a,
        ArchiveFile b,
      ) {
        final int aNumber =
            int.tryParse(
                  slidePattern
                          .firstMatch(
                            a.name,
                          )
                          ?.group(
                            1,
                          ) ??
                      '',
                ) ??
                0;

        final int bNumber =
            int.tryParse(
                  slidePattern
                          .firstMatch(
                            b.name,
                          )
                          ?.group(
                            1,
                          ) ??
                      '',
                ) ??
                0;

        return aNumber.compareTo(
          bNumber,
        );
      },
    );

    final StringBuffer buffer =
        StringBuffer();

    for (int index = 0;
        index < slides.length;
        index++) {
      final Uint8List? content =
          slides[index].readBytes();

      if (content == null ||
          content.isEmpty) {
        continue;
      }

      final String xml =
          utf8.decode(
        content,
        allowMalformed: true,
      );

      final String text =
          _xmlToReadableText(
        xml,
        paragraphClosingTags: const [
          '</a:p>',
        ],
        tabClosingTags: const [],
      );

      if (text.isNotEmpty) {
        buffer
          ..writeln(
            '--- Slide ${index + 1} ---',
          )
          ..writeln(text)
          ..writeln();
      }
    }

    return _normalizeExtractedText(
      buffer.toString(),
    );
  }

  // ============================================================
  // XLSX TEXT EXTRACTION
  // ============================================================

  String _extractXlsxText(
    Uint8List bytes,
  ) {
    final Archive archive =
        _decodeOfficeArchive(
      bytes,
      'Excel workbook',
    );

    final List<String> sharedStrings =
        _readXlsxSharedStrings(
      archive,
    );

    final RegExp sheetPattern =
        RegExp(
      r'^xl/worksheets/sheet(\d+)\.xml$',
    );

    final List<ArchiveFile> sheets =
        archive
            .where(
              (ArchiveFile file) =>
                  file.isFile &&
                  sheetPattern.hasMatch(
                    file.name,
                  ),
            )
            .toList();

    sheets.sort(
      (
        ArchiveFile a,
        ArchiveFile b,
      ) {
        final int aNumber =
            int.tryParse(
                  sheetPattern
                          .firstMatch(
                            a.name,
                          )
                          ?.group(
                            1,
                          ) ??
                      '',
                ) ??
                0;

        final int bNumber =
            int.tryParse(
                  sheetPattern
                          .firstMatch(
                            b.name,
                          )
                          ?.group(
                            1,
                          ) ??
                      '',
                ) ??
                0;

        return aNumber.compareTo(
          bNumber,
        );
      },
    );

    final StringBuffer output =
        StringBuffer();

    final RegExp cellPattern =
        RegExp(
      r'<c\b([^>]*)>([\s\S]*?)</c>',
      caseSensitive: false,
    );

    final RegExp valuePattern =
        RegExp(
      r'<v[^>]*>([\s\S]*?)</v>',
      caseSensitive: false,
    );

    final RegExp inlineTextPattern =
        RegExp(
      r'<t[^>]*>([\s\S]*?)</t>',
      caseSensitive: false,
    );

    final RegExp referencePattern =
        RegExp(
      r'\br="([^"]+)"',
      caseSensitive: false,
    );

    final RegExp typePattern =
        RegExp(
      r'\bt="([^"]+)"',
      caseSensitive: false,
    );

    for (int sheetIndex = 0;
        sheetIndex < sheets.length;
        sheetIndex++) {
      final Uint8List? content =
          sheets[sheetIndex].readBytes();

      if (content == null ||
          content.isEmpty) {
        continue;
      }

      final String xml =
          utf8.decode(
        content,
        allowMalformed: true,
      );

      output.writeln(
        '--- Worksheet ${sheetIndex + 1} ---',
      );

      for (final RegExpMatch cell
          in cellPattern.allMatches(
        xml,
      )) {
        final String attributes =
            cell.group(1) ?? '';

        final String body =
            cell.group(2) ?? '';

        final String reference =
            referencePattern
                    .firstMatch(
                      attributes,
                    )
                    ?.group(
                      1,
                    ) ??
                '';

        final String type =
            typePattern
                    .firstMatch(
                      attributes,
                    )
                    ?.group(
                      1,
                    )
                    ?.toLowerCase() ??
                '';

        String value = '';

        if (type == 's') {
          final String rawIndex =
              valuePattern
                      .firstMatch(
                        body,
                      )
                      ?.group(
                        1,
                      ) ??
                  '';

          final int? sharedIndex =
              int.tryParse(
            rawIndex.trim(),
          );

          if (sharedIndex != null &&
              sharedIndex >= 0 &&
              sharedIndex <
                  sharedStrings.length) {
            value =
                sharedStrings[
                    sharedIndex];
          }
        } else if (type ==
            'inlinestr') {
          final Iterable<RegExpMatch>
              matches =
              inlineTextPattern
                  .allMatches(
            body,
          );

          value =
              matches
                  .map(
                    (RegExpMatch match) =>
                        _decodeXmlEntities(
                      match.group(1) ??
                          '',
                    ),
                  )
                  .join(
                    ' ',
                  );
        } else {
          value =
              _decodeXmlEntities(
            valuePattern
                    .firstMatch(
                      body,
                    )
                    ?.group(
                      1,
                    ) ??
                '',
          );
        }

        value =
            value.trim();

        if (value.isEmpty) {
          continue;
        }

        if (reference.isNotEmpty) {
          output.write(
            '$reference: ',
          );
        }

        output.writeln(
          value,
        );
      }

      output.writeln();
    }

    return _normalizeExtractedText(
      output.toString(),
    );
  }

  List<String> _readXlsxSharedStrings(
    Archive archive,
  ) {
    ArchiveFile? sharedFile;

    for (final ArchiveFile file
        in archive) {
      if (file.isFile &&
          file.name ==
              'xl/sharedStrings.xml') {
        sharedFile =
            file;
        break;
      }
    }

    if (sharedFile == null) {
      return const [];
    }

    final Uint8List? content =
        sharedFile.readBytes();

    if (content == null ||
        content.isEmpty) {
      return const [];
    }

    final String xml =
        utf8.decode(
      content,
      allowMalformed: true,
    );

    final RegExp itemPattern =
        RegExp(
      r'<si[^>]*>([\s\S]*?)</si>',
      caseSensitive: false,
    );

    final RegExp textPattern =
        RegExp(
      r'<t[^>]*>([\s\S]*?)</t>',
      caseSensitive: false,
    );

    return itemPattern
        .allMatches(
          xml,
        )
        .map(
          (RegExpMatch item) {
            final String body =
                item.group(1) ??
                    '';

            return textPattern
                .allMatches(
                  body,
                )
                .map(
                  (RegExpMatch match) =>
                      _decodeXmlEntities(
                    match.group(1) ??
                        '',
                  ),
                )
                .join(
                  ' ',
                )
                .trim();
          },
        )
        .toList();
  }

  // ============================================================
  // OFFICE ARCHIVE HELPERS
  // ============================================================

  Archive _decodeOfficeArchive(
    Uint8List bytes,
    String label,
  ) {
    try {
      final Archive archive =
          ZipDecoder().decodeBytes(
        bytes,
      );

      // Basic protection against unexpectedly huge decompressed
      // Office archives.
      int totalUncompressedBytes = 0;
      int fileCount = 0;

      for (final ArchiveFile file
          in archive) {
        if (!file.isFile) {
          continue;
        }

        fileCount++;
        totalUncompressedBytes +=
            file.size;

        if (fileCount > 3000 ||
            totalUncompressedBytes >
                80 * 1024 * 1024) {
          throw FirebaseAiServiceException(
            'This $label expands to too much data for safe '
            'on-device AI processing. Export it as a smaller PDF.',
          );
        }
      }

      return archive;
    } on FirebaseAiServiceException {
      rethrow;
    } catch (_) {
      throw FirebaseAiServiceException(
        'CASLMS could not read this $label. '
        'The file may be damaged or password-protected. '
        'Try saving a new copy or exporting it as PDF.',
      );
    }
  }

  String _xmlToReadableText(
    String xml, {
    required List<String>
        paragraphClosingTags,
    required List<String>
        tabClosingTags,
  }) {
    String value =
        xml;

    for (final String tag
        in paragraphClosingTags) {
      value =
          value.replaceAll(
        tag,
        '\n',
      );
    }

    for (final String tag
        in tabClosingTags) {
      value =
          value.replaceAll(
        tag,
        '\t',
      );
    }

    value =
        value.replaceAll(
      RegExp(
        r'<(?:w:br|a:br)\b[^>]*/>',
        caseSensitive: false,
      ),
      '\n',
    );

    value =
        value.replaceAll(
      RegExp(
        r'<[^>]+>',
        multiLine: true,
      ),
      '',
    );

    value =
        _decodeXmlEntities(
      value,
    );

    return _normalizeExtractedText(
      value,
    );
  }

  String _decodeXmlEntities(
    String value,
  ) {
    String result =
        value
            .replaceAll(
              '&lt;',
              '<',
            )
            .replaceAll(
              '&gt;',
              '>',
            )
            .replaceAll(
              '&quot;',
              '"',
            )
            .replaceAll(
              '&apos;',
              "'",
            )
            .replaceAll(
              '&amp;',
              '&',
            );

    result =
        result.replaceAllMapped(
      RegExp(
        r'&#x([0-9a-fA-F]+);',
      ),
      (
        Match match,
      ) {
        final int? codePoint =
            int.tryParse(
          match.group(1) ?? '',
          radix: 16,
        );

        if (codePoint == null ||
            codePoint < 0 ||
            codePoint > 0x10FFFF) {
          return '';
        }

        return String.fromCharCode(
          codePoint,
        );
      },
    );

    result =
        result.replaceAllMapped(
      RegExp(
        r'&#(\d+);',
      ),
      (
        Match match,
      ) {
        final int? codePoint =
            int.tryParse(
          match.group(1) ?? '',
        );

        if (codePoint == null ||
            codePoint < 0 ||
            codePoint > 0x10FFFF) {
          return '';
        }

        return String.fromCharCode(
          codePoint,
        );
      },
    );

    return result;
  }

  String _normalizeExtractedText(
    String value,
  ) {
    String text =
        value
            .replaceAll(
              '\r\n',
              '\n',
            )
            .replaceAll(
              '\r',
              '\n',
            );

    text =
        text.replaceAll(
      RegExp(
        r'[ \t]+',
      ),
      ' ',
    );

    text =
        text.replaceAll(
      RegExp(
        r'\n[ \t]+',
      ),
      '\n',
    );

    text =
        text.replaceAll(
      RegExp(
        r'\n{3,}',
      ),
      '\n\n',
    );

    text =
        text.trim();

    if (text.length >
        _maximumExtractedCharacters) {
      text =
          '${text.substring(0, _maximumExtractedCharacters)}'
          '\n\n[CASLMS truncated additional extracted content '
          'to keep the AI request reliable.]';
    }

    return text;
  }

  // ============================================================
  // GEMINI RETRY + FRIENDLY ERROR HANDLING
  // ============================================================

  Future<GenerateContentResponse>
      _generateContentWithRetry({
    required GenerativeModel model,
    required List<Content> contents,
  }) async {
    _throwIfQuotaCooldownActive();

    for (int attempt = 1;
        attempt <= _maximumAiAttempts;
        attempt++) {
      try {
        final GenerateContentResponse response =
            await model.generateContent(
          contents,
        );

        // A successful response proves any previous local cooldown
        // is no longer relevant.
        _quotaBlockedUntil = null;
        _dailyQuotaExhaustedForSession = false;

        return response;
      } catch (e, stackTrace) {
        if (e is FirebaseAiServiceException) {
          rethrow;
        }

        final String rawError =
            e.toString();

        // --------------------------------------------------------
        // DEBUG: SHOW THE REAL FIREBASE AI / GEMINI ERROR
        //
        // This only prints in debug builds. It helps us see the
        // original FirebaseAIException instead of only the short
        // user-friendly snackbar message.
        //
        // Do not expose this raw error directly to students/users.
        // --------------------------------------------------------

        if (kDebugMode) {
          debugPrint(
            '============================================',
          );

          debugPrint(
            'CASLMS GEMINI RAW ERROR',
          );

          debugPrint(
            rawError,
          );

          debugPrint(
            '============================================',
          );

          debugPrintStack(
            stackTrace: stackTrace,
          );
        }

        // --------------------------------------------------------
        // QUOTA / RATE LIMIT
        // --------------------------------------------------------

        if (_isQuotaError(
          rawError,
        )) {
          // ------------------------------------------------------
          // DAILY FREE-TIER QUOTA
          //
          // Gemini can return a RetryInfo delay of only a few
          // seconds even when one of the violated quota IDs is:
          //
          // GenerateRequestsPerDayPerProjectPerModel-FreeTier
          //
          // In that situation, showing "wait 4 seconds" is
          // misleading. Detect the daily quota ID directly.
          // ------------------------------------------------------

          if (_isDailyQuotaError(
            rawError,
          )) {
            _dailyQuotaExhaustedForSession = true;
            _quotaBlockedUntil = null;

            throw FirebaseAiServiceException(
              'Daily AI limit reached.\n\n'
              'The Gemini free-tier request quota for today has been used. '
              'Please try again after the daily quota resets.',
              isTemporary: true,
            );
          }

          // ------------------------------------------------------
          // SHORT-TERM RATE LIMIT
          // ------------------------------------------------------

          final int seconds =
              (_extractRetryAfterSeconds(
                        rawError,
                      ) ??
                      60)
                  .clamp(
                    1,
                    3600,
                  )
                  .toInt();

          _quotaBlockedUntil =
              DateTime.now().add(
            Duration(
              seconds: seconds,
            ),
          );

          throw FirebaseAiServiceException(
            'AI request limit reached. '
            'Please wait about $seconds seconds and try again.',
            isTemporary: true,
            retryAfterSeconds:
                seconds,
          );
        }

        // --------------------------------------------------------
        // TEMPORARY 503 / UNAVAILABLE / DEADLINE
        // --------------------------------------------------------

        if (_isTemporaryServiceError(
          rawError,
        )) {
          if (attempt <
              _maximumAiAttempts) {
            final int waitSeconds =
                attempt == 1
                    ? 2
                    : 4;

            await Future<void>.delayed(
              Duration(
                seconds: waitSeconds,
              ),
            );

            continue;
          }

          throw FirebaseAiServiceException(
            'Gemini is temporarily busy and could not finish processing '
            'the material after several attempts. Please try again later.',
            isTemporary: true,
          );
        }

        final String lower =
            rawError.toLowerCase();

        if (lower.contains('413') ||
            lower.contains(
              'request entity too large',
            ) ||
            lower.contains(
              'payload too large',
            )) {
          throw FirebaseAiServiceException(
            'This learning material is too large for the current AI request. '
            'Use a smaller file or split it into parts.',
          );
        }

        if (lower.contains('app check') ||
            lower.contains(
              'permission-denied',
            ) ||
            lower.contains(
              'permission denied',
            ) ||
            lower.contains('403')) {
          throw FirebaseAiServiceException(
            'CASLMS AI authorization was rejected. '
            'Please restart the app and try again.',
          );
        }

        // --------------------------------------------------------
        // UNKNOWN GEMINI ERROR
        //
        // During development, expose the original Firebase AI error
        // on screen so the real cause can be diagnosed. Release builds
        // still show a safe user-friendly message.
        // --------------------------------------------------------

        if (kDebugMode) {
          throw FirebaseAiServiceException(
            'DEBUG GEMINI ERROR:\n\n$rawError',
          );
        }

        throw FirebaseAiServiceException(
          'Gemini could not complete this request. '
          'Please try again later.',
        );
      }
    }

    throw FirebaseAiServiceException(
      'Gemini could not complete this request. Please try again.',
      isTemporary: true,
    );
  }

  void _throwIfQuotaCooldownActive() {
    if (_dailyQuotaExhaustedForSession) {
      throw FirebaseAiServiceException(
        'Daily AI limit reached.\n\n'
        'The Gemini free-tier request quota for today has been used. '
        'Please try again after the daily quota resets.',
        isTemporary: true,
      );
    }

    final DateTime? blockedUntil =
        _quotaBlockedUntil;

    if (blockedUntil == null) {
      return;
    }

    final DateTime now =
        DateTime.now();

    if (!now.isBefore(
      blockedUntil,
    )) {
      _quotaBlockedUntil =
          null;

      return;
    }

    final int remainingSeconds =
        blockedUntil
            .difference(now)
            .inSeconds +
        1;

    throw FirebaseAiServiceException(
      'AI request limit reached. '
      'Please wait about $remainingSeconds seconds and try again.',
      isTemporary: true,
      retryAfterSeconds:
          remainingSeconds,
    );
  }

  bool _isQuotaError(
    String rawError,
  ) {
    final String value =
        rawError.toLowerCase();

    return value.contains(
          'quota exceeded',
        ) ||
        value.contains(
          'rate limit',
        ) ||
        value.contains(
          'resource_exhausted',
        ) ||
        value.contains(
          'free_tier_requests',
        ) ||
        value.contains(
          'too many requests',
        ) ||
        value.contains(
          'server error [429]',
        ) ||
        value.contains(
          'code": 429',
        ) ||
        value.contains(
          'code: 429',
        );
  }

  bool _isDailyQuotaError(
    String rawError,
  ) {
    final String value =
        rawError.toLowerCase();

    return value.contains(
          'generaterequestsperdayperprojectpermodel-freetier',
        ) ||
        value.contains(
          'generatecontentinputtokenspermodelperday-freetier',
        ) ||
        value.contains(
          'requestsperday',
        ) ||
        value.contains(
          'requests_per_day',
        ) ||
        value.contains(
          'per day per project per model',
        ) ||
        value.contains(
          'daily quota',
        );
  }

  bool _isTemporaryServiceError(
    String rawError,
  ) {
    final String value =
        rawError.toLowerCase();

    return value.contains(
          'server error [503]',
        ) ||
        value.contains(
          'code": 503',
        ) ||
        value.contains(
          'code: 503',
        ) ||
        value.contains(
          'status": "unavailable"',
        ) ||
        value.contains(
          'status: unavailable',
        ) ||
        value.contains(
          'deadline expired',
        ) ||
        value.contains(
          'deadline_exceeded',
        ) ||
        value.contains(
          'service unavailable',
        );
  }

  int? _extractRetryAfterSeconds(
    String rawError,
  ) {
    final RegExp retryPattern =
        RegExp(
      r'retry\s+in\s+([0-9]+(?:\.[0-9]+)?)s',
      caseSensitive: false,
    );

    final RegExpMatch? match =
        retryPattern.firstMatch(
      rawError,
    );

    if (match == null) {
      return null;
    }

    final double? seconds =
        double.tryParse(
      match.group(1) ?? '',
    );

    if (seconds == null) {
      return null;
    }

    return seconds.ceil();
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

  int get totalPoints =>
      questions.length;
}

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
// INTERNAL AI MATERIAL INFO
// ============================================================

class _AiMaterialInfo {
  _AiMaterialInfo({
    required this.resourceId,
    required this.fileName,
    required this.storagePath,
    required this.extension,
  });

  final String resourceId;
  final String fileName;
  final String storagePath;
  final String extension;
}

// ============================================================
// PREPARED AI INPUT
// ============================================================

class _PreparedAiInput {
  _PreparedAiInput({
    required this.sourceBytes,
    required this.inputMode,
    required this.textExtracted,
    required this.textLength,
    this.inlinePart,
    this.extractedText,
  });

  final int sourceBytes;
  final String inputMode;
  final bool textExtracted;
  final int textLength;

  final InlineDataPart? inlinePart;
  final String? extractedText;
}

// ============================================================
// CUSTOM EXCEPTION
// ============================================================

class FirebaseAiServiceException
    implements Exception {
  FirebaseAiServiceException(
    this.message, {
    this.isTemporary = false,
    this.retryAfterSeconds,
  });

  final String message;
  final bool isTemporary;
  final int? retryAfterSeconds;

  @override
  String toString() => message;
}
