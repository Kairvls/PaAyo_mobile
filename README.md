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
- Full copy of the run steps: see **MOBILE_RUNNING.md**
- on the phone open the developer options (wireless debugging)
- ipconfig to check to IPv4 address & copy the port
- & "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe" connect 192.168.1.21:42333 (use the phone ip:port from developer options — works on any Windows user/laptop; old classmate path was `C:\Users\jc suan\...`)
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

should we remove this? or like theres a mode that when on or turn on or click to guide mode the system will shows how to report like on the image 3 or like on the modern mobile apps right now that theres a tutorial mode or like on games that theres a bubble text that will pop point to that area or field then you click any empty area it will next to the next step guide like that until you reach the end of the tutorial or guide mode


no duplication of gmail in the equipment reporters list

Enter your employee ID and 6-digit PIN so nobody else can report under your name.\
We'll email a link

Your PIN is emailed to you when the maintenance office adds or approves you as a reporter. 
No PIN or no email on file?

---

## Extra notes (this PC / current LAN)

Repo: https://github.com/Kairvls/PaAyo_mobile.git

API host is centralized in `lib/core/constants/api.dart` (`Api.host`).  
Current LAN IPv4 for this machine: `192.168.1.24` — update that constant when `ipconfig` changes.

ADB on this PC (when not using the path above):

`C:\Users\aljon\AppData\Local\Android\Sdk\platform-tools\adb.exe`

```powershell
$adb = "C:\Users\aljon\AppData\Local\Android\Sdk\platform-tools\adb.exe"
& $adb pair 192.168.1.21:PAIR_PORT
& $adb connect 192.168.1.21:CONNECT_PORT   # use a colon, not a dot
& $adb devices
```

Backend for phone access (must bind all interfaces):

```powershell
cd C:\xampp\htdocs\STI-PRISM
php artisan serve --host=0.0.0.0 --port=8000
```

Confirm API from this PC: `http://192.168.1.24:8000/api/rooms`

Helper script: `tool/adb-connect.ps1`
