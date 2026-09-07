/// The in-app keyboard for Naming, in two layouts.
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
/// TWO LAYOUTS, AND WHY BOTH EXIST
/// -------------------------------
/// [NamingKeyboardLayout.standard] is the default and is the layout the
/// patient's own phone or computer uses — Kedmanee for Thai, QWERTY for
/// English — with a shift key and both legends printed on every key, the
/// shifted one above. Anyone who already types Thai finds the keys where their
/// hands expect them.
///
/// [NamingKeyboardLayout.alphabetical] is a flat grid in dictionary order with
/// no shift: every character the patient can type is visible at once. Nothing
/// is hidden behind a modifier, so a patient who has never typed can find any
/// letter by scanning. It is offered as the alternative rather than the
/// default, because a familiar layout beats a discoverable one for most people
/// and the ones it does not suit are visible to whoever is administering the
/// test.
///
/// Which one suits a given patient is an empirical question this app cannot
/// answer, so it offers both. What it must not do is mix them: the layout is
/// recorded per item in the session trace, and the analysis page refuses to
/// compare typing timings across a change of layout, because a key that moved
/// is not the same measurement.
///
/// WHAT IS AND IS NOT COMPARABLE ACROSS PATIENTS
/// --------------------------------------------
/// The standard layout's keys are sized to fit the viewport, so **key size is
/// not constant across devices**. That is a deliberate trade made on
/// 2026-09-08: at a fixed 36 logical pixels the twelve-key Kedmanee number row
/// needs about 460 of them, and on a 393-pixel phone the last two keys of every
/// row sat off the right edge. A key that cannot be reached is worse than a key
/// whose size varies — the unreachable one does not just distort the timing,
/// it makes some characters untypeable.
///
/// So: the ORDER is fixed and identical for everyone; the SIZE follows the
/// screen. Within one patient on one device timings are comparable, which is
/// all the analysis page ever claims. Across devices they are not, and the
/// viewport width is recorded in the trace so that is checkable rather than
/// merely asserted.
///
/// The alphabet is COMPLETE in both layouts. Showing only the letters the
/// answer needs would turn naming into a puzzle with a much smaller search
/// space, which is a different task with a different difficulty.
library;

import 'package:flutter/material.dart';

import 'app_language.dart';

/// Fixed logical key size for the alphabetical grid, which wraps and so needs
/// no fitting.
const double keyWidth = 42;
const double keyHeight = 46;

/// The standard layout's key size on a screen wide enough for it. Narrower
/// screens scale down from here — see [fitStandardKeyWidth].
const double standardKeyWidth = 36;
const double standardKeyHeight = 50;

/// Below this a key is too small to hit reliably, so the keyboard scrolls
/// instead of shrinking further. Real Thai phone keyboards sit around 28.
const double minStandardKeyWidth = 22;

const double _keyGap = 3;

/// How far each row is indented, as a fraction of a key. Physical keyboards
/// stagger their rows and hands expect it.
const double _stagger = 0.4;

/// The largest key width at which every row of [rows] fits in [available].
///
/// Each row needs `stagger*i*w + n*(w + gap)`, so the binding row is whichever
/// minimises `(available - n*gap) / (stagger*i + n)`. Clamped at both ends: it
/// never grows past [standardKeyWidth], because a keyboard with enormous keys
/// on a desktop looks broken, and never shrinks past [minStandardKeyWidth],
/// below which the caller should scroll rather than keep scaling.
double fitStandardKeyWidth(List<List<KeyCap>> rows, double available) {
  var best = double.infinity;
  for (var i = 0; i < rows.length; i++) {
    final n = rows[i].length;
    final width = (available - n * _keyGap) / (_stagger * i + n);
    if (width < best) best = width;
  }
  if (best >= standardKeyWidth) return standardKeyWidth;
  // Shaved by a hundredth of a pixel, but only when actually scaling down,
  // because the exact solution lands on the wrong side of the boundary once
  // the division is done in binary: the fit for a 377-pixel viewport
  // multiplies back out to 377.00000000000006, and a row six ten-trillionths
  // of a pixel too wide is still an overflow stripe across the keyboard.
  return (best - 0.01).clamp(minStandardKeyWidth, standardKeyWidth);
}

