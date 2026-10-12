import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/sensor_engine.dart';

class AppProvider extends ChangeNotifier {
  int tabIndex = 0;
  bool developerOverride = false;
  bool emergencyActive = false;
  SensorEngine? _sensor;

  void setTab(int index) { tabIndex = index; notifyListeners(); }
  void attachSensor(SensorEngine sensor) { _sensor = sensor; }
  void setDeveloperOverride(bool value) { developerOverride = value; notifyListeners(); }
  void triggerEmergency() { emergencyActive = true; notifyListeners(); }
  void cancelEmergency() { emergencyActive = false; _sensor?.resetTrigger(); notifyListeners(); }
  Future<void> signOut() async { await FirebaseAuth.instance.signOut(); tabIndex = 0; notifyListeners(); }
}
