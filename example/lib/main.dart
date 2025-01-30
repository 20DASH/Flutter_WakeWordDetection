import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io'; // Added this import
import 'package:flutter/services.dart';
import 'package:flutter_wake_word/flutter_wake_word.dart';
import 'package:flutter_wake_word/use_model.dart';
import 'package:flutter_wake_word/instance_config.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:ios_microphone_permission/ios_microphone_permission.dart';


void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MaterialApp(
    home: WakeWordApp(),
  ));
}

class WakeWordApp extends StatefulWidget {
  @override
  _WakeWordAppState createState() => _WakeWordAppState();
}

class _WakeWordAppState extends State<WakeWordApp> {
  String message = "Listening to WakeWord...";
  final _flutterWakeWordPlugin = FlutterWakeWord();
  bool isFlashing = false;
  String _platformVersion = 'Unknown';
//  final EventChannel eventChannel = EventChannel('flutter_wake_word/event');
// Remove 
  final useModel = UseModel(); // Single instance of UseModel

  final List<InstanceConfig> instanceConfigs = [
    InstanceConfig(
      id: 'need_help_now',
      modelName: 'need_help_now.onnx',
      threshold: 0.9999,
      bufferCnt: 3,
      sticky: false,
    ),
  ];
/*
  void startListeningToEvents() {
    eventChannel.receiveBroadcastStream().listen(
      (event) {
        print('Event received: $event');
        final phrase = event['phrase'];
        if (phrase != null) {
          onWakeWordDetected(phrase);
        }
      },
      onError: (error) {
        print('Error: $error');
      },
    );
  }
*/
  Future<void> initializeKeywordDetection(List<InstanceConfig> configs) async {
    try {

      print("After requestAudioPermissions:");

      print("useModel == : $useModel");
      await useModel.setKeywordDetectionLicense(
        "MTczODEwMTYwMDAwMA==-Vmv1jwEG+Fbog9LoblZnVT4TzAXDhZs7l9O18A+8ul8=",
      );
      print("After useModel.setKeywordDetectionLicense:");

      await useModel.loadModel(configs, onWakeWordDetected);
      print("After useModel.loadModel:");
    } catch (e) {
      print("Error initializing keyword detection: $e");
    }
  }

  Future<void> openSettings() async {
    if (await Permission.microphone.isPermanentlyDenied) {
      print('Microphone permission permanently denied.');
      await openAppSettings();
    } else {
      print('Microphone permission denied.');
    }
  }

  Future<void> requestAudioPermissions() async {
    var status = await Permission.microphone.status;
    final record = AudioRecorder();

    // Check and request permission if needed
    if (await record.hasPermission()) {
        print('record.hasPermission() false:');      
    }else {
        print('record.hasPermission() true:');      

    }

    if (status.isDenied) {
      print('No Microphone permission requesting:');      
      status = await Permission.microphone.request();
    }

    if (status.isGranted) {
      print('Microphone permission granted.');
      if (Platform.isAndroid) {
        var foregroundServicePermission =
            await Permission.systemAlertWindow.request();
        if (!foregroundServicePermission.isGranted) {
          foregroundServicePermission = await Permission.systemAlertWindow.request();
        }
      }
      await initializeKeywordDetection(instanceConfigs);
    } else {
      print('Microphone permission denied.');
      openSettings();
    }
  }

  @override
  void initState() {
    super.initState();
    initPlatformState();
    requestAudioPermissions();
    // startListeningToEvents();
  }

  void onWakeWordDetected(String wakeWord) {

    print("onWakeWordDetected(): $wakeWord");
    print("Calling stopListening(): $wakeWord");
    useModel.stopListening();

    message = "WakeWord '$wakeWord' DETECTED";
    setState(() {
      message = "WakeWord '$wakeWord' DETECTED";
      isFlashing = true;
    });

    Future.delayed(Duration(seconds: 5), () {
      setState(() {
        useModel.startListening();
        message = "Listening to WakeWord...";
        isFlashing = false;
      });
    });
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String platformVersion;
    // Platform messages may fail, so we use a try/catch PlatformException.
    // We also handle the message potentially returning null.
    try {
      platformVersion =
          await _flutterWakeWordPlugin.getPlatformVersion() ?? 'Unknown platform version';
    } on PlatformException {
      platformVersion = 'Failed to get platform version.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = platformVersion;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = MediaQuery.of(context).platformBrightness == Brightness.dark;
    final backgroundColor = isFlashing
        ? (isDarkMode ? Colors.red[400] : Colors.red[100])
        : (isDarkMode ? Colors.black : Colors.white);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDarkMode
                ? [Colors.grey[800]!, Colors.grey[900]!]
                : [Colors.blue[50]!, Colors.blue[100]!],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center, // Center content vertically
          children: [
            Container(
              color: backgroundColor,
              padding: const EdgeInsets.all(16.0),
              child: Text(
                message,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: isDarkMode ? Colors.white : Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 20), // Add space between message and platform version
            Text(
              'Platform Version: $_platformVersion',
              style: TextStyle(
                fontSize: 16,
                color: isDarkMode ? Colors.white : Colors.black,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}