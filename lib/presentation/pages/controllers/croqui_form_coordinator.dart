import 'package:flutter/material.dart';

import 'package:croqui_forense_mvp/data/models/caso_model.dart';
import 'package:croqui_forense_mvp/data/models/dados_laudo_model.dart';
import 'package:croqui_forense_mvp/data/models/atn_model.dart';
import 'package:croqui_forense_mvp/data/models/causa_morte_model.dart';
import 'package:croqui_forense_mvp/core/utils/protocol_formatter.dart';
import 'package:croqui_forense_mvp/presentation/providers/auth_provider.dart';

/// Agrupa os [TextEditingController]s correspondentes a uma cadeia de causa mortis
/// forense (imediata, devida a e consequência de).
class CausaMorteControllers {
  final TextEditingController imediataCtrl;
  final TextEditingController devidoACtrl;
  final TextEditingController consequenciaCtrl;

  CausaMorteControllers({
    String imediata = '',
    String devidoA = '',
    String consequencia = '',
  }) : imediataCtrl = TextEditingController(text: imediata),
       devidoACtrl = TextEditingController(text: devidoA),
       consequenciaCtrl = TextEditingController(text: consequencia);

  void dispose() {
    imediataCtrl.dispose();
    devidoACtrl.dispose();
    consequenciaCtrl.dispose();
  }
}

/// Coordenador de ciclo de vida e estado textual dos formulários do laudo cadavérico.
///
/// **Atenção: roda na UI thread.**
///
/// Centraliza a alocação, escuta e liberação de recursos de todos os 22 controladores de texto
/// do exame físico e dos quesitos legais, além de consolidar os dados para o [DadosLaudoModel].
class CroquiFormCoordinator {
  // Identificação e Requisição Policial
  late final TextEditingController numeroLaudoCtrl;
  late final TextEditingController boCtrl;
  late final TextEditingController picCtrl;
  late final TextEditingController reqOrigemCtrl;
  late final TextEditingController delegaciaSolicitanteCtrl;
  late final TextEditingController reqDestinoCtrl;
  late final TextEditingController nomeVitimaCtrl;

  // Óbito e Estimativas Tanatológicas
  late final TextEditingController numeroDeclaracaoObitoCtrl;
  late final TextEditingController dataObitoCtrl;
  late final TextEditingController horaObitoCtrl;
  late final TextEditingController tipoEstimativaHoraObitoCtrl;
  late final TextEditingController sexoBiologicoEstimadoCtrl;
  late final TextEditingController corpoEstadoCtrl;
  late final TextEditingController corpoEstadoOutrosCtrl;

  // Descrição do Cadáver e Tanatologia
  late final TextEditingController historicoCtrl;
  late final TextEditingController vestesCtrl;
  late final TextEditingController caracteristicasCtrl;
  late final TextEditingController tanatoImediatoCtrl;
  late final TextEditingController tanatoConsecutivoCtrl;
  late final TextEditingController tanatoObservacaoCtrl;

  // Conclusão e Quesitos Oficiais
  late final TextEditingController discussaoCtrl;
  late final TextEditingController conclusaoCtrl;
  late final TextEditingController quesito1Ctrl;
  List<CausaMorteControllers> causasMorteCtrls = [];
  late final TextEditingController quesito3Ctrl;
  late final TextEditingController quesito4Ctrl;

  /// Inicializa todos os controladores de texto com os valores persistidos em [caso].
  CroquiFormCoordinator(Caso caso) {
    _initControllers(caso);
  }

