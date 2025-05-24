import sqlite3
from pathlib import Path
import shutil

# Původní a cílová databáze
ORIGINAL_DB = Path("data/db.sql")
CLEAN_DB = Path("data/db_clean.db")

# Pokud už existuje čistá verze, smaž ji
if CLEAN_DB.exists():
    CLEAN_DB.unlink()

# Zkopíruj původní databázi jako výchozí bod
shutil.copy(ORIGINAL_DB, CLEAN_DB)

# Pracujeme s kopií
conn = sqlite3.connect(CLEAN_DB)
conn.row_factory = sqlite3.Row
cursor = conn.cursor()

# Získání všech tabulek
cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
tabulky = [row["name"] for row in cursor.fetchall()]

for tabulka in tabulky:
    print(f"\n🧹 Čištění tabulky: {tabulka}")
    
    # Získání sloupců
    cursor.execute(f"PRAGMA table_info({tabulka})")
    sloupce = [row["name"] for row in cursor.fetchall()]

    if not sloupce:
        print("  ⏭️ Přeskočeno – prázdná nebo systémová tabulka.")
        continue

    # Sestav podmínku pro detekci NULL ve všech sloupcích
    podminky = " OR ".join([f"{col} IS NULL" for col in sloupce])
    
    # Smazání všech řádků, kde je alespoň jeden NULL
    delete_sql = f"DELETE FROM {tabulka} WHERE {podminky}"
    cursor.execute(delete_sql)
    conn.commit()

    print(f"  ✅ Vyčištěno.")

conn.close()
print("\n🎉 Hotovo! Vznikla databáze bez NULL hodnot: data/db_clean.db")
