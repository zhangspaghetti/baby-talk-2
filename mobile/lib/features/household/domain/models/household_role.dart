enum HouseholdRole { primaryCaregiver, caregiver }

extension HouseholdRoleWire on HouseholdRole {
  String get wireValue {
    switch (this) {
      case HouseholdRole.primaryCaregiver:
        return 'primary_caregiver';
      case HouseholdRole.caregiver:
        return 'caregiver';
    }
  }

  String get label {
    switch (this) {
      case HouseholdRole.primaryCaregiver:
        return '主照护者';
      case HouseholdRole.caregiver:
        return '次照护者';
    }
  }
}

HouseholdRole parseHouseholdRole(String value) {
  switch (value.trim()) {
    case 'primary_caregiver':
      return HouseholdRole.primaryCaregiver;
    case 'caregiver':
      return HouseholdRole.caregiver;
    default:
      throw FormatException('未知 household role: $value');
  }
}

HouseholdRole? maybeParseHouseholdRole(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return parseHouseholdRole(normalized);
}
