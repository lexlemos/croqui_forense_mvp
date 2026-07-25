const String kDatabaseName = 'croqui_forense_mvp.db';
const int kDatabaseVersion = 12;

const String tableUsuarios = 'usuarios'; 
const String tablePapeis = 'papeis';
const String tablePermissoes = 'permissoes';
const String tablePapelPermissoes = 'papel_permissoes';
const String tableTiposAchados = 'tipos_achados';
const String tableCasos = 'casos';
const String tableAchados = 'achados';
const String tableEvidenciasMultimidia = 'evidencias_multimidia';
const String tableLogAuditoria = 'log_auditoria';
const String tableAtns = 'atns';

const String kCreateAtnsSql = '''
CREATE TABLE IF NOT EXISTS atns (
    id TEXT PRIMARY KEY,
    nome TEXT NOT NULL,
    ativo INTEGER DEFAULT 1
);
''';

const String _kCreatePapeis = '''
CREATE TABLE papeis (
    id TEXT PRIMARY KEY,
    nome TEXT NOT NULL UNIQUE,
    descricao TEXT,
    e_padrao INTEGER DEFAULT 0,
    criado_em TEXT DEFAULT (STRFTIME('%Y-%m-%d %H:%M:%f', 'NOW'))
);
''';

const String _kCreatePermissoes = '''
CREATE TABLE permissoes (
    id TEXT PRIMARY KEY,
    codigo TEXT NOT NULL UNIQUE,
    descricao TEXT
);
''';

const String _kCreateUsuarios = '''
CREATE TABLE usuarios (
    id TEXT PRIMARY KEY,
    matricula_funcional TEXT NOT NULL UNIQUE,
    papel_id TEXT NOT NULL,
    nome_completo TEXT NOT NULL,
    crm TEXT,
    classe TEXT,
    ativo INTEGER DEFAULT 1,
    hash_pin_offline TEXT,
    deve_alterar_pin INTEGER DEFAULT 1,
    criado_em TEXT DEFAULT (STRFTIME('%Y-%m-%d %H:%M:%f', 'NOW')),
    atualizado_em TEXT,
    versao INTEGER DEFAULT 1,
    device_id TEXT,
    salt TEXT,
    FOREIGN KEY (papel_id) REFERENCES papeis(id) ON DELETE RESTRICT
);
''';

const String _kCreatePapelPermissoes = '''
CREATE TABLE papel_permissoes (
    papel_id TEXT NOT NULL,
    permissao_id TEXT NOT NULL,
    PRIMARY KEY (papel_id, permissao_id),
    FOREIGN KEY (papel_id) REFERENCES papeis(id) ON DELETE CASCADE,
    FOREIGN KEY (permissao_id) REFERENCES permissoes(id) ON DELETE CASCADE
);
''';

const String _kCreateTiposAchados = '''
CREATE TABLE tipos_achados (
    id TEXT PRIMARY KEY,
    nome TEXT NOT NULL,
    is_interno INTEGER DEFAULT 0,
    schema_formulario_json TEXT,
    ordem INTEGER DEFAULT 0,
    ativo INTEGER DEFAULT 1,
    versao INTEGER DEFAULT 1,
    criado_em TEXT,
    atualizado_em TEXT
);
''';


const String _kCreateCasos = '''
CREATE TABLE casos (
    uuid TEXT PRIMARY KEY,
    id_usuario_criador TEXT NOT NULL,
    numero_laudo_externo TEXT,
    status TEXT DEFAULT 'RASCUNHO',
    hash_integridade TEXT,
    removido INTEGER DEFAULT 0,
    dados_laudo_json TEXT,
    versao INTEGER DEFAULT 1,
    criado_em_dispositivo TEXT DEFAULT (STRFTIME('%Y-%m-%d %H:%M:%f', 'NOW')),
    atualizado_em TEXT,
    finalizado_em TEXT,
    device_id TEXT,
    numero_pic TEXT,
    numero_bo TEXT,
    numero_requisicao TEXT,
    nome_vitima TEXT,
    destino TEXT,
    requisitante TEXT,
    atn_responsavel TEXT,
    pdf_local_path TEXT,
    is_draft_synced INTEGER DEFAULT 0,
    FOREIGN KEY (id_usuario_criador) REFERENCES usuarios(id) ON DELETE RESTRICT
);
''';

