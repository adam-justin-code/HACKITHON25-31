# database.py
from databases import Database

# Předpokládáme, že soubor vzdelani.db je ve stejné složce nebo v root projektu
DATABASE_URL = "sqlite:///db_clean.db"

# Inicializace databázového připojení
database = Database(DATABASE_URL)
