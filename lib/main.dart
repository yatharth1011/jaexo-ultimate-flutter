import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:android_intent_plus/android_intent_plus.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:confetti/confetti.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:vibration/vibration.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

// -----------------------------------------------------------------------------
// CONSTANTS & CONFIGURATION
// -----------------------------------------------------------------------------

const int UDP_PORT = 4545;
const String APP_TITLE = "JAEXO ULTIMATE";

// Colors (Themes)
final Map<String, ColorScheme> kThemes = {
  'matrix': const ColorScheme.dark(
      primary: Color(0xFF00FF41), surface: Colors.black, background: Colors.black),
  'redline': const ColorScheme.dark(
      primary: Color(0xFFFF0000), surface: Color(0xFF1A0000), background: Colors.black),
  'deepspace': const ColorScheme.dark(
      primary: Color(0xFF00BFFF), surface: Color(0xFF001133), background: Colors.black),
  'amber': const ColorScheme.dark(
      primary: Color(0xFFFFBF00), surface: Color(0xFF221100), background: Colors.black),
  'ghost': const ColorScheme.dark( // Default
      primary: Color(0xFFE0E0E0), surface: Color(0xFF121212), background: Colors.black),
};

// -----------------------------------------------------------------------------
// MODELS
// -----------------------------------------------------------------------------

class Task {
  String id;
  String title;
  bool isCompleted;
  int coins;
  String type; // 'focus', 'offline', 'online'

  Task({
    required this.id,
    required this.title,
    this.isCompleted = false,
    this.coins = 0,
    this.type = 'focus',
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'isCompleted': isCompleted,
        'coins': coins,
        'type': type,
      };

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        id: json['id'],
        title: json['title'],
        isCompleted: json['isCompleted'],
        coins: json['coins'],
        type: json['type'],
      );
}

class Profile {
  String id;
  String name;
  String networkSsid; // "Daughter of the network"
  String patternHash; // SHA-256 hash of the pattern string "0-1-2..."
  int coins;
  int targetHours;
  Map<String, int> dailyStudyMinutes; // Date string -> minutes
  List<Task> queue;
  String musicAnchorId; // Device ID of current anchor
  
  // Local state not synced identically but derived
  List<Task> tasks; 

  Profile({
    required this.id,
    required this.name,
    required this.networkSsid,
    required this.patternHash,
    this.coins = 0,
    this.targetHours = 8,
    this.dailyStudyMinutes = const {},
    this.queue = const [],
    this.musicAnchorId = '',
    this.tasks = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'networkSsid': networkSsid,
        'patternHash': patternHash,
        'coins': coins,
        'targetHours': targetHours,
        'dailyStudyMinutes': dailyStudyMinutes,
        'queue': queue.map((e) => e.toJson()).toList(),
        'musicAnchorId': musicAnchorId,
        'tasks': tasks.map((e) => e.toJson()).toList(),
      };

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        id: json['id'],
        name: json['name'],
        networkSsid: json['networkSsid'],
        patternHash: json['patternHash'],
        coins: json['coins'],
        targetHours: json['targetHours'],
        dailyStudyMinutes: Map<String, int>.from(json['dailyStudyMinutes'] ?? {}),
        queue: (json['queue'] as List).map((e) => Task.fromJson(e)).toList(),
        musicAnchorId: json['musicAnchorId'] ?? '',
        tasks: (json['tasks'] as List).map((e) => Task.fromJson(e)).toList(),
      );
}

// -----------------------------------------------------------------------------
// SERVICES
// -----------------------------------------------------------------------------

