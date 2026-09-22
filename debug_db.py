import os
from pathlib import Path
from sqlalchemy import create_engine, text

# Procura DATABASE_URL no .env do backend ou define a padrão
backend_env = Path("C:/dev/cadeiaDeCustodia-IML-back/.env")
db_url = None
if backend_env.exists():
    with open(backend_env, "r", encoding="utf-8") as f:
        for line in f:
            if line.strip().startswith("DATABASE_URL="):
                db_url = line.strip().split("=", 1)[1].strip()
                break

if not db_url:
    db_url = "postgresql://postgres.ftocpawpvbdgnqrfevth:slN6Fq4hpqf7AsEi@aws-0-us-west-2.pooler.supabase.com:6543/postgres"

print(f"DATABASE_URL: {db_url.split('@')[-1] if '@' in db_url else db_url}")

try:
    engine = create_engine(db_url)
    with engine.connect() as conn:
        # 1. Quantos registros existem na tabela evidencias_multimidia
        result = conn.execute(text("SELECT COUNT(*) FROM evidencias_multimidia"))
        count = result.scalar()
        print(f"\n[1] Total de registros em 'evidencias_multimidia': {count}")

        # 2. Tente buscar especificamente o UUID 'e4a3cb44-934b-4697-b567-bcd6ab0d01b5'
        target_uuid = "e4a3cb44-934b-4697-b567-bcd6ab0d01b5"
        result_target = conn.execute(
            text("SELECT * FROM evidencias_multimidia WHERE uuid::text = :uuid"),
            {"uuid": target_uuid}
        )
        row_target = result_target.mappings().first()
        print(f"\n[2] Busca pelo UUID '{target_uuid}':")
        if row_target:
            print(f"    ENCONTRADO: {dict(row_target)}")
        else:
            print("    NÃO ENCONTRADO (UUID não existe no PostgreSQL)")

        # 3. Se houver registros, imprima os dados crus do primeiro registro encontrado (como dict)
        if count > 0:
            result_first = conn.execute(text("SELECT * FROM evidencias_multimidia LIMIT 1"))
            row_first = result_first.mappings().first()
            print(f"\n[3] Dados crus do primeiro registro encontrado:")
            print(f"    {dict(row_first)}")
        else:
            print("\n[3] Tabela 'evidencias_multimidia' está vazia.")

        # Auditoria complementar: verificar tabelas relacionadas a exames e fotos
        try:
            exames_cnt = conn.execute(text("SELECT COUNT(*) FROM exames_croqui")).scalar()
            print(f"\n[Audit Extra] Total em 'exames_croqui': {exames_cnt}")
            if exames_cnt > 0:
                res_exame = conn.execute(text("SELECT id, uuid, numero_laudo FROM exames_croqui LIMIT 3")).mappings().all()
                for r in res_exame:
                    print(f"    Exame: {dict(r)}")
        except Exception as e:
            print(f"\n[Audit Extra] Erro ao consultar exames_croqui: {e}")

except Exception as e:
    print(f"\nERRO AO CONECTAR OU EXECUTAR QUERY: {e}")
