import 'package:flutter/material.dart';
import '../../../data/providers/base_view.dart';
import '../../../data/providers/viewmodel/theme_model.dart';
import '../../../routes/routes.dart';
import '../../widgets/custom_listtile.dart';
import '../../../core/constants/assets_constant.dart';
import 'package:qr_flutter/qr_flutter.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cài đặt'),
      ),
      body: BaseView<ThemeModel>(
        builder: (context, model, child) {
          return ListView(
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.pushNamed(context, Routes.profileRoute);
                },
                child: const CustomListTile(
                  title: 'Hồ sơ',
                  leading: Icon(
                    Icons.person_2_rounded,
                  ),
                  trailing: Icon(Icons.arrow_forward_ios_rounded),
                ),
              ),
              CustomListTile(
                title: 'Chế độ tối',
                titleStyle: TextStyle(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
                ),
                leading: Icon(
                  Icons.lightbulb_circle_rounded,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black,
                ),
                trailing: Switch(
                  value: model.themeMode == ThemeMode.dark,
                  onChanged: (value) {
                    model.toggleTheme(value);
                  },
                ),
              ),
              Column(
                children: [
                  Container(
                    width: 500,
                    height: 500,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        AssetConstant.maQR,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ủng hộ chúng tôi đồng hành cùng các bạn',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
