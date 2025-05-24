library(shiny)
library(leaflet)
library(sf)

# UI
ui <- navbarPage("Vizualizace měst a obcí na území ČR",
                 
                 tabPanel("Mapa obcí",
                          div(
                            style = "height:90vh; width:100%;",
                            leafletOutput("mapaObci", height = "100%", width = "100%")
                          )
                 ),
                 
                 tabPanel("Detail obce",
                          fluidRow(
                            column(
                              width = 4,
                              div(
                                style = "background-color: #f0f0f0; padding: 20px; height: 90vh;",
                                h3(textOutput("obecNazev")),
                                p("Zde se zobrazí detailní informace o vybrané obci."),
                                p("Sem můžeš přidat další statistiky, grafy, nebo tabulky.")
                              )
                            ),
                            column(
                              width = 8,
                              div(
                                style = "background-color: #e0f7e0; height: 90vh;",
                                leafletOutput("obecMapa", height = "100%", width = "100%")
                              )
                            )
                          )
                 )
)

# SERVER
server <- function(input, output, session) {
  # Načtení dat obcí (pouze prvních 10)
  obce_vse <- st_read("C:/Users/janko/Desktop/HACKITHON25-31/Hackithon2025shiny/data/1/OBCE_P.geojson", quiet = TRUE)
  obce_vse <- st_transform(obce_vse, 4326)
  
  obce <- obce_vse[1:10, ]  # zobrazíme jen 10 obcí pro test
  
  # Reactive value pro výběr obce
  vybranaObec <- reactiveVal(NULL)
  
  # Výstup hlavní mapy obcí
  output$mapaObci <- renderLeaflet({
    leaflet(obce, options = leafletOptions(minZoom = 8, maxZoom = 15)) %>%
      addTiles() %>%
      addPolygons(
        layerId = ~NAZEV,
        fillColor = "orange",
        color = "black",
        weight = 0.7,
        fillOpacity = 0.4,
        popup = ~NAZEV
      ) %>%
      setView(lng = 15.25, lat = 49.75, zoom = 7) %>%
      setMaxBounds(11.8, 48.5, 18.9, 51.3)
  })
  
  # Kliknutí na polygon => přejdi do detailu
  observeEvent(input$mapaObci_shape_click, {
    vybranaObec(input$mapaObci_shape_click$id)
    updateNavbarPage(session, "Vizualizace měst a obcí na území ČR", selected = "Detail obce")
  })
  
  # Výstup názvu obce
  output$obecNazev <- renderText({
    req(vybranaObec())
    paste("Obec:", vybranaObec())
  })
  
  # Výstup detailní mapy obce
  output$obecMapa <- renderLeaflet({
    req(vybranaObec())
    detail <- subset(obce, NAZEV == vybranaObec())
    
    if (nrow(detail) == 0) return(leaflet() %>% addTiles())
    
    bbox <- st_bbox(detail)
    center_lng <- (bbox["xmin"] + bbox["xmax"]) / 2
    center_lat <- (bbox["ymin"] + bbox["ymax"]) / 2
    
    leaflet(detail, options = leafletOptions(minZoom = 11, maxZoom = 18)) %>%
      addTiles() %>%
      addPolygons(
        fillColor = "blue",
        color = "black",
        weight = 3,
        fillOpacity = 0.1
      ) %>%
      setView(lng = center_lng, lat = center_lat, zoom = 12) %>%
      setMaxBounds(
        lng1 = bbox["xmin"], lat1 = bbox["ymin"],
        lng2 = bbox["xmax"], lat2 = bbox["ymax"]
      )
  })
}

# Spuštění aplikace
shinyApp(ui = ui, server = server)