// Mimics the Schedule Generator
class ScheduleService {
  static List<Task> getTasksForDate(DateTime date) {
    // Hardcoded logic simulation for 2026/Current structure
    // Logic: Subject rotates based on day of week
    List<String> subjects = ['Math', 'Physics', 'Coding', 'System Design', 'AI'];
    String subject = subjects[date.day % subjects.length];
    
    return [
      Task(id: const Uuid().v4(), title: 'Morning Review: $subject', coins: 50, type: 'focus'),
      Task(id: const Uuid().v4(), title: 'Deep Work: $subject', coins: 100, type: 'focus'),
      Task(id: const Uuid().v4(), title: 'System Maintenance', coins: 30, type: 'offline'),
      Task(id: const Uuid().v4(), title: 'Nightly Sync', coins: 20, type: 'offline'),
    ];
  }
}

class NetworkService {
  RawDatagramSocket? _udpSocket;
  final NetworkInfo _networkInfo = NetworkInfo();
  final String deviceId = const Uuid().v4();
  
  // Discovery
  Future<void> startDiscovery(Function(Map<String, dynamic>) onProfileFound) async {
    _udpSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, UDP_PORT);
    _udpSocket!.broadcastEnabled = true;
    
    _udpSocket!.listen((RawSocketEvent event) {
      if (event == RawSocketEvent.read) {
        Datagram? dg = _udpSocket!.receive();
        if (dg != null) {
          String message = utf8.decode(dg.data);
          try {
            var data = jsonDecode(message);
            if (data['type'] == 'announce' && data['deviceId'] != deviceId) {
              onProfileFound(data);
            }
          } catch (_) {}
        }
      }
    });
  }

  void announceProfile(Profile profile) {
    if (_udpSocket == null) return;
    String msg = jsonEncode({
      'type': 'announce',
      'deviceId': deviceId,
      'profileId': profile.id,
      'name': profile.name,
      'ssid': profile.networkSsid,
      'ip': '0.0.0.0' // In real impl, fetch local IP
    });
    _udpSocket!.send(utf8.encode(msg), InternetAddress("255.255.255.255"), UDP_PORT);
  }

  // Simplified Sync: We are just simulating the logic of sending state to peers via UDP for this single-file demo
  // In a real production app, you'd use TCP sockets or WebSockets.
  void broadcastState(Profile profile) {
    if (_udpSocket == null) return;
    // Chunking omitted for brevity, assuming small profile size for demo
    String msg = jsonEncode({
      'type': 'sync',
      'deviceId': deviceId,
      'payload': profile.toJson()
    });
     _udpSocket!.send(utf8.encode(msg), InternetAddress("255.255.255.255"), UDP_PORT);
  }
}

// -----------------------------------------------------------------------------
// STATE MANAGEMENT (PROVIDER)
// -----------------------------------------------------------------------------

class AppState extends ChangeNotifier {
  // Services
  final NetworkInfo _netInfo = NetworkInfo();
  late SharedPreferences _prefs;
  
  // Data
  Profile? currentProfile;
  List<Map<String, dynamic>> discoveredProfiles = [];
  String currentTheme = 'ghost';
  DateTime selectedDate = DateTime.now();
  String currentSSID = 'Unknown';
  String myDeviceId = const Uuid().v4();
  
  // UI State
  bool isCommandDeckOpen = false;
  bool isTrainingMode = false;
  double batteryLevel = 1.0;
  bool isCharging = false;
  String? musicQuery;
  
  // Confetti
  late ConfettiController confettiController;

  AppState() {
    _init();
    confettiController = ConfettiController(duration: const Duration(seconds: 3));
  }

  void _init() async {
    _prefs = await SharedPreferences.getInstance();
    WakelockPlus.enable();
    
    // Theme
    currentTheme = _prefs.getString('theme') ?? 'ghost';
    
    // Battery
    Battery().onBatteryStateChanged.listen((BatteryState state) {
      isCharging = state == BatteryState.charging || state == BatteryState.full;
      notifyListeners();
    });
    Timer.periodic(const Duration(minutes: 1), (timer) async {
      batteryLevel = (await Battery().batteryLevel) / 100.0;
      notifyListeners();
    });

    // Network Check
    _checkNetwork();
    
    // Glitch Timer
    Timer.periodic(const Duration(seconds: 60), (t) {
      notifyListeners(); // Triggers rebuild for glitch
    });
  }

