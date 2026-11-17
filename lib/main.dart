import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'library.dart';
import 'pages.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.arvirmdn.vycustic.audio',
    androidNotificationChannelName: 'Pemutaran Vycustic',
    androidNotificationOngoing: true,
  );
  await Library.I.load();
  runApp(const VycusticApp());
}

class VycusticApp extends StatelessWidget {
  const VycusticApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vycustic',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: kBg,
        colorScheme: const ColorScheme.dark(
          primary: kAccent,
          onPrimary: Colors.black,
          surface: kBg,
        ),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: IndexedStack(
          index: tab,
          children: const [SearchPage(), FavoritesPage(), PlaylistsPage()],
        ),
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const MiniPlayer(),
          NavigationBar(
            backgroundColor: kSurface,
            indicatorColor: kAccentSoft,
            selectedIndex: tab,
            onDestinationSelected: (i) => setState(() => tab = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.search), label: 'Cari'),
              NavigationDestination(icon: Icon(Icons.favorite_border), label: 'Favorit'),
              NavigationDestination(icon: Icon(Icons.queue_music), label: 'Playlist'),
            ],
          ),
        ],
      ),
    );
  }
}
