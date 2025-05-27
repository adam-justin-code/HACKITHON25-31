import sqlite3

conn = sqlite3.connect("db.db")
cursor = conn.cursor()
cursor.execute("SELECT name FROM sqlite_master WHERE type='table'")
tabulky = [row[0] for row in cursor.fetchall()]

tabulky_s_okresem = []

for tabulka in tabulky:
    cursor.execute(f"PRAGMA table_info({tabulka})")
    sloupce = [row[1] for row in cursor.fetchall()]
    if any("uzemi_typ" in s.lower() for s in sloupce):
        tabulky_s_okresem.append((tabulka, sloupce))

print(f"Tabulky obsahující sloupec okres: {[t[0] for t in tabulky_s_okresem]}")
