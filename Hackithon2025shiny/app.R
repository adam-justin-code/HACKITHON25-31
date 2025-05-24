library(shiny)
library(leaflet)
library(sf)

# UI
ui <- navbarPage("Vizualizace statistických informací na území ČR",
                 tabPanel("Mapa okresů",
                          div(
                            style = "height:90vh; width:100%;",
                            leafletOutput("mapaCR", height = "100%", width = "100%")
                          )
                 ),
                 tabPanel("Detail okresu",
                          fluidRow(
                            column(
                              width = 4,
                              div(
                                style = "background-color: #f0f0f0; padding: 20px; height: 90vh;",
                                h3(textOutput("okresNazev")),
                                p("Zde se zobrazí detailní informace o vybraném okrese."),
                                p("Sem můžeš přidat další statistiky, grafy, nebo tabulky.")
                              )
                            ),
                            column(
                              width = 8,
                              div(
                                style = "background-color: #e0f7e0; height: 90vh;",
                                leafletOutput("okresMapa", height = "100%", width = "100%")
                              )
                            )
                          )
                 )
                 
)

# Server
server <- function(input, output, session) {
  # Načtení dat
  okresy <- st_read("data/1/OKRESY_P.shp.geojson", quiet = TRUE)
  okresy <- st_transform(okresy, 4326)
  
  # Reactive value pro výběr okresu
  vybranyOkres <- reactiveVal(NULL)
  
  # Výstup hlavní mapy s omezením zoomu a bounds na ČR
  output$mapaCR <- renderLeaflet({
    leaflet(okresy, options = leafletOptions(minZoom = 8, maxZoom = 15)) %>%
      addTiles() %>%
      addPolygons(
        layerId = ~NAZEV,
        fillColor = "green",
        color = "black",
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
  
  # Výstup detailní mapy s omezením na konkrétní okres
  output$okresMapa <- renderLeaflet({
    req(vybranyOkres())
    detail <- subset(okresy, NAZEV == vybranyOkres())
    
    # Bounding box okresu
    bbox <- st_bbox(detail)
    
    # Výpočet středu bboxu (bez centroidu = žádné varování)
    center_lng <- (bbox["xmin"] + bbox["xmax"]) / 2
    center_lat <- (bbox["ymin"] + bbox["ymax"]) / 2
    
    leaflet(detail, options = leafletOptions(minZoom = 11, maxZoom = 18)) %>%
      addTiles() %>%
      addPolygons(
        fillColor = "blue",
        color = "black",
        weight = 5,
        fillOpacity = 0.05
      )
  })
}

# Spuštění aplikace
shinyApp(ui, server)
