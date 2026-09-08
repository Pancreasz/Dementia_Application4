import 'dart:async';

import 'package:flutter/material.dart';
import '../moca/app_language.dart';
import '../moca/asset_preload.dart';
import '../moca/live_session.dart';
import '../moca/session_record.dart';
import '../moca/session_store.dart';
import 'score.dart';

void resetScores() {
  animalScore = 0;
  larkScore = 0;
  clockScore = 0;
  totalScore = 0;
  attentionScore = 0;
  reorderScore = 0;
  correctOrder.clear();
  voiceOutcomes.clear();
}

/// Clears the previous assessment and opens a durable record for the new one.
///
/// Deliberately a NEW session rather than resuming an unfinished one: pressing
/// "start test" is an explicit statement that a new assessment is beginning,
/// and silently dropping the clinician into a half-finished stranger's session
/// would be worse than losing it. The old record stays on disk either way —
/// `LiveSession.start` never deletes anything.
Future<void> beginSession() async {
  resetScores();
  LiveSession.clearCurrent();
  await LiveSession.start();
}

class HomePage extends StatefulWidget {
  /// Injectable so the resume offer can be tested. `flutter test` cannot
  /// resolve the real documents directory, so without this the resume path
  /// would be untestable UI — which is the state the persistence layer was
  /// already in before it was wired up here.
  final SessionStore? store;

  const HomePage({super.key, this.store});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// An unfinished session found on disk at launch, or null.
  ///
  /// Without this the persistence layer would be write-only: sessions would be
  /// saved faithfully and never offered back, which is most of the work and
  /// none of the benefit.
  SessionRecord? _resumable;

