import 'package:flutter_test/flutter_test.dart';
import 'package:portable_ai_flutter/services/message_intent_router.dart';

void main() {
  const router = MessageIntentRouter();

  test('clear generation commands route to image generation', () {
    expect(router.classify('Draw a pink castle'), MochiIntent.generateImage);
    expect(router.classify('Generate an image of a cat'), MochiIntent.generateImage);
    expect(router.classify('Create a picture of a fairy forest'), MochiIntent.generateImage);
  });

  test('ordinary chat and requests about image prompts stay chat', () {
    expect(router.classify('Explain image generation'), MochiIntent.chat);
    expect(router.classify('Write me a prompt for an image'), MochiIntent.chat);
    expect(router.classify('Generate a summary'), MochiIntent.chat);
    expect(router.classify('What is a diffusion model?'), MochiIntent.chat);
  });

  test('recent image enables contextual edits', () {
    expect(router.classify('Make it nighttime', hasRecentImage: true), MochiIntent.editImage);
    expect(router.classify('Make it nighttime'), MochiIntent.chat);
    expect(router.classify('Remove the background', hasAttachedImage: true), MochiIntent.editImage);
  });

  test('photo questions with attachment route to analysis', () {
    expect(router.classify('What is this?', hasAttachedImage: true), MochiIntent.analyzeImage);
    expect(router.classify('Describe this screenshot', hasAttachedImage: true), MochiIntent.analyzeImage);
  });
}
