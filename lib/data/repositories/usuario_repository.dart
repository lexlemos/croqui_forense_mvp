
import 'package:croqui_forense_mvp/data/local/database_helper.dart'; 
import 'package:croqui_forense_mvp/data/models/usuario_model.dart'; 

import 'package:croqui_forense_mvp/core/constants/database_constants.dart'; 

class UsuarioRepository {

  final DatabaseHelper _dbHelper; 

  UsuarioRepository(this._dbHelper);

  Future<Usuario?> getUsuarioByMatricula(String matricula) async {
    final db = await _dbHelper.database; 

    final List<Map<String, dynamic>> maps = await db.query(
      tableUsuarios,
      where: 'matricula_funcional = ? AND ativo = 1', 
      whereArgs: [matricula],
      limit: 1, 
    );

    if (maps.isNotEmpty) {
      return Usuario.fromMap(maps.first);
    }
    
    return null;
  }
}