import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

// FIX 1: Correct Import for Android Intent
import 'package:android_intent_plus/android_intent.dart'; 
import 'package:android_intent_plus/flag.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:confetti/confetti.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

// -----------------------------------------------------------------------------
// CONSTANTS & 2026 SCHEDULE DATA
// -----------------------------------------------------------------------------

const int UDP_PORT = 4545;
const String APP_TITLE = "JAEXO ULTIMATE";

// Ported from jpx.py
final Map<String, Map<String, dynamic>> kSchedule2026 = {
  // FEBRUARY 2026
  '2026-02-01': {'event': 'TEST DAY: Star Score-II', 'type': 'TEST', 'target': 4},
  '2026-02-02': {'event': 'PREP: Eng/PE + OC/IOC', 'type': 'PREP', 'target': 5},
  '2026-02-03': {'event': 'PREP: Eng/PE + OC/IOC', 'type': 'PREP', 'target': 5},
  '2026-02-04': {'event': 'TEST DAY: Star Score-II', 'type': 'TEST', 'target': 4},
  '2026-02-05': {'event': 'PREP: Eng/PE + OC/IOC', 'type': 'PREP', 'target': 5},
  '2026-02-06': {'event': 'PREP: Eng/PE + OC/IOC', 'type': 'PREP', 'target': 5},
  '2026-02-07': {'event': 'TEST DAY: Star Score-II', 'type': 'TEST', 'target': 4},
  '2026-02-08': {'event': 'SELF STUDY: Physics Focus', 'type': 'PREP', 'target': 5}, 
  '2026-02-09': {'event': 'PREP: Physics/PE', 'type': 'PREP', 'target': 5},
  '2026-02-10': {'event': 'TEST DAY: Star Score-II', 'type': 'TEST', 'target': 4},
  '2026-02-11': {'event': 'PREP: Physics/PE', 'type': 'PREP', 'target': 5},
  '2026-02-12': {'event': 'TEST DAY: Star Score-II', 'type': 'TEST', 'target': 4},
  '2026-02-13': {'event': 'PREP: Physics/PE', 'type': 'PREP', 'target': 5},
  '2026-02-14': {'event': 'PREP: Physics/PE', 'type': 'PREP', 'target': 5},
  '2026-02-15': {'event': 'BOARD PREP: PE (IOC Rev)', 'type': 'BOARD_PREP', 'target': 3},
  '2026-02-16': {'event': 'BOARD PREP: PE (IOC Rev)', 'type': 'BOARD_PREP', 'target': 3},
  '2026-02-17': {'event': 'BOARD PREP: PE (IOC Rev)', 'type': 'BOARD_PREP', 'target': 3},
  '2026-02-18': {'event': 'CBSE BOARD EXAM: PE', 'type': 'BOARD_EXAM', 'target': 0},
  '2026-02-19': {'event': 'BOARD PREP: Physics', 'type': 'BOARD_PREP', 'target': 3},
  '2026-02-20': {'event': 'CBSE BOARD EXAM: Physics', 'type': 'BOARD_EXAM', 'target': 0},
  '2026-02-21': {'event': 'SELF STUDY: Chemistry Focus', 'type': 'PREP', 'target': 5},
  '2026-02-22': {'event': 'HEAVY TEST: Adv (2 Paper)', 'type': 'HEAVY', 'target': 0.5},
  '2026-02-23': {'event': 'PREP: Chemistry (OC+PC)', 'type': 'PREP', 'target': 5},
  '2026-02-24': {'event': 'PREP: Chemistry (OC+PC)', 'type': 'PREP', 'target': 5},
  '2026-02-25': {'event': 'BOARD PREP: Chem', 'type': 'BOARD_PREP', 'target': 3},
  '2026-02-26': {'event': 'BOARD PREP: Chem', 'type': 'BOARD_PREP', 'target': 3},
  '2026-02-27': {'event': 'BOARD PREP: Chem', 'type': 'BOARD_PREP', 'target': 3},
  '2026-02-28': {'event': 'CBSE BOARD EXAM: Chemistry', 'type': 'BOARD_EXAM', 'target': 0},
  // MARCH 2026
  '2026-03-01': {'event': 'SELF STUDY: Math Focus', 'type': 'PREP', 'target': 5},
  '2026-03-09': {'event': 'CBSE BOARD EXAM: Maths', 'type': 'BOARD_EXAM', 'target': 0},
  '2026-03-12': {'event': 'CBSE BOARD EXAM: English', 'type': 'BOARD_EXAM', 'target': 0},
  '2026-03-15': {'event': 'HEAVY TEST: Adv (2)', 'type': 'HEAVY', 'target': 0.5},
  '2026-03-22': {'event': 'HEAVY TEST: Main + Adv', 'type': 'HEAVY', 'target': 0.5},
  // APRIL 2026
  '2026-04-02': {'event': 'TEST DAY: Adv (1 Paper)', 'type': 'TEST', 'target': 4},
  '2026-04-16': {'event': 'FINAL REVISION', 'type': 'GRIND', 'target': 10},
  // MAY 2026
  '2026-05-17': {'event': '🎯 JEE ADVANCED 2026 EXAMINATION DAY 🎯', 'type': 'FINAL', 'target': 12}
};

