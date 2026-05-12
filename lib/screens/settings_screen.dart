import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Configuración de Alertas")),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text("Alertas de Robos [15.2]"),
            value: true,
            onChanged: (bool value) {},
          ),
          SwitchListTile(
            title: Text("Alertas de Accidentes [15.2]"),
            value: true,
            onChanged: (bool value) {},
          ),
        ],
      ),
    );
  }
}
