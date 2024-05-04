extension Stringizers on String {
  String upTo(int max) {
    if (length > max) {
      return substring(0, max);
    }
    return this;
  }

  String capitalize() {
    if (isEmpty) return this;
    return "${this[0].toUpperCase()}${substring(1)}";
  }

  // https://www.perplexity.ai/search/Please-write-me-fybOo_RQScujWS4W4AeGvQ
  String pluralize() {
    // Ends with 'y' after a consonant (city -> cities)
    if (endsWith('y') && !RegExp(r'[aeiou]y$').hasMatch(this)) {
      return substring(0, length - 1) + 'ies';
    }
    // Ends with 'o', 'ch', 's', 'sh', 'x' or 'z' (potato -> potatoes)
    else if (RegExp(r'(o|ch|s|sh|x|z)$').hasMatch(this)) {
      return this + 'es';
    }
    // Ends with 'f' or 'fe' (wolf -> wolves)
    else if (RegExp(r'(f|fe)$').hasMatch(this)) {
      return replaceAll(RegExp(r'f$'), 'ves').replaceAll(RegExp(r'fe$'), 'ves');
    }
    // Regular nouns (cat -> cats)
    else {
      return this + 's';
    }
  }
}
