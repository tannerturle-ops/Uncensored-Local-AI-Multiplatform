/// Conservative local routing for clear image commands.
/// Ambiguous messages remain chat until a configured model can disambiguate.
enum MochiIntent { chat, generateImage, editImage, analyzeImage, ambiguousImage }

class MessageIntentRouter {
  const MessageIntentRouter();

  MochiIntent classify(String input, {bool hasAttachedImage = false, bool hasRecentImage = false}) {
    final text = input.trim().toLowerCase();
    if (text.isEmpty) return MochiIntent.chat;

    final asksAboutImage = RegExp(
      r'\b(what\s+(?:is|are|does)|describe|explain|identify|read|analy[sz]e|inspect|translate|summari[sz]e)\b',
    ).hasMatch(text);
    final editing = RegExp(
      r'\b(edit|modify|remove|replace|recolor|retouch|enhance|upscale|inpaint|crop|change|make)\b',
    ).hasMatch(text);
    final mentionsExisting = RegExp(
      r'\b(this|that|the|my|uploaded|attached|previous|last|same|it|image|picture|photo|screenshot)\b',
    ).hasMatch(text);

    if (hasAttachedImage) {
      if (editing && RegExp(r'\b(edit|change|remove|replace|recolor|retouch|enhance|upscale|inpaint|crop|turn|make)\b').hasMatch(text)) {
        return MochiIntent.editImage;
      }
      if (asksAboutImage || text.isEmpty || mentionsExisting) {
        return MochiIntent.analyzeImage;
      }
      return MochiIntent.ambiguousImage;
    }

    // Negative intent takes priority: requests for prompts or discussion
    // should not accidentally cause paid image generation.
    if (RegExp(
      r'\b(how\s+to|how\s+do|why|what\s+is|what\s+are|explain|tutorial|prompt\s+for|write\s+(?:me\s+)?(?:a\s+)?prompt|ideas?\s+for)\b',
    ).hasMatch(text)) {
      return MochiIntent.chat;
    }

    if (hasRecentImage && editing && mentionsExisting &&
        RegExp(r'\b(change|edit|modify|remove|replace|add|make|turn|recolor|crop|upscale|enhance)\b').hasMatch(text)) {
      return MochiIntent.editImage;
    }

    if (RegExp(
      r'\b(generate|draw|illustrate|paint|render|design|sketch)\b',
    ).hasMatch(text) &&
        !RegExp(r'\b(don\x27t|do not|without)\s+(?:generate|draw|illustrate|paint|render|design|sketch)\b').hasMatch(text)) {
      return MochiIntent.generateImage;
    }

    if (RegExp(
      r'\b(create|make|produce|show\s+me|send\s+me)\b.*\b(image|picture|photo|artwork|illustration|drawing|portrait)\b',
    ).hasMatch(text)) {
      return MochiIntent.generateImage;
    }

    if (RegExp(r'\b(image|picture|photo|drawing)\b').hasMatch(text) &&
        RegExp(r'\b(can\s+you|could\s+you|would\s+you)\b').hasMatch(text)) {
      return MochiIntent.ambiguousImage;
    }
    return MochiIntent.chat;
  }
}
