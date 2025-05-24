from glob import glob
import sqlite3 as sql

result = glob("Hackithon/sldb/csv/*.sql")

# print(result)


# 2. Připoji se k databázi
conn = sql.connect("db.sql")

for i in result:
    f = open(i, "r", encoding="utf-8")
    contents = f.read()
    contents = contents.replace("START TRANSACTION", "BEGIN")
    
    print(i)
    conn.executescript(contents)
    f.close()
    


# 3. Ulož do nové tabulky
# df.to_sql("obce", conn, if_exists="replace", index=False)


# 4. Zavři připojení