const String _kCreateAchados = '''
CREATE TABLE achados (
    uuid TEXT PRIMARY KEY,
    caso_uuid TEXT NOT NULL,
    diagrama_caso_uuid TEXT NOT NULL DEFAULT '',
    tipo_achado_id TEXT NOT NULL,
    achado_relacionado_uuid TEXT,
    diagrama_nome TEXT,
    numero_sequencial INTEGER,
    pos_x REAL,
    pos_y REAL,
    is_interno INTEGER DEFAULT 0,
    dados_preenchidos_json TEXT,
    observacoes_texto TEXT,
    removido INTEGER DEFAULT 0,
    versao INTEGER DEFAULT 1,
    criado_em TEXT,
    atualizado_em TEXT,
    device_id TEXT,
    tamanho TEXT,
    vista_anatomica TEXT,
    local_anatomico TEXT,
    FOREIGN KEY (caso_uuid) REFERENCES casos(uuid) ON DELETE CASCADE,
    FOREIGN KEY (achado_relacionado_uuid) REFERENCES achados(uuid) ON DELETE SET NULL,
    FOREIGN KEY (tipo_achado_id) REFERENCES tipos_achados(id) ON DELETE RESTRICT
);
''';

const String _kCreateEvidencias = '''
CREATE TABLE evidencias_multimidia (
    uuid TEXT PRIMARY KEY,
    caso_uuid TEXT NOT NULL,
    achado_uuid TEXT,
    substituida_por TEXT,
    tipo TEXT DEFAULT 'ACHADO',
    caminho_arquivo_encriptado TEXT,
    hash_arquivo TEXT,
    foto_sincronizada INTEGER NOT NULL DEFAULT 0,
    removido INTEGER DEFAULT 0,
    versao INTEGER DEFAULT 1,
    criado_em TEXT,
    atualizado_em TEXT,
    descricao TEXT,
    FOREIGN KEY (caso_uuid) REFERENCES casos(uuid) ON DELETE CASCADE,
    FOREIGN KEY (achado_uuid) REFERENCES achados(uuid) ON DELETE CASCADE,
    FOREIGN KEY (substituida_por) REFERENCES evidencias_multimidia(uuid) ON DELETE SET NULL
);
''';

const String tableDetalhesToxicologico = 'detalhes_toxicologico';
const String tableAmostrasGenetica = 'amostras_genetica';
const String tableFrascosAnatomo = 'frascos_anatomo';

const String kCreateExamesSolicitadosSql = '''
CREATE TABLE IF NOT EXISTS exames_solicitados (
    uuid TEXT PRIMARY KEY,
    caso_uuid TEXT NOT NULL,
    tipo_exame TEXT NOT NULL,
    numero_lacre TEXT,
    criado_em TEXT NOT NULL,
    FOREIGN KEY (caso_uuid) REFERENCES casos(uuid) ON DELETE CASCADE
);
''';

const String kCreateDetalhesToxicologicoSql = '''
CREATE TABLE IF NOT EXISTS detalhes_toxicologico (
    uuid TEXT PRIMARY KEY,
    exame_uuid TEXT NOT NULL,
    historico_ocorrencia TEXT,
    historico_outro TEXT,
    material_sg_femoral INTEGER DEFAULT 0,
    material_sg_cardiaca INTEGER DEFAULT 0,
    material_sg_outro TEXT,
    numero_lacre_sg TEXT,
    material_urina INTEGER DEFAULT 0,
    numero_lacre_ur TEXT,
    material_humor_vitreo INTEGER DEFAULT 0,
    numero_lacre_hv TEXT,
    material_estomago INTEGER DEFAULT 0,
    numero_lacre_ce TEXT,
    material_pulmao INTEGER DEFAULT 0,
    numero_lacre_pm TEXT,
    quantificacao_drogas INTEGER DEFAULT 0,
    FOREIGN KEY (exame_uuid) REFERENCES exames_solicitados(uuid) ON DELETE CASCADE
);
''';

const String kCreateAmostrasGeneticaSql = '''
CREATE TABLE IF NOT EXISTS amostras_genetica (
    uuid TEXT PRIMARY KEY,
    exame_uuid TEXT NOT NULL,
    tipo_amostra TEXT NOT NULL,
    descricao_outro TEXT,
    pesquisa_semen INTEGER DEFAULT 0,
    pesquisa_dna INTEGER DEFAULT 0,
    quantidade_swabs INTEGER DEFAULT 1,
    numero_lacre TEXT,
    FOREIGN KEY (exame_uuid) REFERENCES exames_solicitados(uuid) ON DELETE CASCADE
);
''';