final Map<String, ColorScheme> kThemes = {
  'matrix': const ColorScheme.dark(
      primary: Color(0xFF00FF41), surface: Colors.black, background: Colors.black, secondary: Color(0xFF008F11), error: Colors.red),
  'redline': const ColorScheme.dark(
      primary: Color(0xFFFF0000), surface: Color(0xFF1A0000), background: Colors.black, secondary: Color(0xFF880000), error: Color(0xFFFFAA00)),
  'deepspace': const ColorScheme.dark(
      primary: Color(0xFF00BFFF), surface: Color(0xFF001133), background: Colors.black, secondary: Color(0xFF0066AA), error: Color(0xFFFF00FF)),
  'amber': const ColorScheme.dark(
      primary: Color(0xFFFFBF00), surface: Color(0xFF221100), background: Colors.black, secondary: Color(0xFF886600), error: Color(0xFFFF4400)),
  'ghost': const ColorScheme.dark( // Default
      primary: Color(0xFFE0E0E0), surface: Color(0xFF121212), background: Colors.black, secondary: Color(0xFF555555), error: Color(0xFFFF66BB)),
};

// -----------------------------------------------------------------------------
// MODELS
// -----------------------------------------------------------------------------

class Task {
  String id;
  String title;
  String tag;
  bool isCompleted;
  int coins;
  String type; // 'focus', 'offline', 'online_test', 'training', 'music'
  int problems; // For training config
  // State for resume
  int elapsed;
  int lastQ;
  int lastCorrect;
  int lastScore;

  Task({
    required this.id,
    required this.title,
    this.tag = 'MISC',
    this.isCompleted = false,
    this.coins = 0,
    this.type = 'focus',
    this.problems = 15,
    this.elapsed = 0,
    this.lastQ = 1,
    this.lastCorrect = 0,
    this.lastScore = 0,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'title': title, 'tag': tag, 'isCompleted': isCompleted, 'coins': coins, 
    'type': type, 'problems': problems, 'elapsed': elapsed, 
    'lastQ': lastQ, 'lastCorrect': lastCorrect, 'lastScore': lastScore
  };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
    id: json['id'], title: json['title'], tag: json['tag'] ?? 'MISC',
    isCompleted: json['isCompleted'], coins: json['coins'], type: json['type'],
    problems: json['problems'] ?? 15, elapsed: json['elapsed'] ?? 0,
    lastQ: json['lastQ'] ?? 1, lastCorrect: json['lastCorrect'] ?? 0, lastScore: json['lastScore'] ?? 0
  );
}

class LogEntry {
  int id;
  String date; // yyyy-MM-dd
  String type;
  int duration;
  String taskName;
  int questionsTotal;
  int questionsCorrect;
  int marksScored;

  LogEntry({required this.id, required this.date, required this.type, required this.duration, required this.taskName, this.questionsTotal=0, this.questionsCorrect=0, this.marksScored=0});

  Map<String, dynamic> toJson() => { 'id': id, 'date': date, 'type': type, 'duration': duration, 'taskName': taskName, 'questionsTotal': questionsTotal, 'questionsCorrect': questionsCorrect, 'marksScored': marksScored };
  factory LogEntry.fromJson(Map<String, dynamic> j) => LogEntry(id: j['id'], date: j['date'], type: j['type'], duration: j['duration'], taskName: j['taskName'], questionsTotal: j['questionsTotal'], questionsCorrect: j['questionsCorrect'], marksScored: j['marksScored']);
}

class Profile {
  String id;
  String name;
  String networkSsid; 
  String patternHash; 
  int coins;
  Map<String, double> dailyHours; // Date -> Hours
  List<Task> queue;
  String musicAnchorId; 
  List<Task> tasks; // Current day's tasks
  List<LogEntry> logs;
  String lastSyncDate;

  Profile({
    required this.id, required this.name, required this.networkSsid, required this.patternHash,
    this.coins = 0, this.dailyHours = const {}, this.queue = const [],
    this.musicAnchorId = '', this.tasks = const [], this.logs = const [],
    this.lastSyncDate = '',
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'name': name, 'networkSsid': networkSsid, 'patternHash': patternHash,
    'coins': coins, 'dailyHours': dailyHours,
    'queue': queue.map((e) => e.toJson()).toList(),
    'musicAnchorId': musicAnchorId,
    'tasks': tasks.map((e) => e.toJson()).toList(),
    'logs': logs.map((e) => e.toJson()).toList(),
    'lastSyncDate': lastSyncDate
  };

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
    id: json['id'], name: json['name'], networkSsid: json['networkSsid'], patternHash: json['patternHash'],
    coins: json['coins'], dailyHours: Map<String, double>.from(json['dailyHours'] ?? {}),
    queue: (json['queue'] as List).map((e) => Task.fromJson(e)).toList(),
    musicAnchorId: json['musicAnchorId'] ?? '',
    tasks: (json['tasks'] as List).map((e) => Task.fromJson(e)).toList(),
    logs: (json['logs'] as List).map((e) => LogEntry.fromJson(e)).toList(),
    lastSyncDate: json['lastSyncDate'] ?? '',
  );
}

