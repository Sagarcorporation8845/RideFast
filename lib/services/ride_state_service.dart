import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

// Defines the possible states of an active ride
enum RideState { none, searching, driverAssigned, driverArrived }

class RideStateService {
  static const _rideStateKey = 'active_ride_state';
  static const _rideDataKey = 'active_ride_data';

  // Saves the current state of the ride to local storage
  Future<void> saveRideState(RideState state, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_rideStateKey, state.toString());
    await prefs.setString(_rideDataKey, jsonEncode(data));
  }

  // Loads the last saved ride state from local storage
  Future<Map<String, dynamic>?> loadRideState() async {
    final prefs = await SharedPreferences.getInstance();
    final stateStr = prefs.getString(_rideStateKey);
    final dataStr = prefs.getString(_rideDataKey);

    if (stateStr == null || dataStr == null) {
      return null; // No active ride found
    }

    return {
      'state': stateStr,
      'data': jsonDecode(dataStr),
    };
  }

  // Clears the ride state when the ride is completed or cancelled
  Future<void> clearRideState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_rideStateKey);
    await prefs.remove(_rideDataKey);
  }
}
