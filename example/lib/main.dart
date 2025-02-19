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

// We use a class just for clarity, or we can store a Map:
class _MemoryReading {
  final DateTime timestamp;
  final double memoryMB;
  _MemoryReading(this.timestamp, this.memoryMB);
}

class _WakeWordAppState extends State<WakeWordApp> {
  String message = "Listening to WakeWord...";
  final _flutterWakeWordPlugin = FlutterWakeWord();
  bool isFlashing = false;
  String _platformVersion = 'Unknown';
  final useModel = UseModel(); // Single instance of UseModel
  // START: Memory Monitoring Code
// Inside your _WakeWordAppState:

DateTime? _appStartTime;             // When the app starts
List<_MemoryReading> _memoryReadings = [];
  Timer? _memoryTimer;

void startMemoryMonitoring() {
  // Record the time we started
  _appStartTime ??= DateTime.now();

  _memoryTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
    final now = DateTime.now();

    // Current memory usage
    final memoryUsageMB = ProcessInfo.currentRss / (1024 * 1024);

    // Save it in our list
    _memoryReadings.add(_MemoryReading(now, memoryUsageMB));

    // 1) Print the exact timestamp + memory usage
    print("[${now.toIso8601String()}] Current Memory Usage: "
          "${memoryUsageMB.toStringAsFixed(2)} MB");

    // 2) Compute min & max AFTER first 3 minutes
    final threeMinutesAfterStart = _appStartTime!.add(const Duration(minutes: 3));
    final validAllTimeReadings = _memoryReadings.where((r) => r.timestamp.isAfter(threeMinutesAfterStart)).toList();

    if (validAllTimeReadings.isNotEmpty) {
      final minAllTime = validAllTimeReadings.map((r) => r.memoryMB).reduce((a, b) => a < b ? a : b);
      final maxAllTime = validAllTimeReadings.map((r) => r.memoryMB).reduce((a, b) => a > b ? a : b);
      print("  All-time (post-3min) Min: ${minAllTime.toStringAsFixed(2)} MB "
            "Max: ${maxAllTime.toStringAsFixed(2)} MB");
    } else {
      print("  (Not computing all-time min/max until 3 minutes pass.)");
    }

    // 3) Compute min & max for the last hour
    final oneHourAgo = now.subtract(const Duration(hours: 1));
    final lastHourReadings = _memoryReadings.where((r) => r.timestamp.isAfter(oneHourAgo)).toList();

    if (lastHourReadings.isNotEmpty) {
      final minLastHour = lastHourReadings.map((r) => r.memoryMB).reduce((a, b) => a < b ? a : b);
      final maxLastHour = lastHourReadings.map((r) => r.memoryMB).reduce((a, b) => a > b ? a : b);
      print("  Last hour    Min: ${minLastHour.toStringAsFixed(2)} MB "
            "Max: ${maxLastHour.toStringAsFixed(2)} MB");
    } else {
      print("  (No readings in the last hour yet.)");
    }
  });
}

  @override
  void dispose() {
    _memoryTimer?.cancel(); // Stop monitoring when the widget is disposed
    super.dispose();
  }

// END: Memory Monitoring Code


  final List<InstanceConfig> instanceConfigs = [
    InstanceConfig(
      id: 'need_help_now',
      modelName: 'need_help_now.onnx',
      threshold: 0.9999,
      bufferCnt: 3,
      sticky: false,
    ),
  ];

  Future<void> initializeKeywordDetection(List<InstanceConfig> configs) async {
    try {

      print("After requestAudioPermissions:");

      print("useModel == : $useModel");
      await useModel.setKeywordDetectionLicense(
        "MTc0MTk4OTYwMDAwMA==-T6tBtoFpClll7ef89x/bOXRxC9Maf2nZTUFXqBKwnc0="
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
    startMemoryMonitoring();
    initPlatformState();
    requestAudioPermissions();
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