const String kCreateFrascosAnatomoSql = '''
CREATE TABLE IF NOT EXISTS frascos_anatomo (
    uuid TEXT PRIMARY KEY,
    exame_uuid TEXT NOT NULL,
    numero_frasco INTEGER NOT NULL,
    numero_lacre TEXT,
    coracao INTEGER DEFAULT 0,
    figado INTEGER DEFAULT 0,
    baco INTEGER DEFAULT 0,
    encefalo INTEGER DEFAULT 0,
    pulmao_d_lsd INTEGER DEFAULT 0,
    pulmao_d_lmd INTEGER DEFAULT 0,
    pulmao_d_lid INTEGER DEFAULT 0,
    pulmao_e_lse INTEGER DEFAULT 0,
    pulmao_e_lie INTEGER DEFAULT 0,
    rim_d INTEGER DEFAULT 0,
    rim_e INTEGER DEFAULT 0,
    pele_regiao TEXT,
    partes_moles_regiao TEXT,
    outras_regiao TEXT,
    FOREIGN KEY (exame_uuid) REFERENCES exames_solicitados(uuid) ON DELETE CASCADE
);
''';

const String _kCreateLogAuditoria = '''
CREATE TABLE log_auditoria (
    id TEXT PRIMARY KEY,
    caso_uuid TEXT,
    id_usuario TEXT,
    codigo_acao TEXT,
    transacao_uuid TEXT,
    detalhes_json TEXT, 
    timestamp TEXT DEFAULT (STRFTIME('%Y-%m-%d %H:%M:%f', 'NOW')),
    device_id TEXT,
    proveniencia TEXT,
    FOREIGN KEY (caso_uuid) REFERENCES casos(uuid) ON DELETE SET NULL,
    FOREIGN KEY (id_usuario) REFERENCES usuarios(id) ON DELETE SET NULL
);
''';

const List<String> kIndexCreationScripts = [
  'CREATE INDEX idx_usuarios_papel ON usuarios (papel_id);',
  'CREATE INDEX idx_casos_criador ON casos (id_usuario_criador);',
  'CREATE INDEX idx_achados_caso ON achados (caso_uuid);',
  'CREATE INDEX idx_achados_tipo ON achados (tipo_achado_id);',
  'CREATE INDEX idx_achados_relacionado ON achados (achado_relacionado_uuid);',
  'CREATE INDEX idx_evidencias_achado ON evidencias_multimidia (achado_uuid);',
  'CREATE INDEX idx_evidencias_caso ON evidencias_multimidia (caso_uuid);',
  'CREATE INDEX idx_evidencias_substituta ON evidencias_multimidia (substituida_por);',
  'CREATE INDEX idx_log_caso ON log_auditoria (caso_uuid);',
  'CREATE INDEX idx_log_usuario ON log_auditoria (id_usuario);',
  'CREATE INDEX idx_casos_status ON casos (status);',
  'CREATE INDEX idx_exames_caso ON exames_solicitados (caso_uuid);',
  'CREATE INDEX idx_detalhes_toxicologico_exame ON detalhes_toxicologico (exame_uuid);',
  'CREATE INDEX idx_amostras_genetica_exame ON amostras_genetica (exame_uuid);',
  'CREATE INDEX idx_frascos_anatomo_exame ON frascos_anatomo (exame_uuid);',
];

const Map<String, String> kTableScripts = {
  tablePapeis: _kCreatePapeis,
  tablePermissoes: _kCreatePermissoes,
  tableUsuarios: _kCreateUsuarios,
  tablePapelPermissoes: _kCreatePapelPermissoes,
  tableTiposAchados: _kCreateTiposAchados,
  tableCasos: _kCreateCasos,
  tableAchados: _kCreateAchados,
  tableEvidenciasMultimidia: _kCreateEvidencias,
  tableLogAuditoria: _kCreateLogAuditoria,
  'exames_solicitados': kCreateExamesSolicitadosSql,
  tableDetalhesToxicologico: kCreateDetalhesToxicologicoSql,
  tableAmostrasGenetica: kCreateAmostrasGeneticaSql,
  tableFrascosAnatomo: kCreateFrascosAnatomoSql,
  tableAtns: kCreateAtnsSql,
};

final List<String> kFullDatabaseCreationScripts = [
  ...kTableScripts.values,
  ...kIndexCreationScripts,
];