  Future<void> _checkNetwork() async {
    String? ssid = await _netInfo.getWifiName();
    currentSSID = ssid?.replaceAll('"', '') ?? 'Offline';
    
    // If we have a profile, check if it matches network
    if (currentProfile != null && currentProfile!.networkSsid != currentSSID) {
      // Disconnected logic: Keep local but warn user or save pending
    }
    notifyListeners();
  }

  // Profile Management
  void createProfile(String name, String pattern) {
    String hash = pattern; // In real app, use crypto hash
    currentProfile = Profile(
      id: const Uuid().v4(),
      name: name,
      networkSsid: currentSSID,
      patternHash: hash,
      tasks: ScheduleService.getTasksForDate(DateTime.now()),
      musicAnchorId: myDeviceId, // Creator is first anchor
    );
    _saveProfile();
    notifyListeners();
  }

  void joinProfile(Map<String, dynamic> discoveryData, String pattern) {
    // pattern verification logic
    // Request full sync
  }

  void _saveProfile() {
    if (currentProfile != null) {
      _prefs.setString('profile_${currentProfile!.id}', jsonEncode(currentProfile!.toJson()));
    }
  }

  // Task Logic
  void toggleTask(String taskId) {
    if (currentProfile == null) return;
    var t = currentProfile!.tasks.firstWhere((e) => e.id == taskId);
    t.isCompleted = !t.isCompleted;
    if (t.isCompleted) {
      currentProfile!.coins += t.coins;
      // Add time logic
      String todayKey = DateFormat('yyyy-MM-dd').format(DateTime.now());
      currentProfile!.dailyStudyMinutes[todayKey] = (currentProfile!.dailyStudyMinutes[todayKey] ?? 0) + 30; // Mock time
      
      // Check target
      int totalMins = currentProfile!.dailyStudyMinutes[todayKey] ?? 0;
      if (totalMins >= currentProfile!.targetHours * 60) {
        currentProfile!.coins += 500;
        confettiController.play();
      }
    } else {
      currentProfile!.coins -= t.coins;
    }
    _saveProfile();
    notifyListeners();
  }

  // Date Nav
  void changeDate(int days) {
    selectedDate = selectedDate.add(Duration(days: days));
    // Load tasks for date
    if (currentProfile != null) {
       // In a real app, load from DB. Here we regenerate.
       currentProfile!.tasks = ScheduleService.getTasksForDate(selectedDate);
    }
    notifyListeners();
  }

  // Music Logic
  Future<void> playMusic(String query) async {
    if (currentProfile == null) return;
    
    // Add to queue
    currentProfile!.queue.add(Task(id: const Uuid().v4(), title: query, type: 'music'));
    
    if (currentProfile!.musicAnchorId == myDeviceId) {
      // I am anchor, launch intent
      final AndroidIntent intent = AndroidIntent(
        action: 'android.media.action.MEDIA_PLAY_FROM_SEARCH',
        arguments: {'query': query},
        flags: [Flag.FLAG_ACTIVITY_NEW_TASK],
      );
      try {
        await intent.launch();
      } catch (e) {
        print("Error launching music: $e");
      }
    } else {
      // Send command to anchor (Simulated via UDP in real app)
    }
    notifyListeners();
  }
  
  void becomeAnchor() {
    if (currentProfile != null) {
      currentProfile!.musicAnchorId = myDeviceId;
      notifyListeners();
    }
  }

  void setTheme(String theme) {
    currentTheme = theme;
    _prefs.setString('theme', theme);
    notifyListeners();
  }
}

// -----------------------------------------------------------------------------
// MAIN ENTRY POINT
// -----------------------------------------------------------------------------

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
      ],
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

    // Glitch Effect Setup
    return MaterialApp(
      title: APP_TITLE,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: theme.background,
        colorScheme: theme,
        textTheme: GoogleFonts.jetbrainsMonoTextTheme(ThemeData.dark().textTheme).apply(
          bodyColor: theme.primary,
          displayColor: theme.primary,
        ),
      ),
      home: const GlitchWrapper(child: MainScreen()),
    );
  }
}