  void _initControllers(Caso caso) {
    final dados = caso.dadosLaudo;

    numeroLaudoCtrl = TextEditingController(
      text: formatarRequisicao(
        caso.numeroRequisicao.isNotEmpty
            ? caso.numeroRequisicao
            : (caso.numeroLaudoExterno ?? ''),
      ),
    );
    boCtrl = TextEditingController(text: caso.numeroBo);
    picCtrl = TextEditingController(text: caso.numeroPic);
    reqOrigemCtrl = TextEditingController(text: caso.requisitante);
    delegaciaSolicitanteCtrl = TextEditingController(
      text: caso.delegaciaSolicitante ?? '',
    );
    reqDestinoCtrl = TextEditingController(text: caso.destino);
    nomeVitimaCtrl = TextEditingController(text: caso.nomeVitima);

    numeroDeclaracaoObitoCtrl = TextEditingController(
      text: caso.numeroDeclaracaoObito ?? '',
    );
    dataObitoCtrl = TextEditingController(text: caso.dataObito ?? '');
    horaObitoCtrl = TextEditingController(text: caso.horaObito ?? '');
    tipoEstimativaHoraObitoCtrl = TextEditingController(
      text: caso.tipoEstimativaHoraObito ?? '',
    );
    sexoBiologicoEstimadoCtrl = TextEditingController(
      text: caso.sexoBiologicoEstimado ?? '',
    );
    corpoEstadoCtrl = TextEditingController(text: caso.corpoEstado ?? '');
    corpoEstadoOutrosCtrl = TextEditingController(
      text: caso.corpoEstadoOutros ?? '',
    );

    historicoCtrl = TextEditingController(
      text: dados.identificacao.historico.isNotEmpty
          ? dados.identificacao.historico
          : "Consta em Boletim de Ocorrência de número ${caso.numeroBo} que às XX horas do dia XX de XXX do corrente ano. O fato descrito teria ocorrido na localidade conhecida como XXX.",
    );

    vestesCtrl = TextEditingController(
      text: dados.identificacao.vestes.isNotEmpty
          ? dados.identificacao.vestes
          : 'Despido no momento da necrópsia.',
    );
    caracteristicasCtrl = TextEditingController(
      text: dados.caracteristicas.identificacao.isNotEmpty
          ? dados.caracteristicas.identificacao
          : 'Cadáver do sexo XXX, raça XXX, estado nutricional XXX, e idade aparente de XX anos.',
    );
    tanatoImediatoCtrl = TextEditingController(
      text: dados.caracteristicas.tanatoImediato.isNotEmpty
          ? dados.caracteristicas.tanatoImediato
          : 'XXX',
    );
    tanatoConsecutivoCtrl = TextEditingController(
      text: dados.caracteristicas.tanatoConsecutivo.isNotEmpty
          ? dados.caracteristicas.tanatoConsecutivo
          : 'XXX',
    );
    tanatoObservacaoCtrl = TextEditingController(
      text: dados.caracteristicas.tanatoObservacao.isNotEmpty
          ? dados.caracteristicas.tanatoObservacao
          : 'XXX',
    );

    discussaoCtrl = TextEditingController(text: dados.conclusao.discussao);
    conclusaoCtrl = TextEditingController(text: dados.conclusao.conclusaoTexto);
    quesito1Ctrl = TextEditingController(text: dados.conclusao.quesito1Morte);

    if (caso.causaMorte != null && caso.causaMorte!.isNotEmpty) {
      causasMorteCtrls = caso.causaMorte!.map((cm) {
        return CausaMorteControllers(
          imediata: cm.imediata,
          devidoA: cm.devidoA,
          consequencia: cm.consequencia,
        );
      }).toList();
    } else {
      final String causaAntiga = dados.conclusao.quesito2Causa;
      causasMorteCtrls = [CausaMorteControllers(imediata: causaAntiga)];
    }

    quesito3Ctrl = TextEditingController(
      text: dados.conclusao.quesito3Instrumento,
    );
    quesito4Ctrl = TextEditingController(text: dados.conclusao.quesito4Meio);
  }

  /// Adiciona uma nova linha de causa mortis ao formulário.
  void adicionarCausaMorte() {
    causasMorteCtrls.add(CausaMorteControllers());
  }

  /// Remove uma linha de causa mortis pelo seu índice de posição.
  void removerCausaMorte(int index) {
    if (causasMorteCtrls.length > 1 && index < causasMorteCtrls.length) {
      final ctrl = causasMorteCtrls.removeAt(index);
      ctrl.dispose();
    }
  }

  /// Atualiza o campo descritivo do estado de conservação do cadáver.
  void setCorpoEstado(String value) {
    corpoEstadoCtrl.text = value;
  }

  /// Valida se os quesitos forenses obrigatórios e cadeias de causa da morte foram devidamente preenchidos.
  bool validarCamposObrigatorios() {
    if (quesito1Ctrl.text.trim().length < 3) return false;

    for (var ctrl in causasMorteCtrls) {
      if (ctrl.imediataCtrl.text.trim().length < 3) return false;
      if (ctrl.devidoACtrl.text.trim().length < 3) return false;
      if (ctrl.consequenciaCtrl.text.trim().length < 3) return false;
    }

    if (quesito3Ctrl.text.trim().length < 3) return false;
    if (quesito4Ctrl.text.trim().length < 3) return false;

    return true;
  }

