/// The in-app keyboard for Naming.
///
/// WHY THE APP DRAWS ITS OWN KEYBOARD
/// ----------------------------------
/// Two reasons, and only one of them is measurement.
///
/// The first is that the system keyboard is not a controlled surface. It
/// autocorrects, it suggests whole words, its size and layout depend on the
/// device and on settings the patient chose years ago, and on Thai it may
/// predict "อูฐ" from the first consonant. A naming subtest scored on a word
/// the keyboard supplied is not measuring naming.
///
/// The second is that the improvement plan's naming measurements — time to
/// first keypress, inter-key intervals, corrections — need key events, and the
/// system keyboard gives Flutter a text value rather than keystrokes on web.
///
/// WHAT IS AND IS NOT COMPARABLE ACROSS PATIENTS
/// --------------------------------------------
/// Keys are a fixed logical size ([keyWidth] x [keyHeight]) in a fixed order,
/// so the layout does not change from patient to patient. It can still change
/// from DEVICE to device: logical pixels are not millimetres, and a narrower
/// screen wraps the rows differently, which changes how far a finger travels.
/// Within one patient on one device the timings are comparable; across
/// patients they are comparable only on the same hardware. The analysis page
/// leans on within-patient comparison for exactly this reason.
///
/// The alphabet is COMPLETE. Showing only the letters the answer needs would
/// turn naming into a puzzle with a much smaller search space, which is a
/// different task with a different difficulty.
library;

import 'package:flutter/material.dart';

import 'app_language.dart';

/// Fixed logical key size. See the library comment on what this does and does
/// not make comparable.
const double keyWidth = 42;
const double keyHeight = 46;

/// The 44 Thai consonants in dictionary order.
///
/// ฃ and ฅ are obsolete in modern writing and are here anyway: this is the
/// alphabet, not a curated subset, and a patient hunting for ค should not find
/// a gap where ฅ ought to be.
const List<String> kThaiConsonants = [
  'ก', 'ข', 'ฃ', 'ค', 'ฅ', 'ฆ', 'ง', 'จ', 'ฉ', 'ช', 'ซ',
  'ฌ', 'ญ', 'ฎ', 'ฏ', 'ฐ', 'ฑ', 'ฒ', 'ณ', 'ด', 'ต', 'ถ',
  'ท', 'ธ', 'น', 'บ', 'ป', 'ผ', 'ฝ', 'พ', 'ฟ', 'ภ', 'ม',
  'ย', 'ร', 'ล', 'ว', 'ศ', 'ษ', 'ส', 'ห', 'ฬ', 'อ', 'ฮ',
];

/// Vowels and tone marks, in the order they are taught.
const List<String> kThaiMarks = [
  'ะ', 'ั', 'า', 'ำ', 'ิ', 'ี', 'ึ', 'ื',
  'ุ', 'ู', 'เ', 'แ', 'โ', 'ใ', 'ไ', 'ๅ',
  '่', '้', '๊', '๋', '็', '์', 'ๆ',
];

/// Alphabetical rather than Kedmanee (the Thai typewriter layout).
///
/// Kedmanee is faster for anyone who already touch-types Thai and close to
/// unusable for anyone who does not, because its key positions carry no
/// relationship to the alphabet. This population skews elderly and
/// device-unfamiliar, so findability wins over speed — and speed in absolute
/// terms is not what is being measured anyway, only its shape within one
/// patient.
const List<String> kEnglishLetters = [
  'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm',
  'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
];

/// Every key that can be typed in the current language, in display order.
List<String> keyboardCharacters() => AppLanguage.isEnglish
    ? kEnglishLetters
    : [...kThaiConsonants, ...kThaiMarks];

/// A fixed-layout keyboard that reports keystrokes rather than text.
class NamingKeyboard extends StatelessWidget {
  /// One character was typed.
  final void Function(String character) onCharacter;

  /// Backspace. Reported separately from [onCharacter] so a correction never
  /// has to be recovered by inspecting which key it was.
  final VoidCallback onBackspace;

  const NamingKeyboard({
    super.key,
    required this.onCharacter,
    required this.onBackspace,
  });

  @override
  Widget build(BuildContext context) {
    final english = AppLanguage.isEnglish;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _KeyGroup(
          characters: english ? kEnglishLetters : kThaiConsonants,
          onCharacter: onCharacter,
        ),
        if (!english) ...[
          const SizedBox(height: 6),
          // Vowels and tone marks are grouped below the consonants, and tinted,
          // because in Thai they are a different kind of thing — several of
          // them attach above or below the consonant rather than sitting
          // beside it, and a flat A-to-Z run would hide that.
          _KeyGroup(
            characters: kThaiMarks,
            onCharacter: onCharacter,
            tinted: true,
          ),
        ],
        const SizedBox(height: 8),
        SizedBox(
          width: keyWidth * 3,
          height: keyHeight,
          child: OutlinedButton(
            onPressed: onBackspace,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: Colors.blue.shade900,
            ),
            child: const Icon(Icons.backspace_outlined, size: 20),
          ),
        ),
      ],
    );
  }
}

class _KeyGroup extends StatelessWidget {
  final List<String> characters;
  final void Function(String) onCharacter;
  final bool tinted;

  const _KeyGroup({
    required this.characters,
    required this.onCharacter,
    this.tinted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 3,
      runSpacing: 3,
      children: [
        for (final character in characters)
          SizedBox(
            width: keyWidth,
            height: keyHeight,
            child: ElevatedButton(
              onPressed: () => onCharacter(character),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.zero,
                backgroundColor: tinted ? Colors.blue.shade50 : Colors.white,
                foregroundColor: Colors.black87,
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                  side: BorderSide(color: Colors.grey.shade400),
                ),
              ),
              child: Text(
                // A bare Thai vowel or tone mark renders as a floating
                // diacritic with nothing to attach to. The dotted circle is
                // the Unicode convention for showing one in isolation.
                tinted ? '◌$character' : character,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
      ],
    );
  }
}