/// Width the whole keyboard occupies at [width] per key.
double standardKeyboardWidth(List<List<KeyCap>> rows, double width) {
  var needed = 0.0;
  for (var i = 0; i < rows.length; i++) {
    final row = _stagger * i * width + rows[i].length * (width + _keyGap);
    if (row > needed) needed = row;
  }
  return needed;
}

enum NamingKeyboardLayout {
  /// Kedmanee (Thai) or QWERTY (English), with a shift key. The default.
  standard,

  /// Dictionary order, no shift. Every character visible at once.
  alphabetical,
}

/// One key: what it types unshifted, and what it types with shift held.
class KeyCap {
  final String base;
  final String? shifted;

  const KeyCap(this.base, [this.shifted]);
}

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

const List<String> kEnglishLetters = [
  'a', 'b', 'c', 'd', 'e', 'f', 'g', 'h', 'i', 'j', 'k', 'l', 'm',
  'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v', 'w', 'x', 'y', 'z',
];

/// Thai Kedmanee (TIS 820-2531), the layout on every Thai keyboard.
///
/// The number row is included because Thai needs it: ุ and ึ are unshifted on
/// 6 and 7, and ู — which อูฐ requires — is shift+6. Dropping the row to save
/// width would make one of the three test words untypeable.
const List<List<KeyCap>> kThaiStandardRows = [
  [
    KeyCap('ๅ', '+'), KeyCap('/', '๑'), KeyCap('_', '๒'), KeyCap('ภ', '๓'),
    KeyCap('ถ', '๔'), KeyCap('ุ', 'ู'), KeyCap('ึ', '฿'), KeyCap('ค', '๕'),
    KeyCap('ต', '๖'), KeyCap('จ', '๗'), KeyCap('ข', '๘'), KeyCap('ช', '๙'),
  ],
  [
    KeyCap('ๆ', '๐'), KeyCap('ไ', '"'), KeyCap('ำ', 'ฎ'), KeyCap('พ', 'ฑ'),
    KeyCap('ะ', 'ธ'), KeyCap('ั', 'ํ'), KeyCap('ี', '๊'), KeyCap('ร', 'ณ'),
    KeyCap('น', 'ฯ'), KeyCap('ย', 'ญ'), KeyCap('บ', 'ฐ'), KeyCap('ล', ','),
    // Kedmanee's backslash key. ฃ and ฅ are obsolete in modern writing and are
    // here for the same reason they are in the alphabetical grid: this is the
    // alphabet, not a curated subset, and the two layouts must offer the same
    // characters or switching between them changes what can be typed.
    KeyCap('ฃ', 'ฅ'),
  ],
  [
    KeyCap('ฟ', 'ฤ'), KeyCap('ห', 'ฆ'), KeyCap('ก', 'ฏ'), KeyCap('ด', 'โ'),
    KeyCap('เ', 'ฌ'), KeyCap('้', '็'), KeyCap('่', '๋'), KeyCap('า', 'ษ'),
    KeyCap('ส', 'ศ'), KeyCap('ว', 'ซ'), KeyCap('ง', '.'),
  ],
  [
    KeyCap('ผ', '('), KeyCap('ป', ')'), KeyCap('แ', 'ฉ'), KeyCap('อ', 'ฮ'),
    KeyCap('ิ', 'ฺ'), KeyCap('ื', '์'), KeyCap('ท', '?'), KeyCap('ม', 'ฒ'),
    KeyCap('ใ', 'ฬ'), KeyCap('ฝ', 'ฦ'),
  ],
];

