ipconfig
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"

# If Wireless debugging shows a new pairing code:
& $adb pair 192.168.1.21:PAIR_PORT 123456

# Then connect (IP:port from the main Wireless debugging screen — colon, not a dot)
& $adb connect 192.168.1.21:CONNECT_PORT

& $adb devices

Replace PAIR_PORT, 123456, and CONNECT_PORT with what’s on the phone right now (ports change often).

$env:Path = "C:\flutter\bin;$env:Path"
cd C:\xampp\htdocs\PaAyo_mobile
flutter run