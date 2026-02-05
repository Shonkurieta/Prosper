import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:prosper/providers/theme_provider.dart';
import 'package:prosper/providers/font_provider.dart';
// Экраны
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/library/library_screen.dart';
import 'screens/admin/admin_main_screen.dart';
import 'screens/bookmarks/bookmarks_screen.dart';
import 'screens/user/user_home.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Загружаем .env если он есть, иначе игнорируем
  try {
    await dotenv.load(fileName: ".env");
    print('✅ .env загружен успешно');
  } catch (e) {
    print('⚠️ .env файл не найден, используем значения по умолчанию из ApiConstants');
  }
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => FontProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? token;
  String? role;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserSession();
  }

  Future<void> _loadUserSession() async {
    print('🔄 Загружаем сессию пользователя...');
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('token');
    final savedRole = prefs.getString('role');
    
    print('🔑 Token: ${savedToken != null ? "найден" : "отсутствует"}');
    print('👤 Role: $savedRole');
    
    setState(() {
      token = savedToken;
      role = savedRole;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Определяем стартовый экран
    Widget startScreen;
    if (token != null && role != null) {
      if (role == 'ADMIN') {
        print('🔐 Авторизован как ADMIN');
        startScreen = AdminMainScreen(token: token!);
      } else {
        print('🔐 Авторизован как USER');
        startScreen = UserHome(token: token!);
      }
    } else {
      print('🔓 Не авторизован, показываем LoginScreen');
      startScreen = const LoginScreen();
    }

    return Consumer<ThemeProvider>(
      builder: (context, theme, child) {
        if (isLoading) {
          return MaterialApp(
            home: Scaffold(
              backgroundColor: theme.backgroundColor,
              body: Center(
                child: CircularProgressIndicator(
                  color: theme.primaryColor,
                ),
              ),
            ),
          );
        }

        return MaterialApp(
          title: 'Prosper',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            scaffoldBackgroundColor: theme.backgroundColor,
            colorScheme: ColorScheme.fromSeed(
              seedColor: theme.primaryColor,
              brightness: theme.isDarkMode ? Brightness.dark : Brightness.light,
            ),
          ),
          home: startScreen,
          routes: {
            '/login': (_) => const LoginScreen(),
            '/register': (_) => const RegisterScreen(),
            '/home': (_) => LibraryScreen(token: token ?? ''),
            '/admin': (_) => AdminMainScreen(token: token ?? ''),
            '/bookmarks': (_) => BookmarksScreen(token: token ?? ''),
          },
        );
      },
    );
  }
}