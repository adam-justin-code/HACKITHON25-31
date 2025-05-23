library(shiny)
library(leaflet)
library(sf)

# UI
ui <- navbarPage("Mapa okresů",
                 tabPanel("Mapa",
                          leafletOutput("mapaCR", height = 600)
                 ),
                 tabPanel("Detail okresu",
                          h3(textOutput("okresNazev")),
                          p("Zde se zobrazí detailní informace o vybraném okrese."),
                          leafletOutput("okresMapa", height = 400)
                 )
)

# Server
server <- function(input, output, session) {
  # Načtení dat
  okresy <- st_read("data/1/OKRESY_P.shp.geojson", quiet = TRUE)
  okresy <- st_transform(okresy, 4326)
  
  # Reactive value pro výběr okresu
  vybranyOkres <- reactiveVal(NULL)
  
  # Výstup hlavní mapy
  output$mapaCR <- renderLeaflet({
    leaflet(okresy) %>%
      addTiles() %>%
      addPolygons(
        layerId = ~NAZEV,
        fillColor = "red",
        color = "darkgreen",
        weight = 1,
        fillOpacity = 0.5,
        popup = ~NAZEV
      ) %>%
      setView(lng = 15.25, lat = 49.75, zoom = 7) %>%
      setMaxBounds(11.8, 48.5, 18.9, 51.3)
  })
  
  # Kliknutí na polygon => přejdi do detailu
  observeEvent(input$mapaCR_shape_click, {
    vybranyOkres(input$mapaCR_shape_click$id)
    updateNavbarPage(session, "Mapa okresů", selected = "Detail okresu")
  })
  
  # Výstup názvu okresu
  output$okresNazev <- renderText({
    req(vybranyOkres())
    paste("Okres:", vybranyOkres())
  })
  
  # Výstup detailní mapy
  output$okresMapa <- renderLeaflet({
    req(vybranyOkres())
    detail <- subset(okresy, NAZEV == vybranyOkres())
    
    leaflet(detail) %>%
      addTiles() %>%
      addPolygons(
        fillColor = "blue",
        color = "black",
        weight = 2,
        fillOpacity = 0.6
      ) %>%
      setView(lng = st_coordinates(st_centroid(detail))[1],
              lat = st_coordinates(st_centroid(detail))[2],
              zoom = 10)
  })
}

shinyApp(ui, server)