// -----------------------------------------------------------------------------
// SERVICES
// -----------------------------------------------------------------------------

class ScheduleService {
  static List<Task> generateForDate(DateTime date) {
    String dateKey = DateFormat('yyyy-MM-dd').format(date);
    final item = kSchedule2026[dateKey];
    List<Task> t = [];
    String uuid() => const Uuid().v4();
    void add(String txt, String tag, String mode) => t.add(Task(id: uuid(), title: txt, tag: tag, type: mode));

    int dayNum = date.day;
    String mathBook = dayNum % 3 == 0 ? 'Yellow Book: Algebra' : dayNum % 3 == 1 ? 'Sameer Bansal: Calculus' : 'Pink Book: Coord/Vector';

    if (item == null) {
      add('PYQs - Training', 'JEEADV', 'training');
      add('PYQs - Online Test', 'JEEADV', 'online_test');
      add('PYQs - Offline', 'JEEADV', 'offline');
      add('PYQs - Focus', 'JEEADV', 'focus');
      return t;
    }

    String type = item['type'];
    String event = item['event'];

    if (type == 'BOARD_EXAM') {
      add('CBSE EXAM: $event', 'EXAM', 'offline');
    } else if (type == 'HEAVY') {
      add('EVENT: $event', 'TEST', 'offline');
      add('Analysis & Mistake Audit', 'AUDIT', 'focus');
    } else if (type == 'BOARD_PREP') {
      add('Board Prep: ${event.split(':').last}', 'BOARD', 'focus');
      if (event.contains('IOC')) add('VKJ: IOC Selected Qs', 'IOC', 'training');
      if (event.contains('OC')) add('SKM-JA: Organic', 'OC', 'training');
      if (event.contains('PC')) add('NK-JA: Physical', 'PC', 'training');
      if (event.contains('Physics') || event.contains('PHY')) add('Physics: Allen GR Package / HCV', 'PHY', 'training');
      if (event.contains('Math')) add(mathBook, 'MATH', 'training');
    } else if (type == 'TEST') {
      add('$event (Paper Attempt)', 'TEST', 'offline');
      add('Thorough Analysis', 'AUDIT', 'focus');
    } else if (type == 'GRIND' || type == 'PREP') {
      if (!event.contains(':') && !event.contains('/')) {
        add(mathBook, 'MATH', 'training');
        add('Physics: Allen GR Package / HCV', 'PHY', 'training');
        add('NK-JA: Physical Chem', 'PC', 'training');
        add('SKM-JA: Organic', 'OC', 'training');
        add('VKJ: IOC', 'IOC', 'training');
      } else {
        if (event.contains('Math')) add(mathBook, 'MATH', 'training');
        if (event.contains('Physics') || event.contains('PHY')) add('Physics: Allen GR Package / HCV', 'PHY', 'training');
        if (event.contains('IOC')) add('VKJ: IOC', 'IOC', 'training');
        if (event.contains('OC')) add('SKM-JA: Organic', 'OC', 'training');
        if (event.contains('PC')) add('NK-JA: Physical', 'PC', 'training');
      }
    }
    return t;
  }
}

class NetworkService {
  RawDatagramSocket? _udpSocket;
  final NetworkInfo _networkInfo = NetworkInfo();
  String? myIp;
  
  Future<void> start(Function(Map<String, dynamic>) onPacket) async {
    myIp = await _networkInfo.getWifiIP();
    _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, UDP_PORT);
    _udpSocket!.broadcastEnabled = true;
    
    _udpSocket!.listen((RawSocketEvent event) {
      if (event == RawSocketEvent.read) {
        Datagram? dg = _udpSocket!.receive();
        if (dg != null) {
          try {
            String msg = utf8.decode(dg.data);
            var data = jsonDecode(msg);
            // Ignore own packets
            if (data['senderIp'] != myIp) {
              onPacket(data);
            }
          } catch (_) {}
        }
      }
    });
  }

  void broadcast(Map<String, dynamic> data) {
    if (_udpSocket == null || myIp == null) return;
    data['senderIp'] = myIp;
    String msg = jsonEncode(data);
    _udpSocket!.send(utf8.encode(msg), InternetAddress("255.255.255.255"), UDP_PORT);
  }
}

// -----------------------------------------------------------------------------
// STATE MANAGEMENT
// -----------------------------------------------------------------------------

class AppState extends ChangeNotifier {
  final NetworkService _net = NetworkService();
  final NetworkInfo _netInfo = NetworkInfo();
  late SharedPreferences _prefs;
  
