import 'dart:js_interop';
import 'dart:typed_data';

@JS('caslmsReadPdfText')
external JSPromise<JSString> _readPdf(JSUint8Array bytes);

Future<String> readAssistantPdf(Uint8List bytes) async =>
    (await _readPdf(bytes.toJS).toDart).toDart;
