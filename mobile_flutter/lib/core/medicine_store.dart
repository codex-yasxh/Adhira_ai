/// Simple in-memory store so ChatPage can read the current medicine names
/// without needing Supabase persistence.
class MedicineStore {
  MedicineStore._();
  static final MedicineStore instance = MedicineStore._();

  final List<String> names = <String>[];
}