  Profile? currentProfile;
  List<Map<String, dynamic>> discoveredProfiles = [];
  
  String currentTheme = 'ghost';
  DateTime selectedDate = DateTime.now();
  String currentSSID = 'Offline';
  String myDeviceId = '';
  
  // HUD State
  Task? activeTask;
  Task? configTask;
  Timer? _hudTimer;
  int hudTime = 0;
  
  // Battery
  double batteryLevel = 1.0;
  bool isCharging = false;
  String drainTime = "CALC...";
  
  // UI
  bool isCommandDeckOpen = false;
  late ConfettiController confettiController;
  
  // Media
  String currentTrack = "NO LINK";
  String currentArtist = "System Idle";

  AppState() {
    _init();
    confettiController = ConfettiController(duration: const Duration(seconds: 3));
  }

  void _init() async {
    _prefs = await SharedPreferences.getInstance();
    WakelockPlus.enable();
    var devInfo = DeviceInfoPlugin();
    var androidInfo = await devInfo.androidInfo;
    myDeviceId = androidInfo.id;
    
    currentTheme = _prefs.getString('theme') ?? 'ghost';
    
    // Battery
    Battery().onBatteryStateChanged.listen((state) {
      isCharging = state == BatteryState.charging || state == BatteryState.full;
      notifyListeners();
    });
    Timer.periodic(const Duration(seconds: 1), (t) async {
      int level = await Battery().batteryLevel;
      batteryLevel = level / 100.0;
      
      // Simulation of drain.sh logic
      if (!isCharging) {
         // Rough estimation: 1% every 4 mins in heavy usage
         int minsLeft = level * 4;
         int h = minsLeft ~/ 60;
         int m = minsLeft % 60;
         drainTime = "${h}:${m.toString().padLeft(2, '0')}";
      } else {
        drainTime = "CHRG";
      }
      notifyListeners();
    });

    // Network & Sync
    _checkNetwork();
    _net.start((packet) {
      if (packet['type'] == 'announce') {
        if (!discoveredProfiles.any((p) => p['id'] == packet['profile']['id'])) {
          discoveredProfiles.add(packet['profile']);
          notifyListeners();
        }
      } else if (packet['type'] == 'sync' && currentProfile != null) {
        if (packet['profileId'] == currentProfile!.id) {
           _mergeProfile(packet['data']);
        }
      } else if (packet['type'] == 'cmd' && currentProfile != null) {
        if (packet['target'] == myDeviceId) {
           _handleRemoteCommand(packet);
        }
      }
    });

    // Announce Loop
    Timer.periodic(const Duration(seconds: 5), (t) {
      if (currentProfile != null) {
        _net.broadcast({'type': 'sync', 'profileId': currentProfile!.id, 'data': currentProfile!.toJson()});
      } else if (currentSSID != 'Offline') {
         // Ask for profiles?
      }
    });
  }

  Future<void> _checkNetwork() async {
    String? ssid = await _netInfo.getWifiName();
    currentSSID = ssid?.replaceAll('"', '') ?? 'Offline';
    
    if (currentProfile != null && currentProfile!.networkSsid != currentSSID) {
      // Logic for network switch could go here
    }
    notifyListeners();
  }

  void _mergeProfile(Map<String, dynamic> remoteJson) {
     // Last Writer Wins / Simple Merge
     Profile remote = Profile.fromJson(remoteJson);
     // If remote has newer logs or tasks, update.
     // For this replica, we just overwrite strictly if we aren't the one editing
     if (activeTask == null) { // Don't overwrite if we are busy
       currentProfile = remote;
       notifyListeners();
     }
  }

  void _handleRemoteCommand(Map<String, dynamic> packet) {
     if (packet['action'] == 'play') {
       _launchMusic(packet['query']);
     }
  }

  // Auth
  void createProfile(String name, String pattern) {
    String hash = pattern; 
    currentProfile = Profile(
      id: const Uuid().v4(), name: name, networkSsid: currentSSID, patternHash: hash,
      tasks: ScheduleService.generateForDate(DateTime.now()),
      musicAnchorId: myDeviceId,
      lastSyncDate: DateFormat('yyyy-MM-dd').format(DateTime.now())
    );
    _saveProfile();
    notifyListeners();
  }

  void joinProfile(Map<String, dynamic> pData, String pattern) {
    if (pData['patternHash'] == pattern) {
      currentProfile = Profile.fromJson(pData); // Initial load
      _saveProfile();
      notifyListeners();
    } else {
      // Vibration.vibrate(pattern: [50, 50, 50]); // Wrong pattern
    }
  }

  void _saveProfile() {
    if (currentProfile != null) {
      _prefs.setString('profile_last', jsonEncode(currentProfile!.toJson()));
      // Broadcast update
      _net.broadcast({'type': 'sync', 'profileId': currentProfile!.id, 'data': currentProfile!.toJson()});
    }
  }