// -----------------------------------------------------------------------------
// UI COMPONENTS
// -----------------------------------------------------------------------------

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    
    // Auth Check
    if (state.currentProfile == null) {
      return const AuthScreen();
    }

    return Scaffold(
      body: Stack(
        children: [
          // Content
          Column(
            children: [
              const SizedBox(height: 20), // Space for battery bar
              // Header
              _buildHeader(context, state),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (state.isCommandDeckOpen) const CommandDeck(),
                    const SizedBox(height: 10),
                    _buildStats(state),
                    const SizedBox(height: 20),
                    _buildTaskList(context, state),
                    const SizedBox(height: 20),
                    if (state.currentProfile!.queue.isNotEmpty) _buildMusicQueue(state),
                  ],
                ),
              ),
            ],
          ),
          
          // Battery Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 4,
            child: LinearProgressIndicator(
              value: state.batteryLevel,
              backgroundColor: Colors.grey[900],
              valueColor: AlwaysStoppedAnimation(state.isCharging ? Colors.green : state.batteryLevel < 0.2 ? Colors.red : Theme.of(context).colorScheme.primary),
            ),
          ),
          
          // Confetti
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
    final isToday = nowStr == selStr;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Theme.of(context).colorScheme.primary.withOpacity(0.5))),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(state.currentProfile!.name.toUpperCase(), style: GoogleFonts.orbitron(fontSize: 12)),
              Row(
                children: [
                  const Icon(Icons.monetization_on, size: 14),
                  const SizedBox(width: 4),
                  Text("${state.currentProfile!.coins}", style: GoogleFonts.orbitron(fontWeight: FontWeight.bold)),
                ],
              )
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(icon: const Icon(Icons.arrow_left), onPressed: () => state.changeDate(-1)),
              Text(selStr, style: GoogleFonts.orbitron(fontSize: 24, fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.arrow_right), onPressed: () => state.changeDate(1)),
            ],
          ),
          if (!isToday)
            InkWell(
              onTap: () => state.changeDate(DateTime.now().difference(state.selectedDate).inDays),
              child: Text("RETURN TO TODAY", style: const TextStyle(fontSize: 10, decoration: TextDecoration.underline)),
            ),
        ],
      ),
    );
  }

  Widget _buildStats(AppState state) {
    String todayKey = DateFormat('yyyy-MM-dd').format(state.selectedDate);
    int mins = state.currentProfile!.dailyStudyMinutes[todayKey] ?? 0;
    double hours = mins / 60.0;
    double target = state.currentProfile!.targetHours.toDouble();
    double percent = (hours / target).clamp(0.0, 1.0);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("FOCUS: ${hours.toStringAsFixed(1)} / $target H", style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              LinearProgressIndicator(value: percent),
            ],
          ),
        ),
        if (hours >= target) 
          const Padding(padding: EdgeInsets.only(left: 10), child: Text("🏆", style: TextStyle(fontSize: 24))),
      ],
    );
  }

  Widget _buildTaskList(BuildContext context, AppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("TASKS", style: GoogleFonts.orbitron(fontSize: 18)),
        const SizedBox(height: 10),
        ...state.currentProfile!.tasks.map((task) {
          return Card(
            color: Colors.black.withOpacity(0.5),
            shape: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
            child: ListTile(
              leading: Checkbox(
                value: task.isCompleted,
                onChanged: (v) {
                   Vibration.vibrate(duration: 50);
                   state.toggleTask(task.id);
                },
                activeColor: Theme.of(context).colorScheme.primary,
              ),
              title: Text(task.title, style: TextStyle(
                decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                color: task.isCompleted ? Colors.grey : Theme.of(context).colorScheme.primary,
              )),
              trailing: Text("+${task.coins}"),
            ),
          );
        }).toList(),
        
        // Summary Button
        const SizedBox(height: 20),
        if (state.currentProfile!.tasks.every((t) => t.isCompleted))
        Center(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.black),
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SummaryScreen()));
            }, 
            child: Text("I'M DONE TODAY", style: GoogleFonts.orbitron(fontWeight: FontWeight.bold)),
          ),
        )
      ],
    );
  }
  
  Widget _buildMusicQueue(AppState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("QUEUE [ANCHOR: ${state.currentProfile!.musicAnchorId.substring(0,4)}...]", style: GoogleFonts.orbitron(fontSize: 14)),
        Container(
          height: 100,
          color: Colors.black26,
          child: ListView.builder(
            itemCount: state.currentProfile!.queue.length,
            itemBuilder: (c, i) => Padding(
              padding: const EdgeInsets.all(4.0),
              child: Text("${i+1}. ${state.currentProfile!.queue[i].title}", style: const TextStyle(fontSize: 12)),
            ),
          ),
        )
      ],
    );
  }
}

