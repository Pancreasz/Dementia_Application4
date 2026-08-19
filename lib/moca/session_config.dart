import 'app_language.dart';

/// Where the session is being administered. Orientation scores two of its six
/// points against these, so they are session context rather than test content.
///
/// TODO: replace with a settings screen the operator fills in before a session.
/// Until then these are the defaults, and an Orientation score is only
/// meaningful if they match where the patient actually is.
class SessionConfig {
  static String get place => t('โรงพยาบาลศิริราช', 'Hospital');
  static String get province => t('กรุงเทพ', 'Bangkok');
}
