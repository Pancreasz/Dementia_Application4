import 'package:flutter_test/flutter_test.dart';
import 'package:moca_main/moca/app_language.dart';
import 'package:moca_main/moca/subtest_spec.dart';
import 'package:moca_main/moca/subtests.dart';

void main() {
  test('every subtest has English instruction text', () {
    for (final spec in kVoiceSubtests) {
      expect(spec.instructionEn.trim(), isNotEmpty, reason: spec.id);
    }
  });

  test('every subtest with a stimulus by design also has an English one', () {
    for (final spec in kVoiceSubtests) {
      if (spec.stimulusAsset != null) {
        expect(spec.stimulusAssetEn, isNotNull, reason: spec.id);
      } else {
        expect(spec.stimulusAssetEn, isNull, reason: spec.id);
      }
    }
  });

  test('verbal fluency asks for the letter F in English mode', () {
    final fluency = kVoiceSubtests.firstWhere((s) => s.id == 'verbal-fluency');
    expect(fluency.initialLetter, 'ก');
    expect(fluency.initialLetterEn, 'F');
  });

  group('SubtestSpec language resolution', () {
    tearDown(() => AppLanguage.current = Language.th);

    test('instruction/stimulus/sentence/letter fall back to Thai by default', () {
      final spec = kVoiceSubtests.firstWhere((s) => s.id == 'sentence-repetition-1');
      expect(spec.instruction, spec.instructionTh);
      expect(spec.stimulusAssetForLanguage, spec.stimulusAsset);
      expect(spec.expectedSentenceForLanguage, spec.expectedSentence);
    });

    test('switch to English resolves the English fields instead', () {
      AppLanguage.current = Language.en;
      final spec = kVoiceSubtests.firstWhere((s) => s.id == 'sentence-repetition-1');
      expect(spec.instruction, spec.instructionEn);
      expect(spec.stimulusAssetForLanguage, spec.stimulusAssetEn);
      expect(spec.expectedSentenceForLanguage, spec.expectedSentenceEn);

      final fluency = kVoiceSubtests.firstWhere((s) => s.id == 'verbal-fluency');
      expect(fluency.initialLetterForLanguage, 'F');
    });
  });

  test('covers exactly the nine planned subtests, in administration order', () {
    expect(kVoiceSubtests.map((s) => s.id).toList(), [
      'digit-span-forward',
      'digit-span-backward',
      'vigilance',
      'sentence-repetition-1',
      'sentence-repetition-2',
      'verbal-fluency',
      'abstraction-1',
      'abstraction-2',
      'orientation',
    ]);
  });

  test('adds up to 14 points', () {
    final total =
        kVoiceSubtests.fold<int>(0, (sum, s) => sum + s.maxScore);
    expect(total, 14);
  });

  test('every subtest has Thai instruction text', () {
    for (final spec in kVoiceSubtests) {
      expect(spec.instructionTh.trim(), isNotEmpty, reason: spec.id);
    }
  });

  // Only Verbal Fluency has a normed deadline. Enforcing one anywhere else
  // would cut off a slow but correct patient and manufacture a wrong score.
  test('only verbal fluency enforces a time limit', () {
    final enforced =
        kVoiceSubtests.where((s) => s.enforceTimeLimit).map((s) => s.id);
    expect(enforced, ['verbal-fluency']);
  });

  test('verbal fluency is exactly 60 seconds', () {
    final fluency = kVoiceSubtests.firstWhere((s) => s.id == 'verbal-fluency');
    expect(fluency.timeLimitSec, 60);
  });

  test('vigilance is the only tap subtest', () {
    final tap = kVoiceSubtests
        .where((s) => s.responseMode == ResponseMode.tap)
        .map((s) => s.id);
    expect(tap, ['vigilance']);
  });

  // A single wrong digit here changes every score the subtest produces and
  // looks completely normal, so its shape is asserted rather than trusted.
  group('the vigilance sequence', () {
    test('is 29 digits long', () {
      expect(kVigilanceSequence.length, 29);
    });

    test('contains 11 targets', () {
      expect(kVigilanceSequence.split('').where((d) => d == '1').length, 11);
    });

    test('is all digits', () {
      expect(RegExp(r'^\d+$').hasMatch(kVigilanceSequence), isTrue);
    });

    // The structurally important part: three consecutive targets are where a
    // patient tapping perseveratively and one genuinely tracking produce
    // identical output, and the non-target that follows separates them.
    test('has three consecutive targets at positions 18-20', () {
      expect(kVigilanceSequence.substring(18, 21), '111');
      expect(kVigilanceSequence[21], isNot('1'));
    });
  });

  test('digit span expects the sequences from the Thai form', () {
    final forward =
        kVoiceSubtests.firstWhere((s) => s.id == 'digit-span-forward');
    final backward =
        kVoiceSubtests.firstWhere((s) => s.id == 'digit-span-backward');

    expect(forward.expectedSequence, '21854');
    // The patient hears 742 and must say it reversed.
    expect(backward.expectedSequence, '247');
  });

  // Declaring the path rather than leaving it null is the whole point. Null
  // means "this subtest has no stimulus by design", which is true of
  // Abstraction and Orientation — the controller opens the microphone
  // immediately for those. If sentence repetition were null too, the
  // controller could not tell the two apart and would record the patient
  // answering a sentence they never heard.
  test('sentence repetition declares both a stimulus and a sentence', () {
    final items =
        kVoiceSubtests.where((s) => s.id.startsWith('sentence-repetition')).toList();
    expect(items.length, 2);
    for (final spec in items) {
      expect(spec.stimulusAsset, isNotNull, reason: spec.id);
      expect(spec.expectedSentence, isNotNull, reason: spec.id);
      expect(spec.expectedSentence!.trim(), isNotEmpty, reason: spec.id);
    }
  });

  // The scorer compares speech against expectedSentence while the patient
  // hears stimulusAsset. Nothing in the type system ties the two together, so
  // a mismatched pair would score every patient against a sentence they never
  // heard — and look completely normal.
  test('each sentence item pairs its own asset with its own sentence', () {
    final one =
        kVoiceSubtests.firstWhere((s) => s.id == 'sentence-repetition-1');
    final two =
        kVoiceSubtests.firstWhere((s) => s.id == 'sentence-repetition-2');

    expect(one.stimulusAsset, 'assets/moca/audio/sentence-1.wav');
    expect(two.stimulusAsset, 'assets/moca/audio/sentence-2.wav');
    expect(one.expectedSentence, isNot(two.expectedSentence));
  });

  test('subtests with no stimulus by design declare none', () {
    for (final id in ['abstraction-1', 'abstraction-2', 'orientation', 'verbal-fluency']) {
      expect(kVoiceSubtests.firstWhere((s) => s.id == id).stimulusAsset, isNull,
          reason: id);
    }
  });

  test('subtests that need stimulus audio name a wav asset', () {
    final withAudio =
        kVoiceSubtests.where((s) => s.stimulusAsset != null);
    for (final spec in withAudio) {
      expect(spec.stimulusAsset, endsWith('.wav'), reason: spec.id);
      expect(spec.stimulusAsset, startsWith('assets/moca/audio/'),
          reason: spec.id);
    }
  });
}
