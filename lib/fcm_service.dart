import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:googleapis_auth/auth_io.dart';

class FCMService {
  final String projectId;
  final Map<String, dynamic> serviceAccountKey;

  FCMService({required this.projectId, required this.serviceAccountKey});

  Future<void> sendPushNotification(Map<String, dynamic> payload) async {
    final credentials = ServiceAccountCredentials.fromJson(serviceAccountKey);
    final httpClient = await clientViaServiceAccount(credentials, ['https://www.googleapis.com/auth/firebase.messaging']);

    final response = await httpClient.post(
      Uri.parse('https://fcm.googleapis.com/v1/projects/$projectId/messages:send'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'message': payload,
      }),
    );

    if (response.statusCode == 200) {
      print('FCM request sent successfully');
    } else {
      print('FCM request failed with status ${response.statusCode}: ${response.body}');
    }

    httpClient.close();
  }
}
