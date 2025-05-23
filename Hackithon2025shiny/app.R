#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    https://shiny.posit.co/
#

library(shiny)
library(leaflet)
library(sf)

ui <- fluidPage(
  titlePanel("Mapa okresů ČR z GeoJSON"),
  leafletOutput("mapaCR", height = 600)
)

server <- function(input, output, session) {
  output$mapaCR <- renderLeaflet({
    # Načti GeoJSON
    okresy <- st_read("C:/Users/janko/Desktop/Hackithon/1/OKRESY_P.shp.geojson", quiet = TRUE)
    
    # Převod na GPS souřadnice
    okresy <- st_transform(okresy, 4326)
    
    # Vykresli mapu
    leaflet(okresy) %>%
      addTiles() %>%
      addPolygons(
        fillColor = "red",
        color = "darkgreen",
        weight = 1,
        fillOpacity = 0.5,
        popup = ~NAZEV  # ← správný sloupec pro název okresu
      ) %>%
      setView(lng = 15.5, lat = 49.8, zoom = 7)
  })
}

shinyApp(ui, server)


