import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:croqui_forense_mvp/core/enums/status_confirmacao_atn.dart';
import 'package:croqui_forense_mvp/core/utils/uuid_helper.dart';
import 'package:croqui_forense_mvp/data/models/achado_model.dart';
import 'package:croqui_forense_mvp/data/models/balistica_model.dart';
import 'package:croqui_forense_mvp/presentation/pages/controllers/croqui_controller.dart';
import 'package:croqui_forense_mvp/presentation/widgets/common/status_atn_badge.dart';

/// Aba de visualização consolidada dos vestígios balísticos (Projéteis de Arma de Fogo - PAF e estojos)
/// vinculados às lesões e orifícios cadastrados no croqui corporal.
///
/// **Atenção: roda na UI thread.**
///
/// ### Lógicas Condicionais e Rastreabilidade:
/// - **Filtragem Dinâmica**: Varre a lista de [Achado]s e filtra somente as marcações com dados balísticos
///   preenchidos ([Achado.tipoFerimento], [Achado.tipoObjeto], [Achado.numeroLacre] ou [Achado.comentarioAdicional]).
/// - **Resolução de Vínculo**: Localiza o [BalisticaModel] correspondente na coleção do caso matriz através
///   do [Achado.uuid] ou derivado determinístico [deterministicUuidV5].
/// - **Badge de Conferência ATN ([StatusAtnBadge])**: Sinaliza visualmente se o vestígio já foi aceito,
///   visualizado, recusado ou está pendente pelo Auxiliar Técnico de Necrópsia.
/// - **Auditoria de Recusa ([JustificativaRecusaBox])**: Renderizado condicionalmente caso
///   `statusConfirmacaoAtn == StatusConfirmacaoATN.RECUSADO`, exibindo a razão formal apontada pelo ATN.
/// - **Navegação Reativa ([onEdit])**: Ao tocar em um card de vestígio, invoca o callback para reabrir
///   o formulário de edição do ferimento no croqui.
class BalisticaTab extends StatelessWidget {
  final bool readOnly;
  final void Function(Achado)? onEdit;

  const BalisticaTab({super.key, this.readOnly = false, this.onEdit});


  @override
  Widget build(BuildContext context) {
    return Consumer<CroquiController>(
      builder: (context, controller, child) {
        final balisticaAchados = controller.achados
            .where(
              (a) =>
                  (a.tipoFerimento != null && a.tipoFerimento!.isNotEmpty) ||
                  (a.tipoObjeto != null && a.tipoObjeto!.isNotEmpty) ||
                  (a.numeroLacre != null && a.numeroLacre!.isNotEmpty) ||
                  (a.comentarioAdicional != null &&
                      a.comentarioAdicional!.isNotEmpty),
            )
            .toList();

        return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _SectionHeader(
                title: "Balística de Achados",
                icon: Icons.gps_fixed,
              ),
              const SizedBox(height: 8),
              const Text(
                "Vestígios recolhidos associados diretamente a um ferimento. Clique em um achado abaixo para visualizar ou editar os detalhes.",
                style: TextStyle(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              if (balisticaAchados.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text("Nenhuma balística vinculada a achados."),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: balisticaAchados.length,
                  itemBuilder: (context, index) {
                    final a = balisticaAchados[index];
                    final String typeLabel =
                        a.dadosPreenchidos['type_label']?.toString() ??
                        a.tipoAchadoId;

                    final balisticaItem = controller.casoAtual.balisticas.firstWhere(
                      (b) =>
                          (b.achadoUuid != null && b.achadoUuid == a.uuid) ||
                          b.id == deterministicUuidV5(a.uuid, 'balistica'),
                      orElse: () => BalisticaModel(
                        exameId: controller.casoAtual.uuid,
                        achadoUuid: a.uuid,
                        tipoFerimento: a.tipoFerimento,
                        tipoObjeto: a.tipoObjeto,
                        numeroLacre: a.numeroLacre,
                        comentarioAdicional: a.comentarioAdicional,
                      ),
                    );

                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          if (onEdit != null) onEdit!(a);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 10,
                                    backgroundColor: Colors.red,
                                    child: Text(
                                      a.numeroSequencial.toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      "${typeLabel.toUpperCase()} - ${a.localAnatomico}",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  StatusAtnBadge(
                                    status: balisticaItem.statusConfirmacaoAtn,
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.chevron_right,
                                    color: Colors.grey,
                                  ),
                                ],
                              ),
                              const Divider(),
                              if (a.tipoFerimento != null &&
                                  a.tipoFerimento!.isNotEmpty)
                                Text("Tipo de Ferimento: ${a.tipoFerimento}"),
                              if (a.tipoObjeto != null &&
                                  a.tipoObjeto!.isNotEmpty)
                                Text("Tipo de Objeto: ${a.tipoObjeto}"),
                              if (a.numeroLacre != null &&
                                  a.numeroLacre!.isNotEmpty)
                                Text("Nº do Lacre: ${a.numeroLacre}"),
                              if (a.comentarioAdicional != null &&
                                  a.comentarioAdicional!.isNotEmpty)
                                Text("Comentário: ${a.comentarioAdicional}"),
                              if (balisticaItem.statusConfirmacaoAtn ==
                                      StatusConfirmacaoATN.RECUSADO &&
                                  balisticaItem.justificativaRecusa != null &&
                                  balisticaItem.justificativaRecusa!
                                      .trim()
                                      .isNotEmpty) ...[
                                const SizedBox(height: 8),
                                JustificativaRecusaBox(
                                  justificativa:
                                      balisticaItem.justificativaRecusa!,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({required this.title, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.indigo.shade100),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.indigo),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
        ],
      ),
    );
  }
}
