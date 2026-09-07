/// Activities linked to the MoCA domains.
///
/// WHAT THE EVIDENCE ACTUALLY SUPPORTS
/// -----------------------------------
/// The strongest evidence in dementia risk reduction is for interventions that
/// are NOT domain-specific: physical exercise (aerobic in particular), hearing
/// correction where there is hearing loss, blood-pressure control, sleep,
/// social engagement, smoking cessation.
///
/// Evidence that domain-targeted cognitive training improves the targeted
/// domain is weak — gains tend to appear on the trained task itself rather than
/// transferring to daily function. A per-domain list is intuitive and good UX,
/// but it is scientifically thin. So every item here is phrased as *an activity
/// that engages this domain*, never *this will improve your score*, and
/// [generalRecommendations] — the ones that do have evidence — are shown
/// alongside every domain rather than as an afterthought.
///
/// WHY THERE ARE NO MoCA-LIKE TASKS HERE
/// -------------------------------------
/// Practising trail-making, digit span, serial 7s or letter fluency
/// contaminates the patient's own follow-up screening: practice effects make a
/// repeat MoCA uninterpretable against its norms. An app that scores a patient
/// and then hands them practice at the same tasks can invalidate their next
/// assessment. Everything below is deliberately non-task-specific — if an item
/// is ever added that resembles a subtest, that is a bug, not an enhancement.
library;

import 'app_language.dart';

/// One MoCA domain and the activities that engage it.
class ActivityDomain {
  /// Stable key, also used to line a domain up with the subtests that feed it.
  final String id;

  final String nameTh;
  final String nameEn;

  final List<String> activitiesTh;
  final List<String> activitiesEn;

  /// Shown under the list where a domain needs it — memory's activities are
  /// compensation rather than repair, and saying so is part of not overclaiming.
  final String? noteTh;
  final String? noteEn;

  const ActivityDomain({
    required this.id,
    required this.nameTh,
    required this.nameEn,
    required this.activitiesTh,
    required this.activitiesEn,
    this.noteTh,
    this.noteEn,
  });

  String get name => t(nameTh, nameEn);
  List<String> get activities => AppLanguage.isEnglish ? activitiesEn : activitiesTh;
  String? get note => AppLanguage.isEnglish ? noteEn : noteTh;
}

