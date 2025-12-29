import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:qr_code_generator/theme.dart';
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

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    final brightness = View.of(context).platformDispatcher.platformBrightness;

    // Retrieves the default theme for the platform
    TextTheme textTheme = Theme.of(context).textTheme;

    MaterialTheme theme = MaterialTheme(textTheme);
    return MaterialApp(
      title: 'Flutter Demo',
      theme: theme.light(),
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
  late final ValueNotifier<QrShapeStyle> _qrShapeStyle =
      ValueNotifier<QrShapeStyle>(QrShapeStyle.square);
  late final ValueNotifier<Color> _color = ValueNotifier<Color>(Colors.black);
  late final ValueNotifier<Color> _bgColor = ValueNotifier<Color>(
    Colors.transparent,
  );
  late final ValueNotifier<String?> _embeddedImagePath = ValueNotifier<String?>(
    null,
  );

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
    _qrShapeStyle.dispose();
    _color.dispose();
    _bgColor.dispose();
    _embeddedImagePath.dispose();
    _qrDataController.dispose();
    _widgetToImageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Scrollbar(
        thumbVisibility: true,
        trackVisibility: true,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16).add(EdgeInsets.only(
            bottom: 80,
          )),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 620,
              ),
              child: Column(
                mainAxisSize: .min,
                crossAxisAlignment: .center,
                mainAxisAlignment: .center,
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
                            if (qrData == null) return Placeholder();

                            return ValueListenableBuilder<QrShapeStyle>(
                              valueListenable: _qrShapeStyle,
                              builder: (context, shape, _) {
                                return ValueListenableBuilder<Color>(
                                  valueListenable: _color,
                                  builder: (context, color, _) {
                                    return ValueListenableBuilder<Color>(
                                      valueListenable: _bgColor,
                                      builder: (context, bgColor, _) {
                                        return ValueListenableBuilder<String?>(
                                          valueListenable: _embeddedImagePath,
                                          builder: (context, embedded, _) {
                                            return PrettyQrView.data(
                                              data: qrData,
                                              decoration: PrettyQrDecoration(
                                                image: embedded == null
                                                    ? null
                                                    : PrettyQrDecorationImage(
                                                        image: NetworkImage(
                                                          embedded,
                                                        ),
                                                      ),
                                                background: bgColor,
                                                shape: switch (shape) {
                                                  QrShapeStyle.square =>
                                                    PrettyQrSquaresSymbol(
                                                      color: color,
                                                    ),
                                                  QrShapeStyle.circle =>
                                                    PrettyQrDotsSymbol(
                                                      color: color,
                                                    ),
                                                  QrShapeStyle.smooth =>
                                                    PrettyQrSmoothSymbol(
                                                      color: color,
                                                    ),
                                                },
                                                quietZone: .pixels(16),
                                              ),
                                            );
                                          },
                                        );
                                      },
                                    );
                                  },
                                );
                              },
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
                    child: ValueListenableBuilder<QrShapeStyle>(
                      valueListenable: _qrShapeStyle,
                      builder: (context, value, _) {
                        return _SegmentedButton<QrShapeStyle>(
                          segments: [
                            ButtonSegment(
                              value: QrShapeStyle.square,
                              label: Text('Квадрат'),
                            ),
                            ButtonSegment(
                              value: QrShapeStyle.circle,
                              label: Text('Коло'),
                            ),
                            ButtonSegment(
                              value: QrShapeStyle.smooth,
                              label: Text('Плавний'),
                            ),
                          ],
                          selected: {value},
                          onSelectionChanged: (selection) {
                            _qrShapeStyle.value = selection.single;
                          },
                        );
                      },
                    ),
                  ),
                  _Setting(
                    name: 'Колір',
                    child: ValueListenableBuilder<Color>(
                      valueListenable: _color,
                      builder: (context, value, _) {
                        return _SegmentedButton<Color>(
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
                          selected: {value},
                          onSelectionChanged: (selection) {
                            _color.value = selection.single;
                          },
                        );
                      },
                    ),
                  ),
                  _Setting(
                    name: 'Фоновий колір',
                    child: ValueListenableBuilder<Color>(
                      valueListenable: _bgColor,
                      builder: (context, value, _) {
                        return _SegmentedButton<Color>(
                          segments: _bgColors.entries.map((entry) {
                            return ButtonSegment(
                              value: entry.key,
                              label: Text(entry.value),
                              icon: _ColorPreview(color: entry.key),
                            );
                          }).toList(),
                          selected: {value},
                          onSelectionChanged: (selection) {
                            _bgColor.value = selection.single;
                          },
                        );
                      },
                    ),
                  ),
                  _Setting(
                    name: 'Зображення',
                    child: ValueListenableBuilder<String?>(
                      valueListenable: _embeddedImagePath,
                      builder: (context, embedded, _) {
                        return OutlinedButton.icon(
                          iconAlignment: embedded == null ? .start : .end,
                          style: embedded == null
                              ? null
                              : OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                ),
                          onPressed: () async {
                            if (embedded != null) {
                              _embeddedImagePath.value = null;
                              return;
                            }

                            final ImagePicker picker = ImagePicker();
                            final XFile? image = await picker.pickImage(
                              source: ImageSource.gallery,
                            );

                            _embeddedImagePath.value = image?.path;
                          },
                          label: Text(
                            embedded == null ? 'Вибрати' : 'Видалити',
                          ),
                          icon: Icon(
                            embedded == null ? Icons.image : Icons.delete,
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      persistentFooterButtons: [
        TextButton(
          onPressed: () {
            showLicensePage(context: context);
          },
          child: Text('Ліцензії'),
        ),
      ],
      floatingActionButtonLocation: .miniCenterDocked,
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