  @override
  void initState() {
    super.initState();
    _checkForResumable();
    // Fire-and-forget, from the first screen the patient ever sees, so the
    // naming animals and the trail-making GIF are already decoded by the time
    // their pages open — see asset_preload.dart for why this matters on web.
    // Needs a BuildContext with a mounted asset bundle above it, hence the
    // post-frame callback rather than calling it directly from initState.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(preloadAppImages(context));
    });
  }

  Future<void> _checkForResumable() async {
    // Storage failures are not surfaced to the clinician: a missing resume
    // offer is indistinguishable from having nothing to resume, and neither is
    // worth an error dialog on the home screen.
    try {
      final found = await (widget.store ?? SessionStore()).loadResumable();
      if (mounted) setState(() => _resumable = found);
    } catch (_) {}
  }

  /// Picks up the unfinished session and jumps to where it left off.
  ///
  /// Deliberately returns to the FIRST subtest rather than trying to work out
  /// which screen the patient was on. The record knows what was scored, not
  /// where the patient stood, and guessing wrong would re-administer a subtest
  /// that already has a score — a practice effect on a real assessment. The
  /// clinician can skip forward; the app must not invent a position.
  Future<void> _resume() async {
    await LiveSession.resumeOrStart(store: widget.store);
    if (!mounted) return;
    Navigator.pushNamed(context, '/larksen');
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Text(
                          t('ข้อตกลงในการใช้ซอฟต์แวร์', 'License Agreement'),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[800],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 15),
                        const Text(
                          'ซอฟต์แวร์นี้เป็นผลงานที่พัฒนาขึ้นโดย นาย ภูมศิน แพใหญ่ และ นาย ธนาธาร ชาญศึก จาก มหาวิทยาลัยเทคโนโลยีพระจอมเกล้าพระนครเหนือ ภายใต้การดูแลของ ดร. วีระ สอิ้ง ภายใต้โครงการ แอปพลิเคชันเพื่อคัดกรองภาวะสมองเสื่อมเบื้องต้นด้วยตนเอง ซึ่งสนับสนุนโดย สำนักงานพัฒนาวิทยาศาสตร์และเทคโนโลยีแห่งชาติโดยมีวัตถุประสงค์เพื่อส่งเสริมให้นักเรียนและนักศึกษาได้เรียนรู้และฝึกทักษะในการพัฒนาซอฟต์แวร์ลิขสิทธิ์ของซอฟต์แวร์นี้จึงเป็น ของผู้พัฒนา ซึ่งผู้พัฒนาได้อนุญาตให้สำนักงานพัฒนาวิทยาศาสตร์และเทคโนโลยีแห่งชาติเผยแพร่ซอฟต์แวร์นี้ตาม "ต้นฉบับ" โดยไม่มีการแก้ไขดัดแปลงใด ๆ ท้ังสิ้น ให้แก่บุคคลทั่วไปได้ใช้เพื่อประโยชน์ส่วนบุคคลหรือประโยชน์ทางการศึกษาที่ไม่มีวัตถุประสงค์ในเชิงพาณิชย์โดยไม่คิดค่าตอบแทนการใช้ซอฟต์แวร์ดังนั้น สำนักงานพัฒนาวิทยาศาสตร์และเทคโนโลยีแห่งชาติจึงไม่มีหน้าที่ในการดูแล บำรุงรักษา จัดการอบรมการใช้งาน หรือพัฒนาประสิทธิภาพซอฟต์แวร์ รวมทั้งไม่รับรองความถูกต้องหรือประสิทธิภาพการทำงานของซอฟต์แวร์ ตลอดจนไม่รับประกันความเสียหายต่าง ๆ อันเกิดจากการใช้ซอฟต์แวร์นี้ท้ังสิ้น\n\nLicense Agreement\nThis software is a work developed by Mr. Pumasin Paeyai and Mr. Thanatarn Chansuk from King Mongkut\'s University of Technology North Bangkok under the provision of Vera sa-ing under AI Self-Assessment Tools for Preliminary Dementia Screening : AI-SADS, which has been supported by the National Science and Technology Development Agency (NSTDA), in order to encourage pupils and students to learn and practice their skills in developing software. Therefore, the intellectual property of this software shall belong to the developer and the developer gives NSTDA a permission to distribute this software as an "as is" and non-modified software for a temporary and non-exclusive use without remuneration to anyone for his or her own purpose or academic purpose, which are not commercial purposes. In this connection, NSTDA shall not be responsible to the user for taking care, maintaining, training, or developing the efficiency of this software. Moreover, NSTDA shall not be liable for any error, software efficiency and damages in connection with or arising out of the use of the software.',
                          textAlign: TextAlign.justify,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 40, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(t('ตกลง', 'OK')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(""),
        centerTitle: true,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(context),
            tooltip: 'Help',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t('แบบทดสอบโรคประสาทเสื่อม', 'Dementia Screening Test'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue[800],
              ),
            ),
            const SizedBox(height: 20),
            // Switches the whole session's language. Read once per page at
            // build time, so it must be set here, before the test starts —
            // nothing downstream listens for a change mid-session.
            _LanguageToggle(
              onChanged: () => setState(() {}),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 5,
              ),
              onPressed: () {
                // Not awaited: the first subtest must appear immediately, and
                // the write is small. Anything scored before it lands is still
                // captured, because every subtest saves the whole record
                // rather than an increment.
                unawaited(beginSession());
                Navigator.pushNamed(context, '/larksen');
              },
              child: Text(
                t('เริ่มทำแบบทดสอบ', 'Start Test'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (_resumable != null) ...[
              const SizedBox(height: 16),
              // Offered below "start test", never instead of it. A stale record
              // from a previous patient must not be the prominent action, and
              // starting fresh has to stay the obvious default.
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.blue[800],
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: _resume,
                child: Text(
                  t('ทำแบบทดสอบที่ค้างไว้ต่อ', 'Resume unfinished test'),
                  style: const TextStyle(fontSize: 16),
                ),
              ),
              const SizedBox(height: 4),
              // The start time, so a clinician can tell whether this is the
              // patient in front of them or yesterday's abandoned session.
              Text(
                t('เริ่มเมื่อ ${_formatStarted(_resumable!.startedAt)}',
                    'Started ${_formatStarted(_resumable!.startedAt)}'),
                style: TextStyle(fontSize: 13, color: Colors.grey[700]),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _formatStarted(DateTime at) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${at.year}-${two(at.month)}-${two(at.day)} '
        '${two(at.hour)}:${two(at.minute)}';
  }
}

/// Two-way TH/EN switch. A plain pair of buttons rather than a single toggle
/// so both states are always visible — the alternative (one button whose
/// label names the *other* language) is a well-known source of "what
/// language am I about to switch to" confusion.
class _LanguageToggle extends StatelessWidget {
  final VoidCallback onChanged;

  const _LanguageToggle({required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _langButton('ไทย', Language.th),
        const SizedBox(width: 8),
        _langButton('English', Language.en),
      ],
    );
  }

  Widget _langButton(String label, Language language) {
    final selected = AppLanguage.current == language;
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: selected ? Colors.blue[800] : Colors.grey[300],
        foregroundColor: selected ? Colors.white : Colors.black87,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: selected ? 3 : 0,
      ),
      onPressed: () {
        AppLanguage.current = language;
        onChanged();
      },
      child: Text(label),
    );
  }
}