class CommandDeck extends StatefulWidget {
  const CommandDeck({super.key});
  @override
  State<CommandDeck> createState() => _CommandDeckState();
}

class _CommandDeckState extends State<CommandDeck> {
  final TextEditingController _ctrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(border: Border.all(color: Theme.of(context).colorScheme.primary)),
      child: Column(
        children: [
          TextField(
            controller: _ctrl,
            autofocus: true,
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
            decoration: const InputDecoration(
              hintText: "COMMAND OR MUSIC SEARCH...",
              border: InputBorder.none,
            ),
            onSubmitted: (val) {
              if (val.startsWith("/")) {
                // Command processing
                if (val == "/anchor") state.becomeAnchor();
                // Themes
                if (val.startsWith("/theme ")) state.setTheme(val.split(" ")[1]);
              } else {
                // Music
                state.playMusic(val);
              }
              _ctrl.clear();
            },
          ),
          Wrap(
            spacing: 5,
            children: kThemes.keys.map((k) => ActionChip(
              label: Text(k),
              onPressed: () => state.setTheme(k),
              backgroundColor: Colors.black,
              labelStyle: TextStyle(color: kThemes[k]!.primary),
              side: BorderSide(color: kThemes[k]!.primary),
            )).toList(),
          )
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// AUTH & PATTERN LOCK
// -----------------------------------------------------------------------------

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  List<int> pattern = [];
  bool isCreating = false;
  String name = "User";

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("JAEXO ULTIMATE", style: GoogleFonts.orbitron(fontSize: 32, color: Colors.white)),
            const SizedBox(height: 10),
            Text("NETWORK: ${state.currentSSID}", style: GoogleFonts.jetbrainsMono(color: Colors.grey)),
            const SizedBox(height: 50),
            if (isCreating) 
              Padding(
                padding: const EdgeInsets.all(20),
                child: TextField(
                  decoration: const InputDecoration(hintText: "ENTER PROFILE NAME"),
                  onChanged: (v) => name = v,
                ),
              ),
            
            Text(isCreating ? "SET PATTERN" : "ENTER PATTERN TO JOIN/CREATE", style: GoogleFonts.orbitron()),
            const SizedBox(height: 20),
            
            // Pattern Lock Widget
            Container(
              width: 300,
              height: 300,
              color: Colors.black,
              child: GestureDetector(
                onPanStart: (d) => _addPoint(d.localPosition),
                onPanUpdate: (d) => _addPoint(d.localPosition),
                onPanEnd: (d) => _finishPattern(state),
                child: CustomPaint(
                  painter: PatternPainter(pattern, Colors.white),
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => setState(() => isCreating = !isCreating),
              child: Text(isCreating ? "CANCEL" : "CREATE NEW PROFILE"),
            )
          ],
        ),
      ),
    );
  }

  void _addPoint(Offset local) {
    // Determine which dot (0-8) is touched based on 3x3 grid in 300x300 box
    int col = (local.dx / 100).floor();
    int row = (local.dy / 100).floor();
    if (col >= 0 && col < 3 && row >= 0 && row < 3) {
      int index = row * 3 + col;
      if (!pattern.contains(index)) {
        setState(() {
          pattern.add(index);
        });
        Vibration.vibrate(duration: 20);
      }
    }
  }

  void _finishPattern(AppState state) {
    String pStr = pattern.join("-");
    if (pattern.length < 4) {
      setState(() => pattern = []);
      return;
    }

    if (isCreating) {
      state.createProfile(name, pStr);
    } else {
      // Logic to check existing profiles
      // For this demo, we just create/login as if it's the same
      state.createProfile("Existing", pStr);
    }
    setState(() => pattern = []);
  }
}

