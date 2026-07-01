/// Validates user-typed address detail fields (house, floor, tower, landmark).
class AddressInputValidator {
  AddressInputValidator._();

  static final RegExp _allowedChars = RegExp(r"^[a-zA-Z0-9\s\-\/#.,()'&]+$");

  static final RegExp _houseKeywords = RegExp(
    r'\b(flat|flt|house|h\.?\s*no|plot|door|room|building|bldg|blk|block|apt|apartment|unit|shop|shed|wing|tower|twr|sector|sec)\b',
    caseSensitive: false,
  );

  static final RegExp _floorPattern = RegExp(
    r'^(g|gf|ground|grnd|b|lg|ug|basement|'
    r'l\d+|m\d+|'
    r'\d{1,2}(st|nd|rd|th)?'
    r')$',
    caseSensitive: false,
  );

  static final RegExp _landmarkKeywords = RegExp(
    r'\b(near|opposite|behind|beside|next to|landmark|market|temple|school|'
    r'hospital|mall|store|park|chowk|mandir|masjid|church|bus stop|metro|'
    r'station|bank|hotel|restaurant|petrol|pump|colony|gate|main road)\b',
    caseSensitive: false,
  );

  /// Heuristic: random keyboard mash without meaningful address structure.
  static bool looksLikeGibberish(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return false;
    if (RegExp(r'^\d+$').hasMatch(trimmed)) return false;

    final lettersOnly =
        trimmed.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '');
    if (lettersOnly.isEmpty) return false;

    final vowels =
        lettersOnly.replaceAll(RegExp(r'[^aeiou]'), '').length;
    if (lettersOnly.length >= 5 && vowels == 0) return true;
    if (lettersOnly.length >= 6 && vowels / lettersOnly.length < 0.12) {
      return true;
    }
    if (RegExp(r'[bcdfghjklmnpqrstvwxyz]{4,}').hasMatch(lettersOnly)) {
      return true;
    }
    if (RegExp(r'(.)\1{2,}').hasMatch(lettersOnly)) return true;

    return false;
  }

  static String? validateHouseNumber(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Please enter house / flat number';
    if (v.length > 50) return 'Too long (max 50 characters)';
    if (!_allowedChars.hasMatch(v)) {
      return 'Use only letters, numbers and - / # . , ( )';
    }
    if (RegExp(r'\d').hasMatch(v)) return null;
    if (_houseKeywords.hasMatch(v)) return null;
    if (v.length <= 3 && RegExp(r'^[a-zA-Z0-9]+$').hasMatch(v)) return null;
    if (v.contains(' ') &&
        v.split(RegExp(r'\s+')).every((w) => w.length >= 1) &&
        !looksLikeGibberish(v)) {
      return null;
    }
    if (looksLikeGibberish(v)) {
      return 'Please enter a valid house / flat number';
    }
    return 'Include a number (e.g. 36, Flat 302, H.No. 12)';
  }

  static String? validateFloor(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    if (v.length > 15) return 'Too long';
    if (!_allowedChars.hasMatch(v)) return 'Invalid characters';
    if (_floorPattern.hasMatch(v)) return null;
    if (RegExp(r'^\d{1,2}$').hasMatch(v)) return null;
    if (looksLikeGibberish(v)) {
      return 'Please enter a valid floor (e.g. 2, G, Basement)';
    }
    return 'Enter floor as number or G / Ground / Basement';
  }

  static String? validateTowerBlock(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    if (v.length > 40) return 'Too long';
    if (!_allowedChars.hasMatch(v)) return 'Invalid characters';
    if (looksLikeGibberish(v)) {
      return 'Please enter a valid tower / block name';
    }
    if (RegExp(r'^[A-Za-z]\d?$').hasMatch(v)) return null;
    if (RegExp(
      r'\b(tower|block|blk|wing|phase|cluster)\b',
      caseSensitive: false,
    ).hasMatch(v)) {
      return null;
    }
    if (RegExp(r'\d').hasMatch(v) && RegExp(r'[a-zA-Z]').hasMatch(v)) {
      return null;
    }
    if (v.length <= 4 && RegExp(r'^[a-zA-Z0-9]+$').hasMatch(v)) return null;
    if (v.contains(' ') && !looksLikeGibberish(v)) return null;
    return 'Enter tower / block (e.g. A, Tower 2, Block B)';
  }

  static String? validateLandmark(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return null;
    if (v.length < 3) return 'Landmark is too short';
    if (v.length > 80) return 'Too long';
    if (!_allowedChars.hasMatch(v)) return 'Invalid characters';
    if (looksLikeGibberish(v)) {
      return 'Please enter a real nearby landmark';
    }
    if (_landmarkKeywords.hasMatch(v)) return null;
    if (RegExp(r'\d').hasMatch(v)) return null;
    final words =
        v.split(RegExp(r'\s+')).where((w) => w.length >= 2).toList();
    if (words.length >= 2 && !looksLikeGibberish(v)) return null;
    return 'Add a clear landmark (e.g. near City Park, opposite HDFC Bank)';
  }
}
