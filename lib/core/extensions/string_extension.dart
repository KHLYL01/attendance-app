extension StringX on String? {
  String toCapitalized() {
    if (this == null) return '';
    if (this!.isEmpty) return '';

    List<String> str = this!.split('_');

    String text = str.join(' ').toLowerCase();

    return text[0].toUpperCase() + text.substring(1);
  }
}
