from fastapi import FastAPI
import sqlite3
import os
from contextlib import asynccontextmanager


BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(BASE_DIR, "db_clean.db")
# Funkce pro vytvoření view
def create_view_sync():
    if not os.path.exists(DB_PATH):
        raise FileNotFoundError(f"Databáze nebyla nalezena na cestě: {DB_PATH}")

    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    query = """
    CREATE VIEW IF NOT EXISTS view_okres AS
    SELECT * FROM sldb2021_mistoregpobyt_pohlavi
    WHERE uzemi_typ = 'okres'
    """

    cursor.execute(query)
    conn.commit()
    conn.close()

    print("✅ View 'view_okres' bylo vytvořeno.")


def create_view_mt():
    if not os.path.exists(DB_PATH):
        raise FileNotFoundError(f"Databáze nebyla nalezena na cestě: {DB_PATH}")

    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    query = """
    CREATE VIEW IF NOT EXISTS view_mt AS
    SELECT * FROM sldb2021_obybyty_material_druhdomu
    WHERE uzemi_typ = 'okres'
    """

    cursor.execute(query)
    conn.commit()
    conn.close()

    print("✅ View 'view_mt' bylo vytvořeno.")







def create_view_klasif_pohl():
    if not os.path.exists(DB_PATH):
        raise FileNotFoundError(f"Databáze nebyla nalezena na cestě: {DB_PATH}")

    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    query = """
    CREATE VIEW IF NOT EXISTS view_klasif_pohl AS
    SELECT * FROM sldb2021_klasif_pohlavi
    WHERE uzemi_typ = 'okres'
    """

    cursor.execute(query)
    conn.commit()
    conn.close()

    print("✅ View 'view_klasif_pohl' bylo vytvořeno.")

# Lifespan pro inicializaci view při startu
@asynccontextmanager
async def lifespan(app: FastAPI):
    try:
        create_view_sync()
        create_view_klasif_pohl()
        create_view_mt()
    except Exception as e:
        print(f"❌ Chyba při vytváření view: {e}")
    yield
    # sem můžeš dát kód pro "shutdown" fázi

# Inicializace aplikace s lifespanem
app = FastAPI(lifespan=lifespan)

@app.get("/")
def root():
    return {"message": "API běží"}

@app.post("/create-view")
def create_view_endpoint():
    try:
        create_view_sync()
        create_view_klasif_pohl()
        create_view_mt()
        return {"message": "View bylo vytvořeno ručně přes endpoint"}
    except Exception as e:
        return {"error": str(e)}

@app.get("/okresy")
def get_okresy():
    if not os.path.exists(DB_PATH):
        return {"error": "Databáze nebyla nalezena."}

    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()

        # 🔽 TADY nahradíš SELECT
        cursor.execute("""
            SELECT uzemi_txt, pohlavi_txt, SUM(hodnota) AS pocet 
            FROM view_okres
            GROUP BY uzemi_txt, pohlavi_txt
        """) # pridani pohlavi_txt do view

        rows = cursor.fetchall()
        columns = [description[0] for description in cursor.description]
        conn.close()

        data = [dict(zip(columns, row)) for row in rows]
        return {"okresy": data}
    except Exception as e:
        return {"error": str(e)}


@app.get("/klasifikace_pohlavi")
def get_klasif_pohl():
    if not os.path.exists(DB_PATH):
        return {"error": "Databáze nebyla nalezena."}

    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()

        # 🔽 TADY nahradíš SELECT
        cursor.execute("""
            SELECT uzemi_txt, klasif_txt, pohlavi_txt, SUM(hodnota) AS pocet 
            FROM view_klasif_pohl
            GROUP BY uzemi_txt, pohlavi_txt
        """) # pridani pohlavi_txt do view

        rows = cursor.fetchall()
        columns = [description[0] for description in cursor.description]
        conn.close()

        data = [dict(zip(columns, row)) for row in rows]
        return {"okresy": data}
    except Exception as e:
        return {"error": str(e)}


@app.get("/druh_materialu")
def get_klasif_pohl():
    if not os.path.exists(DB_PATH):
        return {"error": "Databáze nebyla nalezena."}

    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()

        # 🔽 TADY nahradíš SELECT
        cursor.execute("""
            SELECT uzemi_txt, material_txt, SUM(hodnota) AS pocet 
            FROM view_mt
            GROUP BY uzemi_txt, material_txt
        """) # pridani pohlavi_txt do view

        rows = cursor.fetchall()
        columns = [description[0] for description in cursor.description]
        conn.close()

        data = [dict(zip(columns, row)) for row in rows]
        return {"okresy": data}
    except Exception as e:
        return {"error": str(e)}