  // Logic
  void changeDate(int days) {
    selectedDate = selectedDate.add(Duration(days: days));
    String dKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    // In real app, check if tasks exist in history, else generate
    // Simplified: regenerate if not today
    if (dKey == DateFormat('yyyy-MM-dd').format(DateTime.now())) {
      // Keep current
    } else {
      currentProfile!.tasks = ScheduleService.generateForDate(selectedDate);
    }
    notifyListeners();
  }

  void toggleTask(String id) {
    var t = currentProfile!.tasks.firstWhere((e) => e.id == id);
    t.isCompleted = !t.isCompleted;
    if (t.isCompleted) {
      if (t.type == 'offline') currentProfile!.coins += 50;
      else currentProfile!.coins += t.coins;
    } else {
       if (t.type == 'offline') currentProfile!.coins -= 50;
       else currentProfile!.coins -= t.coins;
    }
    _saveProfile();
    notifyListeners();
  }

  void startTask(Task t) {
    activeTask = t;
    configTask = null;
    hudTime = t.elapsed;
    _hudTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      hudTime++;
      notifyListeners();
    });
    notifyListeners();
  }

  void finishTask(int correct, int score, int totalQ) {
    _hudTimer?.cancel();
    // Log It
    String dKey = DateFormat('yyyy-MM-dd').format(selectedDate);
    LogEntry log = LogEntry(
      id: DateTime.now().millisecondsSinceEpoch,
      date: dKey,
      type: activeTask!.type,
      duration: hudTime,
      taskName: activeTask!.title,
      questionsTotal: totalQ,
      questionsCorrect: correct,
      marksScored: score
    );
    currentProfile!.logs.add(log);
    
    // Coins
    if (activeTask!.type == 'focus') currentProfile!.coins += (hudTime ~/ 60);
    else currentProfile!.coins += score;
    
    // Update Stats (Hours)
    double prev = currentProfile!.dailyHours[dKey] ?? 0;
    currentProfile!.dailyHours[dKey] = prev + (hudTime / 3600.0);
    
    // Check Target
    double target = kSchedule2026[dKey]?['target']?.toDouble() ?? 5.0;
    if (currentProfile!.dailyHours[dKey]! >= target && prev < target) {
      currentProfile!.coins += 500;
      confettiController.play();
    }
    
    // Mark Done
    var t = currentProfile!.tasks.firstWhere((e) => e.id == activeTask!.id);
    t.isCompleted = true;
    
    activeTask = null;
    _saveProfile();
    notifyListeners();
  }

  void pauseTask(int q, int correct, int score) {
    _hudTimer?.cancel();
    var t = currentProfile!.tasks.firstWhere((e) => e.id == activeTask!.id);
    t.elapsed = hudTime;
    t.lastQ = q;
    t.lastCorrect = correct;
    t.lastScore = score;
    activeTask = null;
    _saveProfile();
    notifyListeners();
  }

  // Music
  void playMusic(String query) {
    currentProfile!.queue.add(Task(id: const Uuid().v4(), title: query, type: 'music'));
    _saveProfile();
    
    if (currentProfile!.musicAnchorId == myDeviceId) {
      _launchMusic(query);
    } else {
      _net.broadcast({'type': 'cmd', 'target': currentProfile!.musicAnchorId, 'action': 'play', 'query': query});
    }
  }

  void _launchMusic(String query) async {
    final AndroidIntent intent = AndroidIntent(
      action: 'android.media.action.MEDIA_PLAY_FROM_SEARCH',
      arguments: {'query': query},
      flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
    );
    try { await intent.launch(); } catch (e) { print(e); }
  }

  void setAnchor() {
    currentProfile!.musicAnchorId = myDeviceId;
    _saveProfile();
    notifyListeners();
  }
}

// -----------------------------------------------------------------------------
// MAIN ENTRY & THEME UI
// -----------------------------------------------------------------------------

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  
  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AppState())],
      child: const JaexoApp(),
    ),
  );
}

class JaexoApp extends StatelessWidget {
  const JaexoApp({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = kThemes[state.currentTheme]!;
    
    // FIX 2: Correct Google Fonts usage (jetBrainsMono)
    final textTheme = GoogleFonts.jetBrainsMonoTextTheme(ThemeData.dark().textTheme).apply(
      bodyColor: theme.primary, displayColor: theme.primary,
    );

    return MaterialApp(
      title: APP_TITLE,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: theme.background,
        colorScheme: theme,
        textTheme: textTheme,
      ),
      home: const GlitchWrapper(child: MainScreen()),
    );
  }
}

