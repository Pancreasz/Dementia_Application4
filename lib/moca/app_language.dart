/// The test's administration language. Set once, from the home page, before
/// the patient starts — nothing mid-session switches it, so every page just
/// reads [AppLanguage.current] at build time rather than listening for
/// changes.
enum Language { th, en }

class AppLanguage {
  static Language current = Language.th;

  static bool get isEnglish => current == Language.en;
}

/// Picks between a Thai and an English string. The common shape every page
/// uses to localize its literals inline.
String t(String th, String en) => AppLanguage.isEnglish ? en : th;

/// MoCA section headings. Subtest specs only carry the Thai name (it doubles
/// as a stable key elsewhere), so this is the one place the English label is
/// looked up from it.
const Map<String, String> _sectionLabelsEn = {
  'สมาธิ': 'Attention',
  'ภาษา': 'Language',
  'ความคิดรวบยอด': 'Abstraction',
  'การรับรู้เวลาและสถานที่': 'Orientation',
};

String sectionLabel(String thaiSection) =>
    AppLanguage.isEnglish ? (_sectionLabelsEn[thaiSection] ?? thaiSection) : thaiSection;

/// SessionTotal.category returns one of these fixed Thai strings (its own
/// tests pin the Thai text, so that getter stays as-is); this is the one
/// place the English label is looked up from it.
const Map<String, String> _categoryLabelsEn = {
  'ปกติ': 'Normal',
  'บกพร่องเล็กน้อย': 'Mild impairment',
  'มีความบกพร่อง': 'Impaired',
  'เสี่ยงสูง': 'High risk',
};

String categoryLabel(String thaiCategory) =>
    AppLanguage.isEnglish ? (_categoryLabelsEn[thaiCategory] ?? thaiCategory) : thaiCategory;
