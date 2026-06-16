/// Default category artwork when API/DB has no [image_url].
abstract final class CategoryImages {
  static const chicken =
      'https://images.unsplash.com/photo-1604503468506-a8da286d644f?auto=format&fit=crop&w=600&q=80';
  static const mutton =
      'https://images.unsplash.com/photo-1607623814075-e51df1bdc82f?auto=format&fit=crop&w=600&q=80';
  static const fish =
      'https://images.unsplash.com/photo-1519003722824-194d4455a60c?auto=format&fit=crop&w=600&q=80';
  static const eggs =
      'https://images.unsplash.com/photo-1582729478250-c89cae4dc85b?auto=format&fit=crop&w=600&q=80';

  static String? urlForName(String name) {
    final key = name.toLowerCase();
    if (key.contains('egg')) return eggs;
    if (key.contains('fish') || key.contains('seafood')) return fish;
    if (key.contains('mutton') ||
        key.contains('lamb') ||
        key.contains('goat')) {
      return mutton;
    }
    if (key.contains('chicken')) return chicken;
    return null;
  }

  static String? resolveUrl(String? imageUrl, String categoryName) {
    final trimmed = imageUrl?.trim();
    if (trimmed != null &&
        trimmed.isNotEmpty &&
        (trimmed.startsWith('http://') || trimmed.startsWith('https://'))) {
      return trimmed;
    }
    return urlForName(categoryName);
  }
}
