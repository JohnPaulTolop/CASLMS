/// CAS registration choices. Stored program codes match academic_catalog.json.
class AcademicCatalog {
  static const String department = 'College of Arts and Sciences (CAS)';
  static const Map<String, String> programLabels = {
    'BSIT': 'Bachelor of Science in Information Technology (BSIT)',
    'BSIS': 'Bachelor of Science in Information Systems (BSIS)',
    'BSPsych': 'Bachelor of Science in Psychology (BSPsych)',
    'BSStat': 'Bachelor of Science in Statistics (BSStat)',
  };
  static const Map<String, List<String>> programs = {
    department: ['BSIT', 'BSIS', 'BSPsych', 'BSStat'],
  };
  static String programLabel(String code) => programLabels[code] ?? code;
  static bool contains(String department, String program) =>
      programs[department]?.contains(program) ?? false;
}