/// QWERTY, shift giving capitals.
///
/// No digit row, unlike Kedmanee: no English animal name needs one, and a row
/// of keys that is never pressed is noise on a screen this size. Shift is
/// cosmetic here — the scorer lowercases both sides — but it is present because
/// a keyboard without one does not behave like the patient's own.
const List<List<KeyCap>> kEnglishStandardRows = [
  [
    KeyCap('q', 'Q'), KeyCap('w', 'W'), KeyCap('e', 'E'), KeyCap('r', 'R'),
    KeyCap('t', 'T'), KeyCap('y', 'Y'), KeyCap('u', 'U'), KeyCap('i', 'I'),
    KeyCap('o', 'O'), KeyCap('p', 'P'),
  ],
  [
    KeyCap('a', 'A'), KeyCap('s', 'S'), KeyCap('d', 'D'), KeyCap('f', 'F'),
    KeyCap('g', 'G'), KeyCap('h', 'H'), KeyCap('j', 'J'), KeyCap('k', 'K'),
    KeyCap('l', 'L'),
  ],
  [
    KeyCap('z', 'Z'), KeyCap('x', 'X'), KeyCap('c', 'C'), KeyCap('v', 'V'),
    KeyCap('b', 'B'), KeyCap('n', 'N'), KeyCap('m', 'M'),
  ],
];

List<List<KeyCap>> standardRows() =>
    AppLanguage.isEnglish ? kEnglishStandardRows : kThaiStandardRows;

/// Whether [character] is a Thai mark that attaches above, below or around a
/// consonant rather than standing on its own.
///
/// Only these get the dotted-circle placeholder. เ แ โ ใ ไ ๅ ๆ are full
/// characters that sit on the line like a consonant — printing them as ◌เ
/// would be wrong, and is what this file used to do.
bool isThaiCombining(String character) {
  if (character.isEmpty) return false;
  final code = character.codeUnitAt(0);
  return code == 0x0E31 || // ั
      (code >= 0x0E34 && code <= 0x0E3A) || // ิ ี ึ ื ุ ู ฺ
      (code >= 0x0E47 && code <= 0x0E4E); // ็ ่ ้ ๊ ๋ ์ ํ ๎
}

/// How a character is drawn on a keycap. U+25CC DOTTED CIRCLE is the Unicode
/// convention for showing a combining mark in isolation.
String keyLabel(String character) =>
    isThaiCombining(character) ? '◌$character' : character;

/// A fixed-layout keyboard that reports keystrokes rather than text.
class NamingKeyboard extends StatefulWidget {
  final NamingKeyboardLayout layout;

  /// One character was typed. For a shifted keypress this is the shifted
  /// character — the caller receives what was produced, not which key produced
  /// it plus a modifier state to reassemble.
  final void Function(String character) onCharacter;

  /// Backspace. Reported separately from [onCharacter] so a correction never
  /// has to be recovered by inspecting which key it was.
  final VoidCallback onBackspace;

  const NamingKeyboard({
    super.key,
    this.layout = NamingKeyboardLayout.standard,
    required this.onCharacter,
    required this.onBackspace,
  });

  @override
  State<NamingKeyboard> createState() => _NamingKeyboardState();
}

class _NamingKeyboardState extends State<NamingKeyboard> {
  /// One-shot, the way a phone keyboard behaves: shift applies to the next key
  /// and then releases itself. Sticky shift would need a second visual state to
  /// distinguish it from caps lock, and nothing on this subtest needs two
  /// shifted characters in a row.
  bool _shift = false;

  void _type(KeyCap cap) {
    widget.onCharacter(_shift ? (cap.shifted ?? cap.base) : cap.base);
    if (_shift) setState(() => _shift = false);
  }

  @override
  Widget build(BuildContext context) {
    return widget.layout == NamingKeyboardLayout.standard
        ? _buildStandard()
        : _buildAlphabetical();
  }

