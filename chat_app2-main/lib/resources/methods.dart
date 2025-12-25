import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:intl/intl.dart';

class ChatRoomId {
  String chatRoomId(String? user1, String user2) {
    if (user1![0].toLowerCase().codeUnits[0] >
        user2.toLowerCase().codeUnits[0]) {
      return "$user1$user2";
    } else {
      return "$user2$user1";
    }
  }
}

Future<Position> getLocation() async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    return Future.error('Location services are disabled.');
  }

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied) {
      return Future.error('Location permissions are denied');
    }
  }

  if (permission == LocationPermission.deniedForever) {
    return Future.error('Gg, we done');
  }

  return await Geolocator.getCurrentPosition();
}

Future<void> openMap(String lat, String long) async {
  String googleUrl =
      'https://www.google.com/maps/search/?api=1&query=$lat,$long';

  await canLaunchUrlString(googleUrl)
      ? await launchUrlString(googleUrl)
      : throw 'Could not launch $googleUrl';
}

// String formatDateString(String dateString) {
//   DateTime dateTime = DateTime.parse(dateString);
//   var formatter = DateFormat('dd/MM/yy');
//   return formatter.format(dateTime);
// }
//
// String convertHours(String dateString) {
//   DateTime dateTime = DateTime.parse(dateString);
//   var formatter = DateFormat('hh:mm');
//   return formatter.format(dateTime);
// }

String timeForMessage(String dateString) {
  DateTime dateTime = DateTime.parse(dateString);
  var formatter = DateFormat('dd/MM/yyyy' + " " + 'HH:mm');
  return formatter.format(dateTime);
}

/// Safely format timestamp string for display
/// Handles cases where timestamp might be malformed or too short
/// Returns formatted string like "14:30, 06/12/2025" or "Invalid time" if malformed
String formatTimestampSafe(String? timestamp) {
  if (timestamp == null || timestamp.isEmpty) {
    return 'Unknown time';
  }
  
  try {
    // Expected format from timeForMessage: "dd/MM/yyyy HH:mm" (16 chars)
    // Example: "06/12/2025 14:30"
    if (timestamp.length >= 16) {
      // Format: time, date
      return "${timestamp.substring(11, 16)}, ${timestamp.substring(0, 10)}";
    } else if (timestamp.length >= 10) {
      // Only date available
      return timestamp.substring(0, 10);
    } else {
      // Try parsing as DateTime
      final dt = DateTime.tryParse(timestamp);
      if (dt != null) {
        return DateFormat('HH:mm, dd/MM/yyyy').format(dt);
      }
      return timestamp; // Return as-is if can't parse
    }
  } catch (e) {
    return 'Invalid time';
  }
}

/// Safely extract time (HH:mm) from timestamp
/// Returns "HH:mm" format or empty string if invalid
String extractTimeSafe(String? timestamp) {
  if (timestamp == null || timestamp.isEmpty) {
    return '';
  }
  
  try {
    if (timestamp.length >= 16) {
      return timestamp.substring(11, 16);
    } else if (timestamp.length >= 5) {
      // Maybe already in HH:mm format
      return timestamp.substring(0, 5);
    } else {
      return '';
    }
  } catch (e) {
    return '';
  }
}
