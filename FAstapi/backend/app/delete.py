import sqlite3
from pathlib import Path
import shutil

ORIGINAL_DB = Path("data/db.sql")
CLEAN_DB = Path("data/db_clean.db")

if CLEAN_DB.exists():
    CLEAN_DB.unlink()

shutil.copy(ORIGINAL_DB, CLEAN_DB)

conn = sqlite3.connect(CLEAN_DB)
conn.row_factory = sqlite3.Row
cursor = conn.cursor()

cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
tabulky = [row["name"] for row in cursor.fetchall()]
countData = 0
for tabulka in tabulky:
    print(f"\n Odstranení všech dat, které mají null data v: {tabulka}")
    
    cursor.execute(f"PRAGMA table_info({tabulka})")
    sloupce = [row["name"] for row in cursor.fetchall()]

    if not sloupce:
        continue

    podminky = " OR ".join([f"{col} IS NULL" for col in sloupce])
    
    delete_sql = f"DELETE FROM {tabulka} WHERE {podminky}"
    cursor.execute(delete_sql)
    conn.commit()

    print(f"Zatím smazáno dat: {countData}")

conn.close()
print(f"Celkem bylo smazáno: {countData} řádků")
print("db je čistá")