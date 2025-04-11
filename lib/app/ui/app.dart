import 'package:flutter/material.dart';
import 'package:nemoai/app/routes/routes.dart';
import 'package:provider/provider.dart';
import '../core/theme/font.dart';
import '../core/theme/theme.dart';
import '../data/providers/viewmodel/theme_model.dart';
import '../routes/router.dart';

import 'dart:io';
import './age_verifi.dart';

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _AppState();
}

class _AppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeModel>(
      builder: (context, model, child) {
        TextTheme textTheme = createTextTheme(context, "Roboto", "Tinos");
        MaterialTheme theme = MaterialTheme(textTheme);

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          themeMode: model.themeMode,
          theme: theme.light(),
          darkTheme: theme.dark(),
          onGenerateRoute: PageRouter.generateRoute,
          initialRoute: Routes.age,
          home: Scaffold(
            body: AgeVerificationScreen(),
          ),
        );
      },
    );
  }
}

//login
//save user session
