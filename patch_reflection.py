import os
import sys

path = r"C:\dev\cadeiaDeCustodia-IML-back\app\infrastructure\repositories\caso_repository.py"
if not os.path.exists(path):
    print("Backend repo not found.")
    sys.exit(1)
    
with open(path, "r", encoding="utf-8") as f:
    content = f.read()

# Fix `bulk_upsert_pericias`
old_bulk = """        from sqlalchemy import Table
        from sqlalchemy.dialects.postgresql import insert
        
        bind = self.db.get_bind()
        meta = PericiaMedicoLegalORM.metadata
        
        t_exame = Table("exame_necroscopico", meta, autoload_with=bind, extend_existing=True)
        t_deslocamento = Table("deslocamento_iml", meta, autoload_with=bind, extend_existing=True)
        t_vitima = Table("vitima", meta, autoload_with=bind, extend_existing=True)"""
new_bulk = """        from sqlalchemy.dialects.postgresql import insert
        from app.infrastructure.database.models._table_cache import get_cached_reflected_table
        
        bind = self.db.get_bind()
        
        t_exame = get_cached_reflected_table("exame_necroscopico", bind)
        t_deslocamento = get_cached_reflected_table("deslocamento_iml", bind)
        t_vitima = get_cached_reflected_table("vitima", bind)"""
content = content.replace(old_bulk, new_bulk)

# Fix `_fetch_related_data`
old_fetch = """        from sqlalchemy import Table, select
        bind = self.db.get_bind()
        meta = PericiaMedicoLegalORM.metadata
        t_exame = Table("exame_necroscopico", meta, autoload_with=bind, extend_existing=True)
        t_desloc = Table("deslocamento_iml", meta, autoload_with=bind, extend_existing=True)
        t_vitima = Table("vitima", meta, autoload_with=bind, extend_existing=True)"""
new_fetch = """        from sqlalchemy import select
        from app.infrastructure.database.models._table_cache import get_cached_reflected_table
        bind = self.db.get_bind()
        t_exame = get_cached_reflected_table("exame_necroscopico", bind)
        t_desloc = get_cached_reflected_table("deslocamento_iml", bind)
        t_vitima = get_cached_reflected_table("vitima", bind)"""
content = content.replace(old_fetch, new_fetch)

with open(path, "w", encoding="utf-8") as f:
    f.write(content)

print("Backend repository reflection patched successfully.")