// -----------------------------------------------------------------------------
// UI WIDGETS
// -----------------------------------------------------------------------------

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    
    if (state.currentProfile == null) return const AuthScreen();
    if (state.activeTask != null) return const HudScreen();

    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
               // Top Battery Line
               SizedBox(
                 height: 4,
                 child: LinearProgressIndicator(
                   value: state.batteryLevel,
                   backgroundColor: Colors.grey[900],
                   valueColor: AlwaysStoppedAnimation(state.isCharging ? Colors.green : state.batteryLevel < 0.2 ? Colors.red : Theme.of(context).colorScheme.primary),
                 ),
               ),
               _buildHeader(context, state),
               Expanded(
                 child: ListView(
                   padding: const EdgeInsets.all(16),
                   children: [
                     if (state.isCommandDeckOpen) const CommandDeck(),
                     _buildStats(context, state),
                     const SizedBox(height: 10),
                     _buildEventBanner(context, state),
                     _buildPausedTasks(context, state),
                     _buildTaskList(context, state),
                   ],
                 ),
               ),
            ],
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: state.confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              colors: [Theme.of(context).colorScheme.primary, Colors.white],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppState state) {
    final fmt = DateFormat('yyyy-MM-dd');
    final nowStr = fmt.format(DateTime.now());
    final selStr = fmt.format(state.selectedDate);
    final theme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: theme.secondary))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
           Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Text("JAEXO ULTIMATE", style: GoogleFonts.orbitron(fontSize: 20, fontWeight: FontWeight.bold)),
               Row(
                 children: [
                   Text("TIME: ${(state.currentProfile!.dailyHours[selStr] ?? 0).toStringAsFixed(2)}H ", style: const TextStyle(fontSize: 12)),
                   Text("🥇: ${state.currentProfile!.coins}", style: const TextStyle(fontSize: 12, color: Colors.amber)),
                 ],
               ),
             ],
           ),
           Column(
             crossAxisAlignment: CrossAxisAlignment.end,
             children: [
               Text(state.drainTime, style: GoogleFonts.orbitron(color: state.isCharging ? Colors.green : theme.primary)),
               Text(selStr, style: GoogleFonts.orbitron(fontSize: 12, color: theme.secondary)),
               if (selStr != nowStr)
                 GestureDetector(
                   onTap: () => state.changeDate(DateTime.now().difference(state.selectedDate).inDays),
                   child: const Text("[RETURN TO TODAY]", style: TextStyle(fontSize: 10, decoration: TextDecoration.underline)),
                 )
             ],
           )
        ],
      ),
    );
  }
  
  Widget _buildStats(BuildContext context, AppState state) {
     final dKey = DateFormat('yyyy-MM-dd').format(state.selectedDate);
     double h = state.currentProfile!.dailyHours[dKey] ?? 0;
     double target = kSchedule2026[dKey]?['target']?.toDouble() ?? 5.0;
     return LinearProgressIndicator(value: (h/target).clamp(0.0, 1.0), minHeight: 6);
  }

  Widget _buildEventBanner(BuildContext context, AppState state) {
    final dKey = DateFormat('yyyy-MM-dd').format(state.selectedDate);
    final event = kSchedule2026[dKey]?['event'];
    if (event == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      padding: const EdgeInsets.all(8),
      color: Theme.of(context).colorScheme.error.withOpacity(0.2),
      child: Text(event, style: GoogleFonts.orbitron(fontWeight: FontWeight.bold)),
    );
  }
  
  Widget _buildPausedTasks(BuildContext context, AppState state) {
    final paused = state.currentProfile!.tasks.where((t) => t.elapsed > 0 && !t.isCompleted).toList();
    if (paused.isEmpty) return const SizedBox.shrink();
    return Column(
      children: paused.map((t) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(border: Border(left: BorderSide(color: Colors.amber, width: 4)), color: Colors.black54),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("PAUSED: ${t.title}"),
            TextButton(
              onPressed: () => state.startTask(t),
              child: const Text("RESUME", style: TextStyle(color: Colors.amber)),
            )
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildTaskList(BuildContext context, AppState state) {
    return Column(
      children: [
        ...state.currentProfile!.tasks.map((t) => Card(
          color: Colors.black.withOpacity(0.6),
          margin: const EdgeInsets.only(bottom: 6),
          shape: Border.all(color: t.isCompleted ? Colors.grey : Theme.of(context).colorScheme.primary),
          child: ListTile(
            dense: true,
            leading: Checkbox(value: t.isCompleted, onChanged: (v) { Vibration.vibrate(duration: 20); state.toggleTask(t.id); }),
            title: Text(t.title, style: TextStyle(decoration: t.isCompleted ? TextDecoration.lineThrough : null, color: t.isCompleted ? Colors.grey : null)),
            trailing: !t.isCompleted && t.type != 'offline' 
              ? ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.black),
                  onPressed: () {
                    if (t.type == 'training' || t.type == 'online_test') {
                      state.configTask = t;
                      showDialog(context: context, builder: (_) => const ConfigDialog());
                    } else {
                      state.startTask(t);
                    }
                  },
                  child: const Text("ENGAGE"),
                )
              : null,
          ),
        )).toList(),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SummaryScreen())),
          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.black),
          child: Text("I'M DONE TODAY", style: GoogleFonts.orbitron()),
        )
      ],
    );
  }
}

