import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isAndroid) {
    await AndroidInAppWebViewController.setWebContentsDebuggingEnabled(true);
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Waste-Hunt',
      home: WebViewScreen(),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  const WebViewScreen({super.key});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  final GlobalKey webViewKey = GlobalKey();
  InAppWebViewController? webViewController;
  final ImagePicker _picker = ImagePicker();

  final String siteUrl = 'https://moonlit-macaron-2cc074.netlify.app/';

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final bool canGoBack = await webViewController?.canGoBack() ?? false;
        if (canGoBack) {
          webViewController?.goBack();
        } else {
          if (mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        body: SafeArea(
          child: InAppWebView(
            key: webViewKey,
            initialUrlRequest: URLRequest(url: WebUri(siteUrl)),
            initialOptions: InAppWebViewGroupOptions(
              crossPlatform: InAppWebViewOptions(
                useShouldOverrideUrlLoading: true,
                mediaPlaybackRequiresUserGesture: false,
              ),
              android: AndroidInAppWebViewOptions(
                useHybridComposition: true,
              ),
            ),
            onWebViewCreated: (controller) {
              webViewController = controller;

              //java handler
              controller.addJavaScriptHandler(
                handlerName: 'openLinkHandler',
                callback: (args) async {
                  if (args.isNotEmpty && args[0] is String) {
                    Uri url = Uri.parse(args[0]);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url,
                          mode: LaunchMode.externalApplication);
                    } else {
                      debugPrint("Could not launch $url");
                    }
                  }
                },
              );

              controller.addJavaScriptHandler(
                handlerName: 'openFilePicker',
                callback: (args) async {
                  final XFile? photo =
                      await _picker.pickImage(source: ImageSource.gallery);
                  if (photo != null) {
                    final bytes = await photo.readAsBytes();
                    final base64String = base64Encode(bytes);
                    return 'data:image/jpeg;base64,$base64String';
                  }
                  return '';
                },
              );

              controller.addJavaScriptHandler(
                handlerName: 'shareCharacter',
                callback: (args) async {
                  final imageUrl = args.isNotEmpty ? args[0].toString() : null;
                  if (imageUrl == null || imageUrl.isEmpty) return;

                  try {
                    final response = await http.get(Uri.parse(imageUrl));
                    final Uint8List imageBytes = response.bodyBytes;
                    final tempDir = await getTemporaryDirectory();
                    final imagePath = '${tempDir.path}/character.png';
                    final imageFile = File(imagePath);
                    await imageFile.writeAsBytes(imageBytes);
                    await Share.shareXFiles([XFile(imagePath)],
                        text: '#WasteHunt');
                  } catch (e) {
                    debugPrint('Failed to share image: $e');
                  }
                },
              );
            },
            androidOnPermissionRequest: (controller, origin, resources) async {
              return PermissionRequestResponse(
                resources: resources,
                action: PermissionRequestResponseAction.GRANT,
              );
            },
          ),
        ),
      ),
    );
  }
}
