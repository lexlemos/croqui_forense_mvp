import 'package:flutter/material.dart';
import 'package:croqui_forense_mvp/data/models/usuario_model.dart';

class UserListItem extends StatelessWidget {
  final Usuario usuario;
  final bool isCurrentUser;
  final Function(bool) onStatusChanged;

  const UserListItem({
    super.key,
    required this.usuario,
    required this.isCurrentUser,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {

    final color = usuario.ativo ? Colors.green : Colors.grey;
    final papelNome = usuario.papelId == 1 ? 'Administrador' : 'Perito / Legista';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: isCurrentUser ? const Color(0xFF317FF5) : color.withOpacity(0.1),
          child: Text(
            usuario.nomeCompleto.isNotEmpty ? usuario.nomeCompleto[0].toUpperCase() : '?',
            style: TextStyle(
              color: isCurrentUser ? Colors.white : color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          usuario.nomeCompleto,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: usuario.ativo ? Colors.black87 : Colors.grey,
            decoration: usuario.ativo ? null : TextDecoration.lineThrough,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('Matrícula: ${usuario.matriculaFuncional}'),
            Container(
              margin: const EdgeInsets.only(top: 4),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Text(
                papelNome.toUpperCase(),
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        trailing: isCurrentUser
            ? const Tooltip(
                message: "Você não pode desativar a si mesmo",
                child: Icon(Icons.lock, color: Colors.grey),
              )
            : Switch(
                value: usuario.ativo,
                activeColor: Colors.green,
                onChanged: (novoValor) => _confirmarAlteracao(context, novoValor),
              ),
      ),
    );
  }

  void _confirmarAlteracao(BuildContext context, bool novoValor) {
    final acao = novoValor ? "ATIVAR" : "DESATIVAR";
    final cor = novoValor ? Colors.green : Colors.red;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$acao Usuário?', style: TextStyle(color: cor)),
        content: Text(
          'Tem certeza que deseja $acao o acesso de "${usuario.nomeCompleto}"?\n\n'
          '${!novoValor ? "O usuário perderá acesso imediato ao sistema." : "O usuário poderá fazer login novamente."}'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: cor),
            onPressed: () {
              Navigator.pop(ctx);
              onStatusChanged(novoValor);
            },
            child: Text('Confirmar $acao'),
          ),
        ],
      ),
    );
  }
}