class PatternPainter extends CustomPainter {
  final List<int> pattern;
  final Color color;
  PatternPainter(this.pattern, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 5..style = PaintingStyle.stroke;
    final dotPaint = Paint()..color = color..style = PaintingStyle.fill;

    // Draw dots
    for (int i = 0; i < 9; i++) {
      double x = (i % 3) * 100.0 + 50;
      double y = (i ~/ 3) * 100.0 + 50;
      canvas.drawCircle(Offset(x, y), 5, dotPaint);
    }

    // Draw lines
    if (pattern.isNotEmpty) {
      Path path = Path();
      for (int i = 0; i < pattern.length; i++) {
        int idx = pattern[i];
        double x = (idx % 3) * 100.0 + 50;
        double y = (idx ~/ 3) * 100.0 + 50;
        if (i == 0) path.moveTo(x, y);
        else path.lineTo(x, y);
      }
      canvas.drawPath(path, paint);
    }
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// -----------------------------------------------------------------------------
// SUMMARY & GRAPH
// -----------------------------------------------------------------------------

class SummaryScreen extends StatelessWidget {
  const SummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    
    // Convert history map to spots
    List<FlSpot> spots = [];
    int index = 0;
    state.currentProfile!.dailyStudyMinutes.forEach((k, v) {
      spots.add(FlSpot(index.toDouble(), v / 60.0));
      index++;
    });

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("I'M DONE TODAY", style: GoogleFonts.orbitron(fontSize: 30, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Text("+500 COINS BONUS", style: const TextStyle(color: Colors.yellow)),
              const SizedBox(height: 40),
              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: false),
                    titlesData: FlTitlesData(show: false),
                    borderData: FlBorderData(show: true, border: Border.all(color: Theme.of(context).colorScheme.primary)),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots.isEmpty ? [const FlSpot(0,0)] : spots,
                        isCurved: true,
                        color: Theme.of(context).colorScheme.primary,
                        barWidth: 3,
                        dotData: FlDotData(show: true),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("CLOSE"),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// UTILS
// -----------------------------------------------------------------------------

class GlitchWrapper extends StatefulWidget {
  final Widget child;
  const GlitchWrapper({super.key, required this.child});
  @override
  State<GlitchWrapper> createState() => _GlitchWrapperState();
}

class _GlitchWrapperState extends State<GlitchWrapper> {
  Timer? _timer;
  double _x = 0;
  double _y = 0;
  
  @override
  void initState() {
    super.initState();
    // Random glitch every 60s approx
    _timer = Timer.periodic(const Duration(seconds: 5), (t) {
      if (Random().nextInt(12) == 0) { // Approx once a minute
        _triggerGlitch();
      }
    });
  }

  void _triggerGlitch() async {
    for (int i=0; i<5; i++) {
      setState(() {
        _x = Random().nextDouble() * 4 - 2;
        _y = Random().nextDouble() * 4 - 2;
      });
      await Future.delayed(const Duration(milliseconds: 50));
    }
    setState(() { _x=0; _y=0; });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: Offset(_x, _y),
      child: widget.child,
    );
  }
}