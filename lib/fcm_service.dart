import 'dart:convert';
import 'package:googleapis_auth/auth_io.dart';
import 'package:http/http.dart' as http;

class FCMService {
  final String projectId;
  final String serviceAccountKey;

  FCMService({required this.projectId, required this.serviceAccountKey});

  Future<void> sendPushNotification(String token, String title, String body) async {
    final accountCredentials = ServiceAccountCredentials.fromJson(serviceAccountKey);

    final scopes = ['https://www.googleapis.com/auth/cloud-platform'];
    final client = await clientViaServiceAccount(accountCredentials, scopes);

    final message = {
      'message': {
        'token': token,
        'notification': {
          'title': title,
          'body': body,
        },
      },
    };

    final url = 'https://fcm.googleapis.com/v1/projects/$projectId/messages:send';
    final response = await client.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(message),
    );

    if (response.statusCode == 200) {
      print('FCM request sent successfully');
    } else {
      print('FCM request failed with status ${response.statusCode}: ${response.body}');
    }
  }
}