  Widget _buildAlphabetical() {
    final english = AppLanguage.isEnglish;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _KeyGroup(
          characters: english ? kEnglishLetters : kThaiConsonants,
          onCharacter: widget.onCharacter,
        ),
        if (!english) ...[
          const SizedBox(height: 6),
          // Vowels and tone marks are grouped below the consonants, and tinted,
          // because in Thai they are a different kind of thing — several of
          // them attach above or below the consonant rather than sitting
          // beside it, and a flat A-to-Z run would hide that.
          _KeyGroup(
            characters: kThaiMarks,
            onCharacter: widget.onCharacter,
            tinted: true,
          ),
        ],
        const SizedBox(height: 8),
        _backspace(width: keyWidth * 3, height: keyHeight),
      ],
    );
  }

  Widget _buildStandard() {
    final rows = standardRows();
    // Measured OUTSIDE any horizontal scroll view: inside one the width is
    // unbounded and there is nothing to fit to.
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final width = fitStandardKeyWidth(rows, available);
        final keyboard = _standardKeys(rows, width);

        // Scrolling is the last resort, reached only on a screen too narrow for
        // even the minimum key size. Everywhere else every key is on screen,
        // which is the point: a key reached by scrolling costs time that has
        // nothing to do with finding the word.
        return standardKeyboardWidth(rows, width) <= available
            ? keyboard
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal, child: keyboard);
      },
    );
  }

  Widget _standardKeys(List<List<KeyCap>> rows, double width) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < rows.length; i++)
          Padding(
            padding: EdgeInsets.only(
              // Staggered like a physical keyboard, so a patient who types on
              // one finds the keys where their hands expect them.
              left: _stagger * i * width,
              bottom: 4,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final cap in rows[i]) _StandardKey(
                  cap: cap,
                  shifted: _shift,
                  width: width,
                  onTap: () => _type(cap),
                ),
              ],
            ),
          ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: width * 2.5,
              height: standardKeyHeight,
              child: ElevatedButton(
                onPressed: () => setState(() => _shift = !_shift),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.zero,
                  // Lit while armed, so the patient can see that the next key
                  // will produce the character printed on top.
                  backgroundColor:
                      _shift ? Colors.blue.shade700 : Colors.grey.shade200,
                  foregroundColor: _shift ? Colors.white : Colors.black87,
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                    side: BorderSide(color: Colors.grey.shade400),
                  ),
                ),
                child: const Icon(Icons.arrow_upward, size: 18),
              ),
            ),
            const SizedBox(width: 4),
            _backspace(width: width * 2.5, height: standardKeyHeight),
          ],
        ),
      ],
    );
  }

  Widget _backspace({required double width, required double height}) {
    return SizedBox(
      width: width,
      height: height,
      child: OutlinedButton(
        onPressed: widget.onBackspace,
        style: OutlinedButton.styleFrom(
          padding: EdgeInsets.zero,
          foregroundColor: Colors.blue.shade900,
        ),
        child: const Icon(Icons.backspace_outlined, size: 20),
      ),
    );
  }
}

/// One standard-layout key, printing both legends the way a real keycap does:
/// the shifted character small and above, the unshifted one large and below.
class _StandardKey extends StatelessWidget {
  final KeyCap cap;
  final bool shifted;
  final double width;
  final VoidCallback onTap;

  const _StandardKey({
    required this.cap,
    required this.shifted,
    required this.width,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final upper = cap.shifted;
    // Type scales with the key, or a narrow phone gets legends wider than the
    // cap they sit on. Clamped so it never becomes unreadable at the low end
    // or cartoonish at the high one. The combining marks are the constraint:
    // they draw as two glyphs, "◌" plus the mark.
    final baseSize = (width * 0.5).clamp(11.0, 16.0);
    final upperSize = (width * 0.34).clamp(8.5, 11.0);
    return Padding(
      padding: const EdgeInsets.only(right: _keyGap),
      child: SizedBox(
        width: width,
        height: standardKeyHeight,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.zero,
            backgroundColor: Colors.white,
            foregroundColor: Colors.black87,
            elevation: 1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
              side: BorderSide(color: Colors.grey.shade400),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (upper != null)
                Text(
                  keyLabel(upper),
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: upperSize,
                    // Emphasis follows the shift key, so while shift is armed
                    // the legend that will actually be typed is the dark one.
                    color: shifted ? Colors.blue.shade800 : Colors.grey.shade600,
                    fontWeight: shifted ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              Text(
                keyLabel(cap.base),
                maxLines: 1,
                style: TextStyle(
                  fontSize: baseSize,
                  color: shifted ? Colors.grey.shade500 : Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ),
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
                keyLabel(character),
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ),
      ],
    );
  }
}
