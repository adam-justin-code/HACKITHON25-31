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
                                p("Zde se zobrazí obce náležící do vybraného okresu."),
                                p("Sem můžeš přidat další statistiky, přehled obcí nebo tabulky.")
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

# SERVER
server <- function(input, output, session) {
  # Načti okresy
  okresy <- st_read("data/1/OKRESY_P.shp.geojson", quiet = TRUE)
  okresy <- st_transform(okresy, 4326)
  
  # Načti obce
  obce <- st_read("data/1/OBCE_P.geojson", quiet = TRUE)
  obce <- st_transform(obce, 4326)
  
  # Reactive hodnota: vybraný okres
  vybranyOkres <- reactiveVal(NULL)
  
  # Mapa ČR – okresy
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
  
  # Kliknutí na okres => přechod do detailu
  observeEvent(input$mapaCR_shape_click, {
    vybranyOkres(input$mapaCR_shape_click$id)
    updateNavbarPage(session, "Vizualizace statistických informací na území ČR", selected = "Detail okresu")
  })
  
  # Název okresu v textu
  output$okresNazev <- renderText({
    req(vybranyOkres())
    paste("Okres:", vybranyOkres())
  })
  
  # Detailní mapa obcí v okresu
  output$okresMapa <- renderLeaflet({
    req(vybranyOkres())
    
    # Najdi záznam okresu podle názvu
    okres_detail <- subset(okresy, NAZEV == vybranyOkres())
    
    # Získej kód okresu
    kod_okresu <- as.character(okres_detail$KOD)
    
    # Vyfiltruj obce patřící do okresu
    obce_v_okrese <- subset(obce, OKRES_KOD == kod_okresu)
    
    # Výpočet středu z bounding boxu
    bbox <- st_bbox(okres_detail)
    center_lng <- (bbox["xmin"] + bbox["xmax"]) / 2
    center_lat <- (bbox["ymin"] + bbox["ymax"]) / 2
    
    leaflet(obce_v_okrese, options = leafletOptions(minZoom = 10, maxZoom = 18)) %>%
      addTiles() %>%
      addPolygons(
        fillColor = "blue",
        color = "black",
        weight = 1,
        fillOpacity = 0.4,
        popup = ~NAZEV
      ) %>%
      setView(lng = center_lng, lat = center_lat, zoom = 11) %>%
      setMaxBounds(
        lng1 = bbox["xmin"], lat1 = bbox["ymin"],
        lng2 = bbox["xmax"], lat2 = bbox["ymax"]
      )
  })
}

# Spuštění
shinyApp(ui = ui, server = server)