const List<ActivityDomain> kActivityDomains = [
  ActivityDomain(
    id: 'visuospatial-executive',
    nameTh: 'การมองเห็นเชิงมิติ และการบริหารจัดการ',
    nameEn: 'Visuospatial / Executive',
    activitiesTh: [
      'วาดรูปหรือสเก็ตช์ภาพ',
      'ต่อจิ๊กซอว์',
      'งานประกอบหรืองานก่อสร้างชิ้นเล็ก ๆ',
      'เดินสำรวจเส้นทางใหม่ ๆ',
      'ทำสวน',
      'ทำอาหารจากสูตรที่ไม่เคยทำ',
    ],
    activitiesEn: [
      'Drawing and sketching',
      'Jigsaw puzzles',
      'Assembly and construction tasks',
      'Navigating new routes on foot',
      'Gardening',
      'Cooking from an unfamiliar recipe',
    ],
  ),
  ActivityDomain(
    id: 'naming-language',
    nameTh: 'การเรียกชื่อ และภาษา',
    nameEn: 'Naming / Language',
    activitiesTh: [
      'อ่านออกเสียง',
      'สนทนาต่อเนื่องเป็นเรื่องเป็นราว',
      'บรรยายภาพถ่ายหรือเหตุการณ์อย่างละเอียด',
      'เล่นเกมคำศัพท์ที่ไม่ได้อิงกับตัวอักษรขึ้นต้น',
      'จำเนื้อเพลง',
    ],
    activitiesEn: [
      'Reading aloud',
      'Sustained conversation',
      'Describing photographs or events in detail',
      'Word games not based on initial letters',
      'Learning song lyrics',
    ],
    // Named explicitly because letter-based word games ARE the fluency subtest.
    noteTh: 'เกมคำศัพท์ที่ให้บอกคำขึ้นต้นด้วยตัวอักษรที่กำหนด ถูกเว้นไว้โดยตั้งใจ '
        'เพราะเป็นแบบทดสอบเดียวกับที่ใช้ประเมิน',
    noteEn: 'Word games based on a given initial letter are deliberately left '
        'out: they are the same task the assessment uses.',
  ),
  ActivityDomain(
    id: 'attention',
    nameTh: 'สมาธิ',
    nameEn: 'Attention',
    activitiesTh: [
      'ทำทีละอย่าง แทนการทำหลายอย่างพร้อมกัน',
      'ลดสิ่งรบกวนรอบตัว เช่น ปิดโทรทัศน์ขณะสนทนา',
      'รักษากิจวัตรประจำวันให้สม่ำเสมอ',
      'รักษาคุณภาพการนอน ซึ่งส่งผลต่อสมาธิมากกว่าปัจจัยอื่นที่ปรับได้',
      'ตรวจการได้ยิน เพราะการฟังที่ต้องใช้ความพยายามกินสมาธิโดยตรง',
    ],
    activitiesEn: [
      'Single-tasking rather than multitasking',
      'Reducing background distraction (television off during conversation)',
      'A regular daily routine',
      'Treating sleep problems, which degrade attention more than almost '
          'anything else modifiable',
      'A hearing check, since effortful listening consumes attention directly',
    ],
  ),
  ActivityDomain(
    id: 'memory',
    nameTh: 'ความจำ',
    nameEn: 'Memory',
    activitiesTh: [
      'วางกุญแจและแว่นตาไว้ที่เดิมทุกครั้ง',
      'ใช้ปฏิทินหรือสมุดบันทึกเป็นประจำทุกวัน',
      'รักษากิจวัตรประจำวันให้สม่ำเสมอ',
      'พูดชื่อสิ่งของออกเสียงเมื่อวางลง',
    ],
    activitiesEn: [
      'A consistent place for keys and glasses',
      'A calendar or notebook used daily',
      'A consistent daily routine',
      'Naming things aloud when putting them down',
    ],
    noteTh: 'สิ่งเหล่านี้เป็นวิธีลดผลกระทบจากปัญหาความจำ ไม่ใช่การฝึกเพื่อซ่อมแซมความจำ',
    noteEn: 'These are strategies that reduce the impact of memory difficulty, '
        'not exercises that repair memory.',
  ),
  ActivityDomain(
    id: 'abstraction-reasoning',
    nameTh: 'ความคิดรวบยอด และการให้เหตุผล',
    nameEn: 'Abstraction / Reasoning',
    activitiesTh: [
      'พูดคุยแลกเปลี่ยนเรื่องข่าว ภาพยนตร์ หรือหนังสือ',
      'เล่นเกมที่ใช้กลยุทธ์ เช่น หมากรุก ไพ่ โกะ',
      'อธิบายเรื่องที่รู้ให้คนอื่นฟัง',
      'ทำกิจกรรมกลุ่มที่ต้องแก้ปัญหาร่วมกัน',
    ],
    activitiesEn: [
      'Discussion of news, films and books',
      'Strategy games (chess, cards, Go)',
      'Explaining a topic to someone else',
      'Group activities with shared problem-solving',
    ],
  ),
  ActivityDomain(
    id: 'orientation',
    nameTh: 'การรับรู้เวลาและสถานที่',
    nameEn: 'Orientation',
    activitiesTh: [
      'ติดปฏิทินขนาดใหญ่ไว้บนผนัง และทำเครื่องหมายวันที่ทุกวัน',
      'ทบทวนวันและวันที่เป็นส่วนหนึ่งของกิจวัตรตอนเช้า',
      'รับแสงธรรมชาติและเข้านอนให้เป็นเวลา ซึ่งช่วยยึดการรับรู้กลางวันกลางคืน',
    ],
    activitiesEn: [
      'A visible wall calendar with the date marked daily',
      'A morning routine that includes checking the day and date',
      'Consistent light exposure and sleep timing, which anchor day-night '
          'orientation',
    ],
  ),
];

/// Shown with EVERY domain, not as a separate section.
///
/// These are the recommendations with real evidence behind them. Presenting
/// them alongside each domain is deliberate: a page that leads with
/// domain-specific cognitive activities and buries exercise at the bottom gets
/// the strength of the evidence exactly backwards.
const List<String> _generalTh = [
  'ออกกำลังกายสม่ำเสมอ — เป็นคำแนะนำที่มีน้ำหนักมากที่สุดเพียงข้อเดียว',
  'พบปะผู้คนอย่างสม่ำเสมอ',
  'นอนหลับให้เพียงพอ',
  'แก้ไขการได้ยินและการมองเห็น',
  'ดูแลความดันโลหิต เบาหวาน และไขมัน ร่วมกับแพทย์ประจำตัว',
];

const List<String> _generalEn = [
  'Regular physical activity — the strongest single recommendation',
  'Social contact',
  'Adequate sleep',
  'Hearing and vision correction',
  'Management of blood pressure, diabetes and cholesterol with their doctor',
];

List<String> get generalRecommendations =>
    AppLanguage.isEnglish ? _generalEn : _generalTh;

/// The framing the page is required to state.
///
/// Not boilerplate. A screening app that reports impairment and then prescribes
/// a response is one reading away from being taken as diagnosis plus treatment
/// plan; this is the thing that keeps the page's role honest. It is returned
/// from here rather than written inline in the widget so it cannot be quietly
/// dropped in a layout change without the test noticing.
List<String> get requiredFraming => AppLanguage.isEnglish
    ? const [
        'These are general suggestions, not treatment.',
        'This app is a screening tool, not a diagnosis.',
        'Discuss your results with a doctor.',
      ]
    : const [
        'ข้อมูลนี้เป็นคำแนะนำทั่วไป ไม่ใช่การรักษา',
        'แอปนี้เป็นเครื่องมือคัดกรองเบื้องต้น ไม่ใช่การวินิจฉัยโรค',
        'ควรนำผลไปปรึกษาแพทย์',
      ];

ActivityDomain? domainById(String id) {
  for (final domain in kActivityDomains) {
    if (domain.id == id) return domain;
  }
  return null;
}
