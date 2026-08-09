import 'package:flutter/material.dart';

/// Resolves the best-matching equipment "kind" key from a [name] and optional
/// [category] using keyword matching. The key maps to both a pictorial image
/// asset and a Material glyph fallback.
String equipmentKindFor(String name, [String category = ""]) {
  final text = "$name $category".toLowerCase();

  bool has(List<String> keys) => keys.any(text.contains);

  // Furniture & Fixtures (check before generic desk/table/board matches).
  if (has(["white board", "whiteboard"])) return "whiteboard";
  if (has(["curtain", "drape", "blind"])) return "curtains";
  if (has([
    "chair",
    "arm desk",
    "armchair",
    "monoblock",
    "stool",
    "bench",
    "sofa",
  ])) {
    return "chair";
  }

  // Air conditioning (window / floor before the generic split match).
  if (has(["window air", "window type air", "window aircon"])) {
    return "aircon_window";
  }
  if (has(["floor standing", "floor-standing", "standing air", "floor air"])) {
    return "aircon_floor";
  }
  if (has([
    "split type",
    "split-type",
    "split air",
    "air condition",
    "aircon",
    "hvac",
    "cooling",
  ])) {
    return "aircon_split";
  }

  // Ventilation.
  if (has([
        "electric fan",
        "ceiling fan",
        "wall fan",
        "stand fan",
        "exhaust fan",
        "ventilat",
        "blower",
      ]) ||
      (has(["fan"]) && !has(["infant"]))) {
    return "fan";
  }

  if (has(["refriger", "freezer", "chiller", "fridge"])) return "refrigerator";
  if (has(["laptop", "notebook"])) return "laptop";

  // Computer set (system unit / tower before generic desktop/computer).
  if (has(["system unit", "system-unit", "tower", "cpu case"])) {
    return "system_unit";
  }
  if (has(["monitor", "lcd", "led screen"])) return "monitor";
  if (has(["keyboard"])) return "keyboard";
  if (has(["mouse"])) return "mouse";
  if (has(["ups", "avr", "uninterruptible", "power supply", "voltage"])) {
    return "ups";
  }
  if (has(["desktop", "computer", "pc "]) || text.trim() == "pc") {
    return "desktop";
  }

  // Display / projection.
  if (has(["projector"])) return "projector";
  if (has(["television", "flat screen", "smart tv", "tv "]) ||
      text.trim() == "tv" ||
      text.endsWith(" tv")) {
    return "tv";
  }

  if (has(["printer", "print"])) return "printer";

  // Network (cable/ethernet before router keywords).
  if (has([
    "ethernet",
    "internet cable",
    "lan cable",
    "utp",
    "network cable",
    "patch cord",
  ])) {
    return "cable";
  }
  if (has(["router", "modem", "network", "switch ", "access point", "wifi"])) {
    return "router";
  }

  if (has(["camera", "cctv", "webcam", "surveillance"])) return "cctv";
  if (has(["speaker", "audio", "sound", "amplifier"])) return "speaker";

  // Lighting.
  if (has([
    "bulb",
    "fluorescent",
    "led light",
    "light bulb",
    "lamp",
    "lighting",
  ])) {
    return "bulb";
  }

  // Furniture tables/desks (after chair/arm desk handled above).
  if (has(["table", "desk"])) return "table";

  return "default";
}

/// Absolute asset path for the pictorial icon of the given equipment.
String equipmentImageFor(String name, [String category = ""]) {
  final kind = equipmentKindFor(name, category);
  return "assets/images/equipment/eq_$kind.png";
}

/// Material glyph fallback (used if an image asset fails to load).
IconData equipmentIconFor(String name, [String category = ""]) {
  switch (equipmentKindFor(name, category)) {
    case "aircon_split":
    case "aircon_window":
    case "aircon_floor":
      return Icons.ac_unit_rounded;
    case "fan":
      return Icons.air_rounded;
    case "refrigerator":
      return Icons.kitchen_rounded;
    case "laptop":
      return Icons.laptop_mac_rounded;
    case "desktop":
      return Icons.desktop_windows_rounded;
    case "system_unit":
      return Icons.dns_rounded;
    case "monitor":
      return Icons.monitor_rounded;
    case "projector":
      return Icons.video_settings_rounded;
    case "tv":
      return Icons.tv_rounded;
    case "printer":
      return Icons.print_rounded;
    case "keyboard":
      return Icons.keyboard_rounded;
    case "mouse":
      return Icons.mouse_rounded;
    case "router":
      return Icons.router_rounded;
    case "cable":
      return Icons.settings_ethernet_rounded;
    case "cctv":
      return Icons.photo_camera_rounded;
    case "speaker":
      return Icons.speaker_rounded;
    case "ups":
      return Icons.battery_charging_full_rounded;
    case "bulb":
      return Icons.lightbulb_rounded;
    case "chair":
      return Icons.chair_rounded;
    case "table":
      return Icons.table_restaurant_rounded;
    case "whiteboard":
      return Icons.co_present_rounded;
    case "curtains":
      return Icons.curtains_rounded;
    default:
      return Icons.devices_other_rounded;
  }
}

/// A pictorial equipment icon that renders the matching image asset and falls
/// back to a themed Material glyph if the image can't be loaded.
class EquipmentGraphic extends StatelessWidget {
  final String name;
  final String category;
  final double size;
  final Color fallbackColor;

  const EquipmentGraphic({
    super.key,
    required this.name,
    this.category = "",
    required this.size,
    this.fallbackColor = const Color(0xFF0B2F64),
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      equipmentImageFor(name, category),
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => Icon(
        equipmentIconFor(name, category),
        size: size,
        color: fallbackColor,
      ),
    );
  }
}
