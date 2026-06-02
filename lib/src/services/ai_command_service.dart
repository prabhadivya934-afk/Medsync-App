class AICommandService {
  static Map<String, dynamic> process(String input) {
    input = input.toLowerCase();

    /// ADD MEDICINE INTENT
    if (input.contains("add")) {
      String name = "";
      String time = "";

      // Extract medicine name
      final words = input.split(" ");
      int addIndex = words.indexOf("add");

      if (addIndex != -1 && addIndex + 1 < words.length) {
        name = words.sublist(addIndex + 1).join(" ");
      }

      // Extract time (basic logic)
      final timeRegex = RegExp(r'(\d{1,2})\s?(am|pm)');
      final match = timeRegex.firstMatch(input);

      if (match != null) {
        time = match.group(0)!;
      }

      return {"intent": "add_medicine", "name": name, "time": time};
    }

    /// GREETING
    if (input.contains("hello")) {
      return {"intent": "greeting"};
    }

    return {"intent": "unknown"};
  }
}
