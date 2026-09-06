import 'subtest_spec.dart';

/// Vigilance: the patient taps every time they hear the target digit. Straight
/// from the Thai MoCA-Basic form — 29 digits, 11 of them targets.
///
/// The three consecutive targets at positions 18-20 are the structurally
/// important part: they are where a patient tapping perseveratively and one
/// genuinely tracking produce identical output, and the non-target that
/// follows separates them. A test asserts this shape.
const String kVigilanceSequence = '52139411806215194511141905112';

/// Silence between the instruction and the first digit, so the sequence does
/// not start on the heels of the last syllable. Silence rather than a
/// countdown: a countdown hands the patient a rhythm to lock onto before the
/// task begins.
const int _vigilanceLeadInMs = 1000;

const List<SubtestSpec> kVoiceSubtests = [
  SubtestSpec(
    id: 'digit-span-forward',
    section: 'สมาธิ',
    instructionTh: 'ฟังตัวเลขต่อไปนี้ แล้วพูดทวนตามลำดับ',
    instructionEn: 'Listen to the following numbers, then repeat them in the same order.',
    maxScore: 1,
    // Both built by tool/build_sequences.py from the per-digit recordings, one
    // digit per second. Regenerate after changing expectedSequence — the file
    // is what the patient hears and this string is what they are scored on.
    stimulusAsset: 'assets/moca/audio/digits-forward.wav',
    stimulusAssetEn: 'assets/moca/audio/eng-digits-forward.wav',
    expectedSequence: '21854',
    timeLimitSec: 7,
  ),
  SubtestSpec(
    id: 'digit-span-backward',
    section: 'สมาธิ',
    instructionTh: 'ฟังตัวเลขต่อไปนี้ แล้วพูดทวนย้อนกลับ',
    instructionEn: 'Listen to the following numbers, then repeat them in reverse order.',
    maxScore: 1,
    stimulusAsset: 'assets/moca/audio/digits-backward.wav',
    stimulusAssetEn: 'assets/moca/audio/eng-digits-backward.wav',
    // The patient hears 742 and must say it reversed. build_sequences.py holds
    // the heard order; it is this reversed, not a copy of it.
    expectedSequence: '247',
    timeLimitSec: 7,
  ),
  SubtestSpec(
    id: 'vigilance',
    section: 'สมาธิ',
    // Must stay word for word in step with what the screen shows — a patient
    // who reads one instruction and is set another has been given a second
    // task nobody intended, and on this subtest that looks like a deficit.
    instructionTh: 'คุณจะได้ยินตัวเลขหลายตัว ให้แตะที่ปุ่มบนหน้าจอ ทุกครั้งที่ได้ยินเลขหนึ่ง',
    instructionEn:
        'You will hear several numbers. Tap the button on the screen every time you hear the number one.',
    maxScore: 1,
    responseMode: ResponseMode.tap,
    sequence: kVigilanceSequence,
    target: '1',
    intervalMs: 1000,
    leadInMs: _vigilanceLeadInMs,
    // The sequence's own fixed duration, recorded rather than enforced: the
    // subtest ends when the audio ends.
    timeLimitSec: 30,
  ),
  // Sentences and recordings supplied by the user on 2026-08-17. The
  // expectedSentence text and the audio must stay in step: the scorer compares
  // what the patient said against this string, so editing one without
  // re-recording the other silently scores every patient against a sentence
  // they never heard.
  //
  // stimulusAsset is declared rather than left null. Null means "no stimulus
  // by design" (Abstraction, Orientation), where the microphone opens
  // immediately. The controller skips a subtest whose DECLARED stimulus fails
  // to load, which is the safety net if the asset ever fails to bundle.
  SubtestSpec(
    id: 'sentence-repetition-1',
    section: 'ภาษา',
    instructionTh: 'ฟังประโยคต่อไปนี้ แล้วพูดทวนให้เหมือนเดิมทุกคำ',
    instructionEn: 'Listen to the following sentence, then repeat it back exactly.',
    maxScore: 1,
    stimulusAsset: 'assets/moca/audio/sentence-1.wav',
    stimulusAssetEn: 'assets/moca/audio/eng-sentence-1.wav',
    expectedSentence: 'ฉันรู้ว่าจอมเป็นคนเดียวที่มาช่วยงานวันนี้',
    expectedSentenceEn: 'How can a clam cram in a clean cream can',
    timeLimitSec: 20,
  ),
  SubtestSpec(
    id: 'sentence-repetition-2',
    section: 'ภาษา',
    instructionTh: 'ฟังประโยคต่อไปนี้ แล้วพูดทวนให้เหมือนเดิมทุกคำ',
    instructionEn: 'Listen to the following sentence, then repeat it back exactly.',
    maxScore: 1,
    stimulusAsset: 'assets/moca/audio/sentence-2.wav',
    stimulusAssetEn: 'assets/moca/audio/eng-sentence-2.wav',
    expectedSentence: 'แมวมักจะซ่อนตัวอยู่หลังเก้าอี้เมื่อมีหมาอยู่ในห้อง',
    expectedSentenceEn: 'The thirty-three thieves thought that they thrilled the throne.',
    timeLimitSec: 20,
  ),
  SubtestSpec(
    id: 'verbal-fluency',
    section: 'ภาษา',
    instructionTh: 'บอกคำที่ขึ้นต้นด้วยตัว ก ให้ได้มากที่สุดภายในหนึ่งนาที',
    instructionEn:
        'Say as many words as you can that begin with the letter F within one minute.',
    maxScore: 1,
    // The only normed deadline in the app. 60 seconds is what the "11 or more
    // words" cutoff is measured against, so it is enforced.
    timeLimitSec: 60,
    enforceTimeLimit: true,
    initialLetter: 'ก',
    initialLetterEn: 'F',
  ),
  SubtestSpec(
    id: 'abstraction-1',
    section: 'ความคิดรวบยอด',
    // The worked example is part of the instruction, not a scored item. Without
    // it, people answer with a shared physical feature and score 0 for
    // misunderstanding the task rather than for failing it.
    instructionTh:
        'บอกว่าของสองสิ่งเหมือนกันอย่างไร ตัวอย่างเช่น กล้วยกับส้ม เป็นผลไม้ทั้งคู่ ทีนี้ รถไฟกับจักรยาน?',
    instructionEn:
        'Tell me how two things are alike. For example, a banana and an orange are both fruit. Now, how are a train and a bicycle alike?',
    maxScore: 1,
    timeLimitSec: 30,
  ),
  SubtestSpec(
    id: 'abstraction-2',
    section: 'ความคิดรวบยอด',
    // No example this time — it was given once, and repeating it would prompt
    // the patient toward the kind of answer being measured.
    instructionTh: 'แล้วนาฬิกากับไม้บรรทัดเหมือนกันอย่างไร?',
    instructionEn: 'Now, how are a watch and a ruler alike?',
    maxScore: 1,
    timeLimitSec: 30,
  ),
  SubtestSpec(
    id: 'orientation',
    section: 'การรับรู้เวลาและสถานที่',
    instructionTh: 'บอกวัน เดือน ปี วันที่ สถานที่ และจังหวัดในวันนี้',
    instructionEn: 'Tell me the day, month, year, date, place, and city today.',
    maxScore: 6,
    timeLimitSec: 15,
  ),
];
