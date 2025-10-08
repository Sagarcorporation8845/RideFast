import 'package:audioplayers/audioplayers.dart';

class SoundService {
  final AudioPlayer _audioPlayer = AudioPlayer();

  // A private helper method to play a sound from the assets
  Future<void> _playSound(String fileName) async {
    try {
      await _audioPlayer.play(AssetSource('sounds/$fileName'));
    } catch (e) {
      // Catch and print any errors, but don't crash the app
      print("Error playing sound: $e");
    }
  }

  // Plays the sound for when a driver is assigned
  void playDriverAssignedSound() {
    _playSound('driver_assigned.mp3');
  }

  // Plays the generic sound for a new ride state (arrived, started, OTP)
  void playNewStateSound() {
    _playSound('new_state.mp3');
  }

  // Plays the celebratory sound when a ride is completed
  void playRideCompletedSound() {
    _playSound('Ride_completed.mp3');
  }

  // Plays when a ride is cancelled or no drivers are found
  void playRideCancelledSound() {
    // As requested, using the 'Ride_completed.mp3' sound for this state
    _playSound('Ride_completed.mp3');
  }

  // Call this to release resources when the service is no longer needed
  void dispose() {
    _audioPlayer.dispose();
  }
}
