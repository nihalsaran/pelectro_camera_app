import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_uvc_camera/flutter_uvc_camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/services.dart';

class CameraTest extends StatefulWidget {
  const CameraTest({Key? key}) : super(key: key);

  @override
  State<CameraTest> createState() => _CameraTestState();
}

class _CameraTestState extends State<CameraTest> {
  int? burstCount;
  String lastSavedPath = '';
  double _zoomLevel = 1.0;
  final double _maxZoomLevel = 3.0; // Adjust as needed
  final double _minZoomLevel = 1.0;
  final double _zoomStep = 0.1;
  UVCCameraController? cameraController;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    cameraController = UVCCameraController();
    cameraController?.msgCallback = (state) {
      showCustomToast(state);
    };
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await Permission.storage.request();
    await Permission.camera.request();
    await initializeCamera();
  }

  Future<void> initializeCamera() async {
    await cameraController?.openUVCCamera();
    await cameraController?.getAllPreviewSizes();
    cameraController?.updateResolution(PreviewSize(width: 352, height: 288));
  }

  void showCustomToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<String?> _showNameFileDialog() async {
    String fileName = '';
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Name your photo'),
          content: TextField(
            onChanged: (value) {
              fileName = value;
            },
            decoration: const InputDecoration(
              hintText: 'Enter file name',
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Save'),
              onPressed: () {
                Navigator.of(context).pop(fileName);
              },
            ),
          ],
        );
      },
    );
  }

  Future<String?> getExternalStoragePath() async {
    if (Platform.isAndroid) {
      final Directory? directory = await getExternalStorageDirectory();
      if (directory != null) {
        final String fullPath = path.join(directory.path, 'Photos');
        final Directory dir = Directory(fullPath);
        if (!await dir.exists()) {
          await dir.create(recursive: true);
        }
        return fullPath;
      }
    } else if (Platform.isIOS) {
      final Directory documentsDir = await getApplicationDocumentsDirectory();
      final String fullPath = path.join(documentsDir.path, 'Photos');
      final Directory dir = Directory(fullPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return fullPath;
    }
    return null;
  }

  Future<void> takePicture() async {
    try {
      String? originalPath = await cameraController?.takePicture();
      if (originalPath != null) {
        String? fileName = await _showNameFileDialog();
        if (fileName != null && fileName.isNotEmpty) {
          String? savePath = await getExternalStoragePath();
          if (savePath != null) {
            final String newPath = path.join(savePath, '$fileName.jpg');

            await File(originalPath).copy(newPath);
            await File(originalPath).delete();

            setState(() {
              lastSavedPath = newPath;
            });
            showCustomToast('Photo saved to: $newPath');
          } else {
            showCustomToast('Unable to access storage');
          }
        }
      }
    } catch (e) {
      showCustomToast('Error saving photo: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (cameraController != null)
            Positioned.fill(
              child: Transform.scale(
                scale: _zoomLevel,
                child: SizedBox.expand(
                  child: Transform.translate(
                    offset: const Offset(-160, 0), // Adjust -20 to move left
                    child: UVCCameraView(
                      cameraController: cameraController!,
                      params: const UVCCameraViewParamsEntity(frameFormat: 1),
                      width: MediaQuery.of(context).size.width,
                      height: MediaQuery.of(context).size.height,
                    ),
                  ),
                ),
              ),
            ),
          // Inside the Positioned.fill widget in the build method:
          Positioned.fill(
            child: Transform.translate(
              offset: const Offset(220, -70),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Zoom In Button (+)
                  Transform.translate(
                    offset: const Offset(30, 30),
                    child: GestureDetector(
                      onTap: _zoomIn,
                      child: Icon(
                        Icons.zoom_in,
                        color: Colors.white70,
                        size: 40,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Controls Row (Gallery, Burst Buttons, Shutter Button)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 32.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Gallery Button
                        Transform.translate(
                          offset: const Offset(260,
                              150), // Adjust this value to move more/less left
                          child: GestureDetector(
                            onTap: () async {
                              String? directoryPath =
                                  await getExternalStoragePath();
                              if (directoryPath != null) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        GalleryPage(directoryPath),
                                  ),
                                );
                              } else {
                                showCustomToast('No directory found');
                              }
                            },
                            child: Icon(
                              Icons.photo_library,
                              color: Colors.white70,
                              size: 40,
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),

                        // 5x Preset Button
                        GestureDetector(
                          onTap: () => setState(() => burstCount = 5),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: burstCount == 5
                                  ? Colors.deepOrange
                                  : Colors.white70,
                            ),
                            child: Center(
                              child: Text(
                                '5x',
                                style: TextStyle(
                                  color: burstCount == 5
                                      ? Colors.white
                                      : Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),

                        // Shutter Button
                        GestureDetector(
                          onTap: () async {
                            if (burstCount != null) {
                              for (int i = 0; i < burstCount!; i++) {
                                await takePicture();
                                await Future.delayed(
                                    const Duration(milliseconds: 500));
                              }
                              setState(() => burstCount = null);
                            } else {
                              takePicture();
                            }
                          },
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.deepOrange,
                                width: 4,
                              ),
                            ),
                            child: Container(
                              margin: const EdgeInsets.all(2),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white70,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),

                        // 10x Preset Button
                        GestureDetector(
                          onTap: () => setState(() => burstCount = 10),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: burstCount == 10
                                  ? Colors.deepOrange
                                  : Colors.white70,
                            ),
                            child: Center(
                              child: Text(
                                '10x',
                                style: TextStyle(
                                  color: burstCount == 10
                                      ? Colors.white
                                      : Colors.black,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Zoom Out Button (-)
                  Transform.translate(
                    offset: const Offset(30, -20),
                    child: GestureDetector(
                      onTap: _zoomOut,
                      child: Icon(
                        Icons.zoom_out,
                        color: Colors.white70,
                        size: 40,
                      ),
                    ),
                  ),

                  // Display the last saved photo name
                  if (lastSavedPath.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        path.basename(lastSavedPath),
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    cameraController?.closeCamera();
    super.dispose();
  }

  void _zoomIn() {
    setState(() {
      if (_zoomLevel < _maxZoomLevel) {
        _zoomLevel += _zoomStep;
      }
    });
  }

  void _zoomOut() {
    setState(() {
      if (_zoomLevel > _minZoomLevel) {
        _zoomLevel -= _zoomStep;
      }
    });
  }
}

// GalleryPage widget
class GalleryPage extends StatelessWidget {
  final String directoryPath;

  const GalleryPage(this.directoryPath, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final directory = Directory(directoryPath);
    final images = directory
        .listSync()
        .where((item) =>
            item is File &&
            (item.path.endsWith('.jpg') || item.path.endsWith('.png')))
        .map((item) => item.path)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gallery'),
        backgroundColor: Colors.black,
      ),
      body: images.isNotEmpty
          ? GridView.builder(
              itemCount: images.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
              ),
              itemBuilder: (context, index) {
                final imagePath = images[index];
                return GestureDetector(
                  onTap: () {
                    // Open image in full screen
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FullImageView(imagePath),
                      ),
                    );
                  },
                  child: Image.file(
                    File(imagePath),
                    fit: BoxFit.cover,
                  ),
                );
              },
            )
          : const Center(
              child: Text(
                'No images found.',
                style: TextStyle(color: Colors.white),
              ),
            ),
      backgroundColor: Colors.black,
    );
  }
}

// FullImageView widget
class FullImageView extends StatelessWidget {
  final String imagePath;

  const FullImageView(this.imagePath, {Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Photo'),
        backgroundColor: Colors.black,
      ),
      body: Center(
        child: Image.file(File(imagePath)),
      ),
      backgroundColor: Colors.black,
    );
  }
}
