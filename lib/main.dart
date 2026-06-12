import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ads/appodeal_ads.dart';
import 'coins/coin_store.dart';
import 'screens/game_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  await CoinStore.load();
  await AppodealAds.initialize(
    appKey: '93c9e1c0382888f75cd8022c18b116efe68a375ffe933ed7',
    testing: false,
    verboseLogs: false,
  );
  await AppodealAds.loadAndShowConsentIfRequired();
  runApp(const MovingBrickApp());
}

class MovingBrickApp extends StatelessWidget {
  const MovingBrickApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Moving Brick',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE65100),
          brightness: Brightness.dark,
          primary: const Color(0xFFE65100),
          secondary: const Color(0xFFFFB74D),
        ),
        useMaterial3: true,
      ),
      home: const GameScreen(),
    );
  }
}
