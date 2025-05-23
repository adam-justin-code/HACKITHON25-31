library(shiny)
library(leaflet)
library(sf)

ui <- fluidPage(
  titlePanel("Mapa okresů ČR z GeoJSON"),
  leafletOutput("mapaCR", height = 900)
)

server <- function(input, output, session) {
  output$mapaCR <- renderLeaflet({
    # Načti GeoJSON soubor (uprav cestu dle potřeby)
    okresy <- st_read("C:/Users/janko/Desktop/Hackithon/1/OKRESY_P.shp.geojson", quiet = TRUE)
    
    # Převod souřadnic na WGS84 (GPS)
    okresy <- st_transform(okresy, 4326)
    
    # Vykresli mapu s omezeným zoomem a bounds
    leaflet(okresy, options = leafletOptions(minZoom = 8, maxZoom = 10)) %>%
      addTiles() %>%
      addPolygons(
        fillColor = "green",
        color = "darkgreen",
        weight = 1,
        fillOpacity = 0.5,
        popup = ~paste0(
          "<table style='width:100%; font-size:14px;'>",
          "<tr><th style='text-align:left;'>Název:</th><td>", NAZEV, "</td></tr>",
          "<tr><th style='text-align:left;'>Kód:</th><td>", KOD, "</td></tr>",
          "<tr><th style='text-align:left;'>LAU1 kód:</th><td>", LAU1_KOD, "</td></tr>",
          "<tr><th style='text-align:left;'>VÚSC kód:</th><td>", VUSC_KOD, "</td></tr>",
          "<tr><th style='text-align:left;'>NUTS3 kód:</th><td>", NUTS3_KOD, "</td></tr>",
          "</table>"
        )
      ) %>%
      setView(lng = 15.5, lat = 49.8, zoom = 7) %>%
      setMaxBounds(lng1 = 12.0, lat1 = 48.5, lng2 = 19.0, lat2 = 51.2)
  })
}

shinyApp(ui, server)
