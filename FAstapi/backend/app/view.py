from databases import Database

async def create_view(database: Database):
    query = """
    SELECT FROM sldb2021_mistoregpobyt_pohlavi
        WHERE uzemi_typ = 'okres'
    """
    await database.execute(query=query)
    return {"message": "View created"}