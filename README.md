# prism_mobile

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

Mobile Running: 
- on the phone open the developer options (wireless debugging)
- ipconfig to check to IPv4 address & copy the port
- & "C:\Users\jc suan\AppData\Local\Android\Sdk\platform-tools\adb.exe" connect 192.168.137.209:38637 (use the phone ip address from developer options to make the laptop and phone connected to each other)
- flutter devices to confirm if the ip address exist
- flutter run then click or choose the phone ip address
- r to hot reload
- R to hot restart
- q to exit development


Web Running:
- php artisan serve to run the web server (localhost:8000 for accessing MFA office 365)
- php artisan reverb:start to make it live viewing (no refresh needed for some parts)
- php artisan serve --host=0.0.0.0 --port=8000 (to connect to mobile)


Web to Email form for registering as reporter:
- php artisan serve --host=0.0.0.0 --port=8000