class CommandDeck extends StatelessWidget {
  const CommandDeck({super.key});
  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.primary), color: Colors.black),
      child: Column(
        children: [
          TextField(
            autofocus: true,
            decoration: const InputDecoration(hintText: "COMMAND OR MUSIC...", border: InputBorder.none),
            onSubmitted: (v) {
              if (v == '/anchor') state.setAnchor();
              else state.playMusic(v);
            },
          ),
          Wrap(
            spacing: 5,
            children: kThemes.keys.map((k) => ActionChip(
               label: Text(k), backgroundColor: Colors.black, side: BorderSide(color: kThemes[k]!.primary),
               labelStyle: TextStyle(color: kThemes[k]!.primary),
               onPressed: () { state.currentTheme = k; state._prefs.setString('theme', k); state.notifyListeners(); }
            )).toList(),
          ),
          const SizedBox(height: 5),
          Text("ANCHOR: ${state.currentProfile!.musicAnchorId.substring(0,4)}..."),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// HUD (ACTIVE SESSION)
// -----------------------------------------------------------------------------

class HudScreen extends StatefulWidget {
  const HudScreen({super.key});
  @override
  State<HudScreen> createState() => _HudScreenState();
}

class _HudScreenState extends State<HudScreen> {
  int qIdx = 1;
  int correct = 0;
  int score = 0;

  @override
  void initState() {
    super.initState();
    final t = context.read<AppState>().activeTask!;
    qIdx = t.lastQ > 0 ? t.lastQ : 1;
    correct = t.lastCorrect;
    score = t.lastScore;
  }

  void answer(int delta, bool isCorrect, bool next) {
    Vibration.vibrate(duration: 40);
    setState(() {
      score += delta;
      if (isCorrect) correct++;
      if (next) qIdx++;
    });
    
    final t = context.read<AppState>().activeTask!;
    if (t.type == 'training' && qIdx > t.problems) {
      context.read<AppState>().finishTask(correct, score, t.problems);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final task = state.activeTask!;
    final timeStr = Duration(seconds: state.hudTime).toString().split('.').first.padLeft(8, '0');

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             Text(task.type.toUpperCase(), style: const TextStyle(letterSpacing: 4, color: Colors.grey)),
             Text(timeStr, style: GoogleFonts.jetBrainsMono(fontSize: 60, fontWeight: FontWeight.bold)),
             if (task.type == 'training')
               Text("Q_$qIdx | SCR: $score", style: GoogleFonts.orbitron(fontSize: 24, color: score < 0 ? Colors.red : Colors.green)),
             const SizedBox(height: 20),
             Text(task.title, style: const TextStyle(fontSize: 18), textAlign: TextAlign.center),
             const SizedBox(height: 40),
             if (task.type == 'training') ...[
               Row(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   _hudBtn("CORRECT (+4)", Colors.green, () => answer(4, true, true)),
                   const SizedBox(width: 10),
                   _hudBtn("RETRY (-1)", Colors.red, () => answer(-1, false, false)),
                 ],
               ),
               const SizedBox(height: 10),
               _hudBtn("SKIP (0)", Colors.grey, () => answer(0, false, true)),
             ] else 
               _hudBtn("TERMINATE SESSION", Colors.white, () => state.finishTask(0, state.hudTime ~/ 60, 0)),
             
             const SizedBox(height: 20),
             TextButton(
               onPressed: () => state.pauseTask(qIdx, correct, score),
               child: const Text("TAKE BREAK (SAVE)", style: TextStyle(color: Colors.amber)),
             )
          ],
        ),
      ),
    );
  }

  Widget _hudBtn(String txt, Color color, VoidCallback onTap) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(side: BorderSide(color: color), foregroundColor: color, padding: const EdgeInsets.all(20)),
      onPressed: onTap,
      child: Text(txt, style: GoogleFonts.orbitron(fontWeight: FontWeight.bold)),
    );
  }
}

class ConfigDialog extends StatefulWidget {
  const ConfigDialog({super.key});
  @override
  State<ConfigDialog> createState() => _ConfigDialogState();
}

class _ConfigDialogState extends State<ConfigDialog> {
  int problems = 15;
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.black,
      title: Text("CONFIG", style: GoogleFonts.orbitron()),
      content: TextField(
        keyboardType: TextInputType.number,
        decoration: const InputDecoration(labelText: "Question Count"),
        onChanged: (v) => problems = int.tryParse(v) ?? 15,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("CANCEL")),
        ElevatedButton(
          onPressed: () {
            context.read<AppState>().configTask!.problems = problems;
            context.read<AppState>().startTask(context.read<AppState>().configTask!);
            Navigator.pop(context);
          }, 
          child: const Text("ENGAGE")
        )
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// SUMMARY SCREEN
// -----------------------------------------------------------------------------

class SummaryScreen extends StatelessWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final dKey = DateFormat('yyyy-MM-dd').format(state.selectedDate);
    double h = state.currentProfile!.dailyHours[dKey] ?? 0;
    
