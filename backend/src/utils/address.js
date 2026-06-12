const addressToText = (addr) => {
  if (!addr) return '';
  if (typeof addr === 'string') return addr.trim();
  const formatted = addr.formatted || addr.formatted_address;
  if (formatted) return String(formatted).trim();
  const text = addr.text || addr.addressText || addr.raw || addr.address;
  if (text) return String(text).trim();
  const parts = [addr.line1, addr.line2, addr.city, addr.state, addr.pincode].filter(Boolean);
  return parts.join(', ');
};

const addressToObject = (addr) => {
  if (!addr) return null;
  if (typeof addr === 'string') {
    const trimmed = addr.trim();
    return trimmed ? { text: trimmed, formatted: trimmed } : null;
  }
  const text = addressToText(addr);
  const lat = Number(addr.lat ?? addr.latitude);
  const lng = Number(addr.lng ?? addr.longitude);
  return {
    text,
    formatted: text,
    raw: addr.raw ? String(addr.raw) : text,
    ...(Number.isFinite(lat) && Number.isFinite(lng) ? { lat, lng } : {}),
  };
};

module.exports = { addressToText, addressToObject };
