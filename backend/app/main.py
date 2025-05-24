# # main.py
# from fastapi import FastAPI
# from database import database

# app = FastAPI()

# @app.get("/")
# def root():
#     return {"message": "API je živé!"}

# # Zapojení připojení k databázi při startu a ukončení aplikace
# @app.on_event("startup")
# async def startup():
#     await database.connect()

# @app.on_event("shutdown")
# async def shutdown():
#     await database.disconnect()

# # Ukázkový endpoint
# @app.get("/db_clean")
# async def get_vzdelani():
#     query = "SELECT uzemi_txt FROM sldb2021_mistoregpobyt_pohlavi"
#     rows = await database.fetch_all(query=query)
#     return rows


# if __name__ == "__main__":
#     import uvicorn

#     uvicorn.run("main:app", host="127.0.0.1", port=8000, reload=True)




# from fastapi import FastAPI
# from databases import Database

# DATABASE_URL = "sqlite:///./db_clean.db"  # nahraď svým reálným připojením, např. PostgreSQL
# database = Database(DATABASE_URL)

# app = FastAPI()


# async def create_view():
#     # Ukázkový SQL dotaz - uprav dle potřeby. CREATE VIEW nebo SELECT ... INTO VIEW
#     query = """
#     CREATE VIEW IF NOT EXISTS view_okres AS
#     SELECT * FROM sldb2021_mistoregpobyt_pohlavi
#     WHERE uzemi_typ = 'okres'
#     """
#     await database.execute(query=query)
#     return {"message": "View created"}


# @app.on_event("startup")
# async def startup():
#     await database.connect()



# @app.on_event("shutdown")
# async def shutdown():
#     await database.disconnect()


# @app.post("/create-view")
# async def create_db_view():
#     return await create_view()


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

# Lifespan pro inicializaci view při startu
@asynccontextmanager
async def lifespan(app: FastAPI):
    try:
        create_view_sync()
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
            SELECT uzemi_txt, SUM(hodnota) AS pocet
            FROM view_okres
            GROUP BY uzemi_txt
        """)

        rows = cursor.fetchall()
        columns = [description[0] for description in cursor.description]
        conn.close()

        data = [dict(zip(columns, row)) for row in rows]
        return {"okresy": data}
    except Exception as e:
        return {"error": str(e)}
