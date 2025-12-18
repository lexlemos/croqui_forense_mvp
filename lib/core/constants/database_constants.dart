const String kDatabaseName = 'croqui_forense_mvp.db';
const int kDatabaseVersion = 1;

const String tableUsuarios = 'usuarios'; 
const String tablePapeis = 'papeis';
const String tablePermissoes = 'permissoes';
const String tablePapelPermissoes = 'papel_permissoes';
const String tableTiposAchados = 'tipos_achados';
const String tableTemplatesDiagrama = 'templates_diagrama';
const String tableCasos = 'casos';
const String tableDiagramasDoCaso = 'diagramas_do_caso';
const String tableAchados = 'achados';
const String tableEvidenciasMultimidia = 'evidencias_multimidia';
const String tableLogAuditoria = 'log_auditoria';

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
    caminho_icone TEXT,
    schema_formulario_json TEXT,
    versao INTEGER DEFAULT 1,
    criado_em TEXT,
    atualizado_em TEXT
);
''';

const String _kCreateTemplates = '''
CREATE TABLE templates_diagrama (
    id TEXT PRIMARY KEY,
    nome TEXT NOT NULL,
    caminho_svg TEXT,
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
    criado_em_rede_confiavel TEXT,
    atualizado_em TEXT,
    device_id TEXT,
    proveniencia TEXT,
    FOREIGN KEY (id_usuario_criador) REFERENCES usuarios(id) ON DELETE RESTRICT
);
''';

const String _kCreateDiagramas = '''
CREATE TABLE diagramas_do_caso (
    uuid TEXT PRIMARY KEY,
    caso_uuid TEXT NOT NULL,
    template_id TEXT NOT NULL,
    removido INTEGER DEFAULT 0,
    versao INTEGER DEFAULT 1,
    criado_em TEXT,
    atualizado_em TEXT,
    device_id TEXT,
    FOREIGN KEY (caso_uuid) REFERENCES casos(uuid) ON DELETE CASCADE,
    FOREIGN KEY (template_id) REFERENCES templates_diagrama(id) ON DELETE RESTRICT
);
''';

const String _kCreateAchados = '''
CREATE TABLE achados (
    uuid TEXT PRIMARY KEY,
    diagrama_caso_uuid TEXT NOT NULL,
    tipo_achado_id TEXT NOT NULL,
    numero_sequencial INTEGER,
    pos_x REAL,
    pos_y REAL,
    esta_pendente INTEGER DEFAULT 1,
    dados_preenchidos_json TEXT,
    observacoes_texto TEXT,
    removido INTEGER DEFAULT 0,
    versao INTEGER DEFAULT 1,
    criado_em TEXT,
    atualizado_em TEXT,
    device_id TEXT,
    proveniencia TEXT,
    FOREIGN KEY (diagrama_caso_uuid) REFERENCES diagramas_do_caso(uuid) ON DELETE CASCADE,
    FOREIGN KEY (tipo_achado_id) REFERENCES tipos_achados(id) ON DELETE RESTRICT
);
''';

const String _kCreateEvidencias = '''
CREATE TABLE evidencias_multimidia (
    uuid TEXT PRIMARY KEY,
    achado_uuid TEXT NOT NULL,
    substituida_por TEXT,
    tipo TEXT DEFAULT 'FOTO',
    caminho_arquivo_encriptado TEXT,
    hash_arquivo TEXT,
    hmac_arquivo TEXT,
    salt_base64 TEXT,
    chave_cifrada_base64 TEXT,
    hash_exif TEXT,
    removido INTEGER DEFAULT 0,
    versao INTEGER DEFAULT 1,
    criado_em TEXT,
    atualizado_em TEXT,
    device_id TEXT,
    FOREIGN KEY (achado_uuid) REFERENCES achados(uuid) ON DELETE CASCADE,
    FOREIGN KEY (substituida_por) REFERENCES evidencias_multimidia(uuid) ON DELETE SET NULL
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
  'CREATE INDEX idx_diagramas_caso ON diagramas_do_caso (caso_uuid);',
  'CREATE INDEX idx_diagramas_template ON diagramas_do_caso (template_id);',
  'CREATE INDEX idx_achados_diagrama ON achados (diagrama_caso_uuid);',
  'CREATE INDEX idx_achados_tipo ON achados (tipo_achado_id);',
  'CREATE INDEX idx_evidencias_achado ON evidencias_multimidia (achado_uuid);',
  'CREATE INDEX idx_evidencias_substituta ON evidencias_multimidia (substituida_por);',
  'CREATE INDEX idx_log_caso ON log_auditoria (caso_uuid);',
  'CREATE INDEX idx_log_usuario ON log_auditoria (id_usuario);',
  'CREATE INDEX idx_casos_status ON casos (status);',
  'CREATE INDEX idx_achados_pendente ON achados (esta_pendente);',
];

const Map<String, String> kTableScripts = {
  tablePapeis: _kCreatePapeis,
  tablePermissoes: _kCreatePermissoes,
  tableUsuarios: _kCreateUsuarios,
  tablePapelPermissoes: _kCreatePapelPermissoes,
  tableTiposAchados: _kCreateTiposAchados,
  tableTemplatesDiagrama: _kCreateTemplates,
  tableCasos: _kCreateCasos,
  tableDiagramasDoCaso: _kCreateDiagramas,
  tableAchados: _kCreateAchados,
  tableEvidenciasMultimidia: _kCreateEvidencias,
  tableLogAuditoria: _kCreateLogAuditoria,
};

final List<String> kFullDatabaseCreationScripts = [
  ...kTableScripts.values,
  ...kIndexCreationScripts,
];