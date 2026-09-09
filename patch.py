import sys
import os

path = r'c:\dev\croqui_forense_mvp\lib\presentation\pages\controllers\croqui_controller.dart'
with open(path, 'r', encoding='utf-8') as f:
    content = f.read()

replacements = [
    (
"""  Future<void> salvarExamesModel(List<ExameSolicitadoModel> exames) async {
    examesSolicitadosModel = exames;
    await _casoRepository.salvarExames(casoAtual.uuid, exames);
    notifyListeners();
    _scheduleAutoSave();
  }""",
"""  Future<void> _bumpRootVersion() async {
    casoAtual = casoAtual.copyWith(
      versao: casoAtual.versao + 1,
      atualizadoEm: DateTime.now().toUtc(),
    );
    await _caseService.salvarRascunho(casoAtual);
    notifyListeners();
  }

  Future<void> salvarExamesModel(List<ExameSolicitadoModel> exames) async {
    examesSolicitadosModel = exames;
    await _casoRepository.salvarExames(casoAtual.uuid, exames);
    await _bumpRootVersion();
    notifyListeners();
    _scheduleAutoSave();
  }"""
    ),
    (
"""  Future<void> salvarExamesSolicitados({
    required String? anatomoLacre,
    required String? toxicologicoLacre,
    required String? geneticaLacre,
    required String? outrosLacre,
  }) async {
    await _caseService.salvarExamesSolicitados(
      casoUuid: casoAtual.uuid,
      anatomoLacre: anatomoLacre,
      toxicologicoLacre: toxicologicoLacre,
      geneticaLacre: geneticaLacre,
      outrosLacre: outrosLacre,
    );
    examesSolicitados = await _caseService.getExamesSolicitados(casoAtual.uuid);
    notifyListeners();
  }""",
"""  Future<void> salvarExamesSolicitados({
    required String? anatomoLacre,
    required String? toxicologicoLacre,
    required String? geneticaLacre,
    required String? outrosLacre,
  }) async {
    await _caseService.salvarExamesSolicitados(
      casoUuid: casoAtual.uuid,
      anatomoLacre: anatomoLacre,
      toxicologicoLacre: toxicologicoLacre,
      geneticaLacre: geneticaLacre,
      outrosLacre: outrosLacre,
    );
    examesSolicitados = await _caseService.getExamesSolicitados(casoAtual.uuid);
    await _bumpRootVersion();
    notifyListeners();
  }"""
    ),
    (
"""      try {
        await _achadoService.salvarAchado(achadoFinal);
        await _loadAchados();
        
        globalMessengerKey.currentState?.hideCurrentSnackBar();
        globalMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text("Achado adicionado!")));""",
"""      try {
        await _achadoService.salvarAchado(achadoFinal);
        await _bumpRootVersion();
        await _loadAchados();
        
        globalMessengerKey.currentState?.hideCurrentSnackBar();
        globalMessengerKey.currentState?.showSnackBar(const SnackBar(content: Text("Achado adicionado!")));"""
    ),
    (
"""      try {
        await _achadoService.atualizarAchado(achadoAtualizado);
        await _loadAchados();
        _snack("Achado atualizado!");""",
"""      try {
        await _achadoService.atualizarAchado(achadoAtualizado);
        await _bumpRootVersion();
        await _loadAchados();
        _snack("Achado atualizado!");"""
    ),
    (
"""    try {
      await _achadoService.removerAchado(uuid);
      await _loadAchados();
      _snack("Achado removido.");""",
"""    try {
      await _achadoService.removerAchado(uuid);
      await _bumpRootVersion();
      await _loadAchados();
      _snack("Achado removido.");"""
    ),
    (
"""  Future<void> adicionarFotoGeral(String path) async {
    final ev = EvidenciaMultimidia.novo(
      casoUuid: casoAtual.uuid,
      tipo: 'GERAL',
      caminhoArquivoEncriptado: path,
    );
    await _caseService.salvarEvidenciaGeral(ev);
    await _loadAchados();
  }""",
"""  Future<void> adicionarFotoGeral(String path) async {
    final ev = EvidenciaMultimidia.novo(
      casoUuid: casoAtual.uuid,
      tipo: 'GERAL',
      caminhoArquivoEncriptado: path,
    );
    await _caseService.salvarEvidenciaGeral(ev);
    await _bumpRootVersion();
    await _loadAchados();
  }"""
    ),
    (
"""  Future<void> removerFotoGeral(String uuid) async {
    await _caseService.removerEvidenciaGeral(uuid);
    await _loadAchados();
  }""",
"""  Future<void> removerFotoGeral(String uuid) async {
    await _caseService.removerEvidenciaGeral(uuid);
    await _bumpRootVersion();
    await _loadAchados();
  }"""
    ),
    (
"""  Future<void> salvarDescricaoFotoGeral(String uuid, String descricao) async {
    final index = evidenciasGerais.indexWhere((e) => e.uuid == uuid);
    if (index != -1) {
      final evAtualizada = evidenciasGerais[index].copyWith(descricao: descricao);
      await _caseService.salvarEvidenciaGeral(evAtualizada);
      await _loadAchados();
    }
  }""",
"""  Future<void> salvarDescricaoFotoGeral(String uuid, String descricao) async {
    final index = evidenciasGerais.indexWhere((e) => e.uuid == uuid);
    if (index != -1) {
      final evAtualizada = evidenciasGerais[index].copyWith(descricao: descricao);
      await _caseService.salvarEvidenciaGeral(evAtualizada);
      await _bumpRootVersion();
      await _loadAchados();
    }
  }"""
    )
]

for old, new in replacements:
    if old not in content:
        print(f"FAILED TO FIND:\n{old}\n---")
    content = content.replace(old, new)

with open(path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Patch applied.")