    // Graph Data
    List<FlSpot> spots = [];
    int i = 0;
    var sortedKeys = state.currentProfile!.dailyHours.keys.toList()..sort();
    for (var k in sortedKeys) {
      spots.add(FlSpot(i.toDouble(), state.currentProfile!.dailyHours[k]!));
      i++;
    }

    return Scaffold(
      appBar: AppBar(title: const Text("MISSION REPORT"), backgroundColor: Colors.transparent),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
             Text("TIME: ${h.toStringAsFixed(2)}h", style: GoogleFonts.orbitron(fontSize: 30)),
             const SizedBox(height: 20),
             SizedBox(
               height: 200,
               child: LineChart(
                 LineChartData(
                   gridData: FlGridData(show: false),
                   titlesData: FlTitlesData(show: false),
                   borderData: FlBorderData(show: true, border: Border.all(color: Theme.of(context).colorScheme.primary)),
                   lineBarsData: [
                     LineChartBarData(spots: spots, isCurved: true, color: Theme.of(context).colorScheme.primary, dotData: FlDotData(show: false), belowBarData: BarAreaData(show: true, color: Theme.of(context).colorScheme.primary.withOpacity(0.2)))
                   ]
                 )
               ),
             ),
             const Spacer(),
             ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text("RETURN TO BASE"))
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// AUTH SCREEN
// -----------------------------------------------------------------------------

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  List<int> pattern = [];
  bool creating = false;
  String name = "User";

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("JAEXO ULTIMATE", style: GoogleFonts.orbitron(fontSize: 32)),
            Text("NET: ${state.currentSSID}", style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),
            
            if (creating) TextField(
               textAlign: TextAlign.center,
               onChanged: (v) => name = v,
               decoration: const InputDecoration(hintText: "ENTER CODENAME"),
            )
            else if (state.discoveredProfiles.isNotEmpty)
               Column(children: state.discoveredProfiles.map((p) => TextButton(
                 onPressed: () { /* Select profile logic if multiple */ },
                 child: Text("FOUND: ${p['name']} (Enter Pattern)")
               )).toList()),
               
            const SizedBox(height: 20),
            Container(
              width: 300, height: 300, color: Colors.black,
              child: GestureDetector(
                onPanUpdate: (d) => _addDot(d.localPosition),
                onPanEnd: (_) => _submit(state),
                child: CustomPaint(painter: PatternPainter(pattern, Theme.of(context).colorScheme.primary)),
              ),
            ),
            TextButton(
              onPressed: () => setState(() => creating = !creating), 
              child: Text(creating ? "CANCEL" : "CREATE NEW IDENTITY")
            )
          ],
        ),
      ),
    );
  }

  void _addDot(Offset local) {
    int col = (local.dx / 100).floor();
    int row = (local.dy / 100).floor();
    if (col >= 0 && col < 3 && row >= 0 && row < 3) {
      int idx = row * 3 + col;
      if (!pattern.contains(idx)) {
        setState(() => pattern.add(idx));
        Vibration.vibrate(duration: 20);
      }
    }
  }

  void _submit(AppState state) {
    String pStr = pattern.join("-");
    if (pattern.length < 4) { setState(() => pattern = []); return; }
    
    if (creating) {
      state.createProfile(name, pStr);
    } else if (state.discoveredProfiles.isNotEmpty) {
      state.joinProfile(state.discoveredProfiles.first, pStr);
    } else {
       // Auto-create local if none found
       state.createProfile("Commander", pStr);
    }
    setState(() => pattern = []);
  }
}

class PatternPainter extends CustomPainter {
  final List<int> p;
  final Color c;
  PatternPainter(this.p, this.c);
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = c..strokeWidth = 4..style = PaintingStyle.stroke;
    final dot = Paint()..color = c..style = PaintingStyle.fill;
    for (int i=0; i<9; i++) canvas.drawCircle(Offset((i%3)*100.0+50, (i~/3)*100.0+50), 5, dot);
    if (p.isNotEmpty) {
      Path path = Path();
      for (int i=0; i<p.length; i++) {
        double x = (p[i]%3)*100.0+50;
        double y = (p[i]~/3)*100.0+50;
        if (i==0) path.moveTo(x, y); else path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);
    }
  }
  @override
  bool shouldRepaint(old) => true;
}

class GlitchWrapper extends StatefulWidget {
  final Widget child;
  const GlitchWrapper({super.key, required this.child});
  @override
  State<GlitchWrapper> createState() => _GlitchWrapperState();
}

class _GlitchWrapperState extends State<GlitchWrapper> {
  double dx=0, dy=0;
  @override
  void initState() {
    super.initState();
    Timer.periodic(const Duration(seconds: 60), (t) async {
       for(int i=0;i<5;i++) {
         setState(() { dx = Random().nextDouble()*4-2; dy = Random().nextDouble()*4-2; });
         await Future.delayed(const Duration(milliseconds: 50));
       }
       setState(() { dx=0; dy=0; });
    });
  }
  @override
  Widget build(BuildContext context) => Transform.translate(offset: Offset(dx, dy), child: widget.child);
}