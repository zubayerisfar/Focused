import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationPreferencesProvider extends ChangeNotifier {
  static const String _keyFollowerAlerts = 'notif_pref_follower_alerts';
  static const String _keySquadInvites = 'notif_pref_squad_invites';
  static const String _keyFriendNudgesAndGifts = 'notif_pref_nudges_gifts';
  static const String _keyPartnerCompletions = 'notif_pref_partner_completions';
  static const String _keyOccasionalReminders = 'notif_pref_occasional_reminders';
  static const String _keyOccasionalHour = 'notif_pref_occasional_hour';
  static const String _keyOccasionalMinute = 'notif_pref_occasional_minute';

  bool _followerAlerts = true;
  bool _squadInvites = true;
  bool _friendNudgesAndGifts = true;
  bool _partnerCompletions = true;
  bool _occasionalReminders = true;
  int _occasionalHour = 20; // 8:00 PM default
  int _occasionalMinute = 0;

  bool _loaded = false;

  bool get followerAlerts => _followerAlerts;
  bool get squadInvites => _squadInvites;
  bool get friendNudgesAndGifts => _friendNudgesAndGifts;
  bool get partnerCompletions => _partnerCompletions;
  bool get occasionalReminders => _occasionalReminders;
  TimeOfDay get occasionalTime =>
      TimeOfDay(hour: _occasionalHour, minute: _occasionalMinute);
  bool get isLoaded => _loaded;

  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _followerAlerts = prefs.getBool(_keyFollowerAlerts) ?? true;
    _squadInvites = prefs.getBool(_keySquadInvites) ?? true;
    _friendNudgesAndGifts = prefs.getBool(_keyFriendNudgesAndGifts) ?? true;
    _partnerCompletions = prefs.getBool(_keyPartnerCompletions) ?? true;
    _occasionalReminders = prefs.getBool(_keyOccasionalReminders) ?? true;
    _occasionalHour = prefs.getInt(_keyOccasionalHour) ?? 20;
    _occasionalMinute = prefs.getInt(_keyOccasionalMinute) ?? 0;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setFollowerAlerts(bool value) async {
    _followerAlerts = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFollowerAlerts, value);
  }

  Future<void> setSquadInvites(bool value) async {
    _squadInvites = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keySquadInvites, value);
  }

  Future<void> setFriendNudgesAndGifts(bool value) async {
    _friendNudgesAndGifts = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyFriendNudgesAndGifts, value);
  }

  Future<void> setPartnerCompletions(bool value) async {
    _partnerCompletions = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyPartnerCompletions, value);
  }

  Future<void> setOccasionalReminders(bool value) async {
    _occasionalReminders = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOccasionalReminders, value);
  }

  Future<void> setOccasionalTime(TimeOfDay time) async {
    _occasionalHour = time.hour;
    _occasionalMinute = time.minute;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyOccasionalHour, time.hour);
    await prefs.setInt(_keyOccasionalMinute, time.minute);
  }
}