  /// Consolida os campos de texto do formulário e retorna uma nova instância de [Caso] atualizada.
  Caso extrairCasoAtualizado({
    required Caso casoBase,
    required List<AtnModel> atns,
    AuthProvider? authProvider,
  }) {
    final String nomePerito;
    final String dataFinalizacao;
    if (authProvider != null) {
      nomePerito =
          authProvider.usuario?.nomeCompleto ?? "Perito não identificado";
      dataFinalizacao = DateTime.now().toUtc().toIso8601String();
    } else {
      nomePerito =
          casoBase.dadosLaudo.auditoria.peritoResponsavel ??
          "Perito não identificado";
      dataFinalizacao =
          casoBase.dadosLaudo.auditoria.dataFinalizacao ??
          DateTime.now().toUtc().toIso8601String();
    }

    final nomesAtns = casoBase.atnsIds
        .map((id) {
          final match = atns.where((a) => a.id == id).firstOrNull;
          return match?.nome ?? id;
        })
        .join(", ");

    final Map<String, dynamic> novosDados = {
      'auditoria': {
        'perito_responsavel': nomePerito,
        'data_finalizacao': dataFinalizacao,
        'atns_nomes': nomesAtns,
      },
      'identificacao': {
        'vestes': vestesCtrl.text,
        'historico': historicoCtrl.text,
        'sexo': casoBase.dadosLaudo.identificacao.sexo,
      },
      'caracteristicas': {
        'identificacao': caracteristicasCtrl.text,
        'tanato_imediato': tanatoImediatoCtrl.text,
        'tanato_observacao': tanatoObservacaoCtrl.text,
        'tanato_consecutivo': tanatoConsecutivoCtrl.text,
      },
      'conclusao': {
        'discussao': discussaoCtrl.text,
        'quesito_1_morte': quesito1Ctrl.text,
        'quesito_3_instrumento': quesito3Ctrl.text,
        'quesito_4_meio': quesito4Ctrl.text,
        'conclusao_texto': conclusaoCtrl.text,
      },
    };

    final String corpoEstOu = corpoEstadoOutrosCtrl.text.trim();
    final now = DateTime.now();
    final dataNecropsiaFinal =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    final horaNecropsiaFinal =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

    final causasMorteList = causasMorteCtrls
        .map(
          (ctrl) => CausaMorteModel(
            imediata: ctrl.imediataCtrl.text,
            devidoA: ctrl.devidoACtrl.text,
            consequencia: ctrl.consequenciaCtrl.text,
          ),
        )
        .toList();

    final reqNum = sanitizarRequisicao(numeroLaudoCtrl.text);

    return casoBase.copyWith(
      numeroBo: boCtrl.text,
      numeroPic: picCtrl.text,
      numeroRequisicao: reqNum,
      numeroLaudoExterno: reqNum.isNotEmpty ? reqNum : casoBase.numeroLaudoExterno,
      nomeVitima: nomeVitimaCtrl.text,
      destino: reqDestinoCtrl.text,
      requisitante: reqOrigemCtrl.text,
      delegaciaSolicitante: delegaciaSolicitanteCtrl.text,
      dadosLaudo: DadosLaudoModel.fromMap(novosDados),
      numeroDeclaracaoObito: numeroDeclaracaoObitoCtrl.text,
      dataObito: dataObitoCtrl.text,
      horaObito: horaObitoCtrl.text,
      tipoEstimativaHoraObito: tipoEstimativaHoraObitoCtrl.text,
      sexoBiologicoEstimado: sexoBiologicoEstimadoCtrl.text,
      corpoEstado: corpoEstadoCtrl.text,
      corpoEstadoOutros: corpoEstOu,
      dataNecropsia: dataNecropsiaFinal,
      horaNecropsia: horaNecropsiaFinal,
      causaMorte: causasMorteList,
      isDraftSynced: false,
      atualizadoEm: DateTime.now().toUtc(),
      versao: casoBase.versao + 1,
    );
  }

  /// Descarta todos os controladores de texto ativos.
  void dispose() {
    numeroLaudoCtrl.dispose();
    boCtrl.dispose();
    picCtrl.dispose();
    reqOrigemCtrl.dispose();
    delegaciaSolicitanteCtrl.dispose();
    reqDestinoCtrl.dispose();
    nomeVitimaCtrl.dispose();
    numeroDeclaracaoObitoCtrl.dispose();
    dataObitoCtrl.dispose();
    horaObitoCtrl.dispose();
    tipoEstimativaHoraObitoCtrl.dispose();
    sexoBiologicoEstimadoCtrl.dispose();
    corpoEstadoCtrl.dispose();
    corpoEstadoOutrosCtrl.dispose();
    historicoCtrl.dispose();
    vestesCtrl.dispose();
    caracteristicasCtrl.dispose();
    tanatoImediatoCtrl.dispose();
    tanatoConsecutivoCtrl.dispose();
    tanatoObservacaoCtrl.dispose();
    discussaoCtrl.dispose();
    conclusaoCtrl.dispose();
    quesito1Ctrl.dispose();
    quesito3Ctrl.dispose();
    quesito4Ctrl.dispose();

    for (var ctrl in causasMorteCtrls) {
      ctrl.dispose();
    }
  }
}
