library(shiny)
library(leaflet)
library(sf)
library(httr)
library(jsonlite)
library(dplyr)
library(stringi)

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
                                h3(textOutput("pocetObyvatel")),
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

# SERVER
server <- function(input, output, session) {
  # 1. Načtení dat z API
  res <- httr::GET("http://127.0.0.1:8000/okresy")
  json_text <- content(res, as = "text", encoding = "UTF-8")
  data_list <- fromJSON(json_text)
  df_db <- as.data.frame(data_list$okresy)
  df_db$pocet <- as.numeric(df_db$pocet)
  
  # 2. Normalizace názvů z API
  df_db <- df_db %>%
    mutate(
      NAZEV_api = case_when(
        uzemi_txt == "Praha" ~ "území Hlavního města Prahy",
        TRUE ~ uzemi_txt
      ),
      nazev_norm = stri_trans_general(tolower(NAZEV_api), "Latin-ASCII"),
      nazev_norm = trimws(nazev_norm)
    )
  
  # 3. Načtení shapefile s okresy
  okresy <- st_read("data/1/OKRESY_P.shp.geojson", quiet = TRUE)
  okresy <- st_transform(okresy, 4326)
  
  # 4. Normalizace názvů v polygonu
  okresy <- okresy %>%
    mutate(
      NAZEV_polygon = as.character(NAZEV),
      nazev_norm = stri_trans_general(tolower(NAZEV_polygon), "Latin-ASCII"),
      nazev_norm = trimws(nazev_norm)
    )
  output$pocetObyvatel <- renderText({
    req(vybranyOkres())
    data <- reactive_data()
    pocet <- data$pocet[data$nazev_norm == vybranyOkres()]
    if (is.na(pocet)) return("N/A")
    format(pocet, big.mark = " ", scientific = FALSE)
  })
  
  # 5. Spojení prostorových dat s daty z API
  map_data <- left_join(okresy, df_db, by = "nazev_norm")
  reactive_data <- reactiveVal(map_data)
  
  # 6. Reaktivní hodnota vybraného okresu
  vybranyOkres <- reactiveVal(NULL)
  
  # 7. Barevná paleta
  pal <- colorNumeric("YlOrRd", domain = map_data$pocet, na.color = "#cccccc")
  
  # 8. Výstup hlavní mapy
  output$mapaCR <- renderLeaflet({
    leaflet(map_data, options = leafletOptions(minZoom = 8, maxZoom = 15)) %>%
      addTiles() %>%
      addPolygons(
        layerId = ~nazev_norm,
        fillColor = ~pal(pocet),
        fillOpacity = 0.8,
        color = "white",
        weight = 1,
        label = ~paste0(NAZEV_polygon, ": ", format(pocet, big.mark = " ", scientific = FALSE)),
        highlightOptions = highlightOptions(color = "black", weight = 2, bringToFront = TRUE)
      ) %>%
      addLegend(
        pal = pal,
        values = ~pocet,
        opacity = 0.8,
        title = "Počet obyvatel",
        position = "bottomright"
      ) %>%
      setView(lng = 15.25, lat = 49.75, zoom = 7) %>%
      setMaxBounds(11.8, 48.5, 18.9, 51.3)
  })
  
  # 9. Kliknutí na polygon
  observeEvent(input$mapaCR_shape_click, {
    vybranyOkres(trimws(input$mapaCR_shape_click$id))
    updateNavbarPage(session, "Mapa okresů", selected = "Detail okresu")
  })
  
  # 10. Výstup názvu okresu
  output$okresNazev <- renderText({
    req(vybranyOkres())
    data <- reactive_data()
    nazev_okresu <- data$NAZEV_polygon[data$nazev_norm == vybranyOkres()]
    paste("Okres:", nazev_okresu)
  })
  
  # 11. Detailní mapa okresu
  output$okresMapa <- renderLeaflet({
    req(vybranyOkres())
    data <- reactive_data()
    detail <- data %>% filter(trimws(nazev_norm) == vybranyOkres())
    
    if (nrow(detail) == 0) {
      return(leaflet() %>% addTiles())
    }
    
    center <- st_centroid(st_union(detail))
    coords <- st_coordinates(center)
    
    leaflet(detail, options = leafletOptions(minZoom = 11, maxZoom = 18)) %>%
      addTiles() %>%
      addPolygons(
        fillColor = "blue",
        color = "black",
        weight = 5,
        fillOpacity = 0.2
      ) %>%
      setView(lng = coords[1], lat = coords[2], zoom = 11)
  })
}

# Spuštění aplikace
shinyApp(ui, server)
