/// Canonical equipment condition and inventory status values (mobile).
/// Keep in sync with backend EquipmentConditions / EquipmentInventoryStatuses.
class EquipmentConditions {
  static const good = "Good";
  static const underMaintenance = "Under Maintenance";
  static const defective = "Defective";
  static const damaged = "Damaged";
  static const disposed = "Disposed";

  static const List<String> all = [
    good,
    underMaintenance,
    defective,
    damaged,
    disposed,
  ];
}

class EquipmentInventoryStatuses {
  static const active = "Active";
  static const borrowed = "Borrowed";
  static const underMaintenance = "Under Maintenance";
  static const forReplacement = "For Replacement";
  static const disposed = "Disposed";

  static const List<String> all = [
    active,
    borrowed,
    underMaintenance,
    forReplacement,
    disposed,
  ];
}
