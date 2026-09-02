import 'dart:html' as html;

Future<bool> requestWebNotificationPermission() async {
  if (!html.Notification.supported) return false;
  if (html.Notification.permission == 'granted') return true;
  final result = await html.Notification.requestPermission();
  return result == 'granted';
}

void showWebNotification(String title, String body) {
  if (!html.Notification.supported) return;
  if (html.Notification.permission != 'granted') return;
  html.Notification(title, body: body);
}
