const PLUS_CODE_RE = /\b[A-Z0-9]{4,}\+[A-Z0-9]{2,}\b/gi;

const stripPlusCode = (text) => {
  if (!text) return '';
  return String(text)
    .replace(PLUS_CODE_RE, '')
    .replace(/\s{2,}/g, ' ')
    .replace(/^[,\s]+|[,\s]+$/g, '')
    .trim();
};

const dedupeParts = (parts) => {
  const seen = new Set();
  const result = [];
  for (const raw of parts) {
    const part = stripPlusCode(raw);
    if (!part) continue;
    const key = part.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    result.push(part);
  }
  return result;
};

const cleanAddressText = (text) => {
  if (!text) return '';
  const stripped = stripPlusCode(text);
  if (stripped.includes(',')) {
    return dedupeParts(stripped.split(',').map((p) => p.trim())).join(', ');
  }
  return stripped;
};

const addressToText = (addr) => {
  if (!addr) return '';
  if (typeof addr === 'string') return cleanAddressText(addr);

  const formatted = addr.formatted || addr.formatted_address;
  if (formatted) return cleanAddressText(String(formatted));

  const text = addr.text || addr.addressText || addr.raw || addr.address;
  if (text) return cleanAddressText(String(text));

  const parts = [
    addr.line1 || addr.address_line1 || addr.addressLine1,
    addr.line2 || addr.address_line2 || addr.addressLine2,
    addr.landmark,
    addr.city,
    addr.state,
    addr.pincode,
  ].filter(Boolean);

  return dedupeParts(parts).join(', ');
};

const addressToObject = (addr) => {
  if (!addr) return null;
  if (typeof addr === 'string') {
    const trimmed = cleanAddressText(addr);
    return trimmed ? { text: trimmed, formatted: trimmed } : null;
  }
  const text = addressToText(addr);
  const lat = Number(addr.lat ?? addr.latitude);
  const lng = Number(addr.lng ?? addr.longitude);
  return {
    text,
    formatted: text,
    raw: addr.raw ? cleanAddressText(String(addr.raw)) : text,
    ...(Number.isFinite(lat) && Number.isFinite(lng) ? { lat, lng } : {}),
  };
};

module.exports = { addressToText, addressToObject, stripPlusCode, cleanAddressText };
