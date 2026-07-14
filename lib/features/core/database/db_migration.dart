const int dbVersion = 1;

// Schema SQL para criar tabelas SQLite
const String createPessoaTable = '''
  CREATE TABLE IF NOT EXISTS tb_pessoa (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tipo_pessoa TEXT NOT NULL,
    rsocial_nome TEXT NOT NULL,
    fantasia_apelido TEXT,
    cnpj_cpf TEXT UNIQUE,
    ie_rg TEXT,
    endereco TEXT,
    numero TEXT,
    complemento TEXT,
    bairro TEXT,
    cep TEXT,
    telefone TEXT,
    celular TEXT,
    email TEXT,
    contato TEXT,
    referencia TEXT,
    status TEXT DEFAULT 'A',
    cliente TEXT DEFAULT 'N',
    transportador TEXT DEFAULT 'N',
    contribuinte TEXT DEFAULT 'N',
    data_cadastro TEXT,
    data_atualizacao TEXT
  );
''';

const String createMotoristaTable = '''
  CREATE TABLE IF NOT EXISTS tb_motorista (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nome TEXT NOT NULL,
    apelido TEXT,
    cpf TEXT UNIQUE,
    rg TEXT,
    telefone TEXT,
    celular TEXT,
    email TEXT,
    endereco TEXT,
    numero TEXT,
    complemento TEXT,
    bairro TEXT,
    cidade TEXT,
    cep TEXT,
    cnh TEXT,
    cnh_validade TEXT,
    status TEXT DEFAULT 'A',
    data_cadastro TEXT,
    data_atualizacao TEXT
  );
''';

const String createColaboradorTable = '''
  CREATE TABLE IF NOT EXISTS tb_colaborador (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    nome TEXT NOT NULL,
    apelido TEXT,
    cpf TEXT UNIQUE,
    rg TEXT,
    funcao TEXT,
    telefone TEXT,
    celular TEXT,
    email TEXT,
    endereco TEXT,
    numero TEXT,
    bairro TEXT,
    cep TEXT,
    status TEXT DEFAULT 'A',
    data_cadastro TEXT,
    data_atualizacao TEXT
  );
''';

const String createVeiculoTable = '''
  CREATE TABLE IF NOT EXISTS tb_veiculo (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    placa TEXT UNIQUE,
    marca TEXT,
    modelo TEXT,
    cor TEXT,
    ano TEXT,
    tipo TEXT,
    renavam TEXT,
    chassi TEXT,
    status TEXT DEFAULT 'A',
    data_cadastro TEXT,
    data_atualizacao TEXT
  );
''';

const String createRotaTable = '''
  CREATE TABLE IF NOT EXISTS tb_rota (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    descricao TEXT NOT NULL,
    regiao TEXT,
    motorista_id INTEGER,
    veiculo_id INTEGER,
    status TEXT DEFAULT 'A',
    data_prevista TEXT,
    data_inicio TEXT,
    data_fim TEXT,
    paradas INTEGER,
    km_estimado REAL,
    km_realizado REAL,
    data_cadastro TEXT,
    data_atualizacao TEXT,
    FOREIGN KEY (motorista_id) REFERENCES tb_motorista(id),
    FOREIGN KEY (veiculo_id) REFERENCES tb_veiculo(id)
  );
''';

const String createMovimentoTable = '''
  CREATE TABLE IF NOT EXISTS tb_movimento_conta (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tipo TEXT NOT NULL,
    status TEXT,
    conta INTEGER,
    conta_nome TEXT,
    valor REAL,
    dt_emissao TEXT,
    dt_compensado TEXT,
    historico TEXT,
    data_cadastro TEXT,
    data_atualizacao TEXT
  );
''';

const String createSyncQueueTable = '''
  CREATE TABLE IF NOT EXISTS tb_sync_queue (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    tabela TEXT NOT NULL,
    operacao TEXT NOT NULL,
    registro_id INTEGER,
    dados TEXT NOT NULL,
    status TEXT DEFAULT 'P',
    tentativas INTEGER DEFAULT 0,
    data_criacao TEXT,
    data_ultimo_tentativa TEXT
  );
''';

// Lista de todas as migrações
List<String> getMigrations() {
  return [
    createPessoaTable,
    createMotoristaTable,
    createColaboradorTable,
    createVeiculoTable,
    createRotaTable,
    createMovimentoTable,
    createSyncQueueTable,
  ];
}
