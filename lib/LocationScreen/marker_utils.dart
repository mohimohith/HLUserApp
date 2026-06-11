import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Custom marker ko resize karke return karega
Future<BitmapDescriptor> getResizedMarker(String path, int width) async {
  final ByteData data = await rootBundle.load(path);
  final ui.Codec codec = await ui.instantiateImageCodec(
    data.buffer.asUint8List(),
    targetWidth: width, // 👈 marker ka size (px me)
  );
  final ui.FrameInfo fi = await codec.getNextFrame();
  final ByteData? resizedData =
  await fi.image.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.fromBytes(resizedData!.buffer.asUint8List());
}
