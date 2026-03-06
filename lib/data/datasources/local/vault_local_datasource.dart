import '../../../core/errors/exceptions.dart';
import 'database_helper.dart';

/// Local data source for vault operations backed by sqflite.
class VaultLocalDatasource {
  final DatabaseHelper _dbHelper;

  VaultLocalDatasource({required DatabaseHelper dbHelper})
      : _dbHelper = dbHelper;

  /// Inserts a vault item record.
  Future<void> insertVaultItem(Map<String, dynamic> data) async {
    try {
      final db = await _dbHelper.database;
      await db.insert('vault_items', data);
    } catch (e) {
      throw DatabaseException(message: 'Failed to insert vault item: $e');
    }
  }

  /// Gets all vault items.
  Future<List<Map<String, dynamic>>> getAllVaultItems() async {
    try {
      final db = await _dbHelper.database;
      return db.query('vault_items', orderBy: 'encrypted_at DESC');
    } catch (e) {
      throw DatabaseException(message: 'Failed to get vault items: $e');
    }
  }

  /// Deletes a vault item by ID.
  Future<void> deleteVaultItem(String id) async {
    try {
      final db = await _dbHelper.database;
      await db.delete('vault_items', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      throw DatabaseException(message: 'Failed to delete vault item: $e');
    }
  }

  /// Gets a vault item by ID.
  Future<Map<String, dynamic>?> getVaultItemById(String id) async {
    try {
      final db = await _dbHelper.database;
      final results = await db.query(
        'vault_items',
        where: 'id = ?',
        whereArgs: [id],
      );
      return results.isEmpty ? null : results.first;
    } catch (e) {
      throw DatabaseException(message: 'Failed to get vault item: $e');
    }
  }
}
