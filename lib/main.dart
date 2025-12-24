import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:widgets_to_image/widgets_to_image.dart';
import 'dart:convert';
import 'dart:typed_data';

final _bgColors = {
  Colors.transparent: 'Прозорий',
  Colors.black: 'Чорний',
  Colors.white: 'Білий',
};

enum QrShapeStyle {
  square,
  circle,
  smooth,
}

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: .fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  QrShapeStyle _qrShapeStyle = .square;
  Color _color = Colors.black;
  Color _bgColor = Colors.transparent;
  String? _embeddedImagePath;

  late final ValueNotifier<String?> _qrDataNotifier = ValueNotifier<String?>(
    null,
  );
  late final TextEditingController _qrDataController = TextEditingController();
  Timer? _debounce;

  late final WidgetsToImageController _widgetToImageController =
      WidgetsToImageController();

  @override
  void initState() {
    super.initState();

    _qrDataController.addListener(() {
      if (_debounce?.isActive ?? false) _debounce!.cancel();

      _debounce = Timer(const Duration(milliseconds: 300), () {
        String? newQrData = _qrDataController.text.trim();
        newQrData = newQrData.isEmpty ? null : newQrData;

        if (_qrDataNotifier.value != newQrData) {
          _qrDataNotifier.value = newQrData;
        }
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _qrDataNotifier.dispose();
    _qrDataController.dispose();
    _widgetToImageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisSize: .min,
          crossAxisAlignment: .start,
          spacing: 8,
          children: [
            WidgetsToImage(
              controller: _widgetToImageController,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: 300,
                    maxWidth: 300,
                    minHeight: 50,
                    minWidth: 50,
                  ),
                  child: ValueListenableBuilder<String?>(
                    valueListenable: _qrDataNotifier,
                    builder: (context, qrData, child) {
                      return qrData == null
                          ? Placeholder()
                          : PrettyQrView.data(
                              data: qrData,
                              decoration: PrettyQrDecoration(
                                image: _embeddedImagePath == null
                                    ? null
                                    : PrettyQrDecorationImage(
                                        image: NetworkImage(
                                          _embeddedImagePath!,
                                        ),
                                      ),
                                background: _bgColor,
                                shape: switch (_qrShapeStyle) {
                                  .square => PrettyQrSquaresSymbol(
                                    color: _color,
                                  ),
                                  .circle => PrettyQrDotsSymbol(
                                    color: _color,
                                  ),
                                  .smooth => PrettyQrSmoothSymbol(
                                    color: _color,
                                  ),
                                },
                                quietZone: .pixels(16),
                              ),
                            );
                    },
                  ),
                ),
              ),
            ),
            TextFormField(
              controller: _qrDataController,
              decoration: InputDecoration(
                hintText: 'https://example.com',
                labelText: 'Дані для QR кода',
              ),
            ),
            _Setting(
              name: 'Стиль QR коду',
              child: _SegmentedButton<QrShapeStyle>(
                segments: [
                  ButtonSegment(
                    value: .square,
                    label: Text('Квадрат'),
                  ),
                  ButtonSegment(
                    value: .circle,
                    label: Text('Коло'),
                  ),
                  ButtonSegment(
                    value: .smooth,
                    label: Text('Плавний'),
                  ),
                ],
                selected: {_qrShapeStyle},
                onSelectionChanged: (selection) {
                  setState(() => _qrShapeStyle = selection.single);
                },
              ),
            ),
            _Setting(
              name: 'Колір',
              child: _SegmentedButton<Color>(
                segments: [
                  ButtonSegment(
                    value: Colors.black,
                    label: Text('Чорний'),
                    icon: _ColorPreview(color: Colors.black),
                  ),
                  ButtonSegment(
                    value: Colors.white,
                    label: Text('Білий'),
                    icon: _ColorPreview(color: Colors.white),
                  ),
                ],
                selected: {_color},
                onSelectionChanged: (selection) {
                  setState(() => _color = selection.single);
                },
              ),
            ),
            _Setting(
              name: 'Фоновий колір',
              child: _SegmentedButton<Color>(
                segments: _bgColors.entries.map((entry) {
                  return ButtonSegment(
                    value: entry.key,
                    label: Text(entry.value),
                    icon: _ColorPreview(color: entry.key),
                  );
                }).toList(),
                selected: {_bgColor},
                onSelectionChanged: (selection) {
                  setState(() => _bgColor = selection.single);
                },
              ),
            ),
            _Setting(
              name: 'Зображення',
              child: OutlinedButton.icon(
                iconAlignment: _embeddedImagePath == null ? .start : .end,
                style: _embeddedImagePath == null
                    ? null
                    : OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                      ),
                onPressed: () async {
                  if (_embeddedImagePath != null) {
                    setState(() {
                      _embeddedImagePath = null;
                    });
                    return;
                  } 

                  final ImagePicker picker = ImagePicker();
                  final XFile? image = await picker.pickImage(
                    source: ImageSource.gallery,
                  );

                  setState(() {
                    _embeddedImagePath = image?.path;
                  });
                },
                label: Text(
                  _embeddedImagePath == null ? 'Вибрати' : 'Видалити',
                ),
                icon: Icon(
                  _embeddedImagePath == null ? Icons.image : Icons.delete,
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: ValueListenableBuilder<String?>(
        valueListenable: _qrDataNotifier,
        builder: (context, qrData, child) {
          return qrData == null
              ? SizedBox.shrink()
              : FloatingActionButton.extended(
                  onPressed: () async {
                    final pngBytes = await _widgetToImageController.capturePng(
                      pixelRatio: 3.0,
                      waitForAnimations: false,
                      delayMs: 300,
                    );

                    if (pngBytes == null) {
                      return;
                    }

                    final String? outputFile = await FilePicker.platform
                        .saveFile(
                          fileName: 'qr-code.png',
                          bytes: pngBytes,
                          type: FileType.image,
                          allowedExtensions: ['png'],
                        );

                    if (outputFile == null) {
                      // User canceled the picker
                      return;
                    }
                  },
                  label: Text('Завантажити QR код'),
                );
        },
      ),
    );
  }
}

class _ColorPreview extends StatelessWidget {
  const _ColorPreview({
    super.key,
    required this.color,
  });
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black),
        color: color,
      ),
    );
  }
}

class _Setting extends StatelessWidget {
  const _Setting({
    required this.name,
    required this.child,
  });

  final String name;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        crossAxisAlignment: .center,
        alignment: WrapAlignment.spaceBetween,
        runAlignment: WrapAlignment.spaceBetween,
        spacing: 8,
        children: [
          Text(name),
          child,
        ],
      ),
    );
  }
}

class _SegmentedButton<T> extends SegmentedButton<T> {
  const _SegmentedButton({
    super.key,
    required List<ButtonSegment<T>> super.segments,
    required super.selected,
    super.onSelectionChanged,
    super.emptySelectionAllowed = false,
    super.multiSelectionEnabled = false,
    super.showSelectedIcon = false,
    super.direction = Axis.horizontal,
  });
}
