# How to run PaAyo Mobile

Repo: https://github.com/Kairvls/PaAyo_mobile.git

Use this on **whichever Windows laptop** you’re on. Do not hardcode another classmate’s username in the ADB path.

---

## 1. Start the STI-PRISM API (phone must reach it)

```powershell
cd C:\xampp\htdocs\STI-PRISM
php artisan serve --host=0.0.0.0 --port=8000
```

`--host=0.0.0.0` is required so the phone can connect. `localhost` alone is not enough.

Optional (live updates on web):

```powershell
php artisan reverb:start
```

---

## 2. Point the app at this laptop’s IP

1. Run `ipconfig` and copy the **IPv4 Address** (example: `192.168.1.24`).
2. Open `lib/core/constants/api.dart` and set:

```dart
static const String host = "192.168.1.24"; // your current IPv4
```

3. Confirm from this PC:

```powershell
Invoke-WebRequest http://192.168.1.24:8000/api/rooms
```

You want status `200`.

---

## 3. Connect the phone (wireless debugging)

On the phone:

1. Enable **Developer options** → **Wireless debugging**.
2. Note the **pairing** IP:port + pairing code.
3. Note the **connect** IP:port (they can differ; ports change often).

On the laptop (works for any Windows user):

```powershell
$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
& $adb kill-server
& $adb start-server

# 1) On the phone tap: Wireless debugging → Pair device with pairing code
#    Put the pairing IP:port AND the 6-digit code on ONE line (do not wait for the prompt):
& $adb pair 192.168.1.21:PAIR_PORT 123456

# 2) Go BACK to the Wireless debugging screen and copy the IP:port under
#    "IP address & port" (this is NOT the pairing port)
& $adb connect 192.168.1.21:CONNECT_PORT

& $adb devices
```

You must see a device listed (e.g. `192.168.1.21:XXXXX device`) before `flutter run` will work.

If you get `protocol fault` / `couldn't read status message`:
1. Toggle **Wireless debugging OFF → ON** on the phone
2. Open a **new** pairing code (old ports expire in seconds)
3. Run `adb kill-server` then pair again with code on the same line
4. Or plug a USB cable once, accept “Allow USB debugging”, then try wireless again

Or use the helper:

```powershell
.\tool\adb-connect.ps1 -PhoneEndpoint "192.168.1.21:CONNECT_PORT" -PairEndpoint "192.168.1.21:PAIR_PORT" -PairCode "123456"
```

---

## 4. Run Flutter

Flutter SDK on this laptop: `C:\flutter` (already on User PATH).

```powershell
# New terminal so PATH picks up C:\flutter\bin
cd C:\xampp\htdocs\PaAyo_mobile
$env:Path = "C:\flutter\bin;$env:LOCALAPPDATA\Android\Sdk\platform-tools;$env:Path"
flutter devices
flutter run -d 192.168.1.21:CONNECT_PORT
```

Windows tip: turn on **Developer Mode** (`start ms-settings:developers`) so Flutter plugin symlinks work.

While running:

- `r` — hot reload  
- `R` — hot restart  
- `q` — quit  

---

## Common mistakes

| Problem | Fix |
|--------|-----|
| `C:\Users\jc suan\...\adb.exe` not found | That path is another person’s laptop. Use `$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe` |
| `failed to connect` | Pair first; refresh the wireless-debug port on the phone |
| App can’t reach API | Use `--host=0.0.0.0` and update `Api.host` to this PC’s IPv4 |
| `192.168.1.21.42333` | Wrong — must be `192.168.1.21:42333` (colon) |

---

## Quick checklist

- [ ] `php artisan serve --host=0.0.0.0 --port=8000`
- [ ] `Api.host` matches `ipconfig` IPv4
- [ ] Phone paired + connected (`adb devices` shows it)
- [ ] `flutter run`
