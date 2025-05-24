# ==== Knihovny ====
library(shiny)
library(leaflet)
library(sf)
library(httr)
library(jsonlite)
library(dplyr)
library(stringi)
library(ggplot2)

# ==== UI ====
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
                                style = "background-color: #f0f0f0; padding: 20px; height: 90vh; overflow-y: auto;",
                                h3(textOutput("okresNazev")),
                                h4("Počet obyvatel:"),
                                h3(textOutput("pocetObyvatel")),
                                h4("Poměr mužů a žen:"),
                                plotOutput("grafPohlavi", height = "250px"),
                                h4("Materiál budov:"),
                                plotOutput("grafMaterial", height = "250px")
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
                 ),
                 
                 tabPanel("Porovnání materiálů",
                          fluidPage(
                            fluidRow(
                              column(
                                width = 12,
                                checkboxGroupInput("vybrane_materialy", "Vyber typy materiálu:",
                                                   choices = NULL, selected = NULL, inline = TRUE)
                              )
                            ),
                            fluidRow(
                              column(
                                width = 12,
                                div(
                                  style = "overflow-x: auto;",
                                  plotOutput("sloupcovyGrafMaterial", height = "600px", width = "2000px")
                                )
                              )
                            )
                          )
                 ),
                 
                 tabPanel("Nezaměstnanost",
                          leafletOutput("mapaNezamestnanost", height = "90vh", width = "100%")
                 )
)

# ==== SERVER ====
server <- function(input, output, session) {
  
  # --- 0. Načtení dat nezaměstnanosti ---
  df_nezamestnanost <- read.csv("data/nezamestnanost.csv", encoding = "UTF-8") %>%
    rename(Obec = Obec, nezamestnanost = Hodnota) %>%
    mutate(nazev_norm = stri_trans_general(tolower(trimws(Obec)), "Latin-ASCII"))
  
  
  # --- 1. Získání dat z API ---
  res_obyv <- httr::GET("http://127.0.0.1:8000/okresy")
  df_obyv <- fromJSON(content(res_obyv, "text", encoding = "UTF-8"))$okresy %>%
    as.data.frame() %>%
    mutate(
      nazev_norm = stri_trans_general(tolower(trimws(uzemi_txt)), "Latin-ASCII"),
      pohlavi_txt = tolower(pohlavi_txt)
    )
  
  df_obyv_suma <- df_obyv %>%
    group_by(nazev_norm) %>%
    summarise(pocet = sum(pocet, na.rm = TRUE), .groups = "drop")
  
  res_mat <- httr::GET("http://127.0.0.1:8000/druh_materialu")
  df_mat <- fromJSON(content(res_mat, "text", encoding = "UTF-8"))$okresy %>%
    as.data.frame() %>%
    mutate(nazev_norm = stri_trans_general(tolower(trimws(uzemi_txt)), "Latin-ASCII"))
  
  # --- 2. Načtení shapefile ---
  okresy <- st_read("data/1/OKRESY_P.shp.geojson", quiet = TRUE) %>%
    st_transform(4326) %>%
    mutate(
      NAZEV_polygon = as.character(NAZEV),
      nazev_norm = stri_trans_general(tolower(trimws(NAZEV)), "Latin-ASCII")
    )
  
  # --- 3. Spojení dat ---
  map_data <- left_join(okresy, df_obyv_suma, by = "nazev_norm")
  reactive_data <- reactiveVal(map_data)
  vybranyOkres <- reactiveVal(NULL)
  pal <- colorNumeric("YlOrRd", domain = map_data$pocet, na.color = "#cccccc")
  
  # --- 4. Mapa ČR ---
  output$mapaCR <- renderLeaflet({
    leaflet(map_data, options = leafletOptions(minZoom = 8, maxZoom = 15)) %>%
      addTiles() %>%
      addPolygons(
        layerId = ~nazev_norm,
        fillColor = ~pal(pocet),
        fillOpacity = 0.8,
        color = "darkgreen",
        weight = 1,
        label = ~paste0(NAZEV_polygon, ": ", format(pocet, big.mark = " ", scientific = FALSE)),
        highlightOptions = highlightOptions(color = "blue", weight = 2, bringToFront = TRUE)
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
  
  # --- 5. Kliknutí na polygon ---
  observeEvent(input$mapaCR_shape_click, {
    vybrany_id <- trimws(input$mapaCR_shape_click$id)
    vybranyOkres(vybrany_id)
    updateNavbarPage(session, "Mapa okresů", selected = "Detail okresu")
    data <- reactive_data()
    detail <- data %>% filter(nazev_norm == vybrany_id)
    leafletProxy("mapaCR") %>%
      clearGroup("vybrany") %>%
      addPolygons(
        data = detail,
        fillColor = "blue",
        fillOpacity = 0.4,
        color = "black",
        weight = 3,
        group = "vybrany"
      )
  })
  
  # --- 6. Výstupy pro detail okresu ---
  output$okresNazev <- renderText({
    req(vybranyOkres())
    reactive_data()$NAZEV_polygon[reactive_data()$nazev_norm == vybranyOkres()]
  })
  
  output$pocetObyvatel <- renderText({
    req(vybranyOkres())
    pocet <- reactive_data()$pocet[reactive_data()$nazev_norm == vybranyOkres()]
    if (is.na(pocet)) return("N/A")
    format(pocet, big.mark = " ", scientific = FALSE)
  })
  
  output$okresMapa <- renderLeaflet({
    req(vybranyOkres())
    detail <- reactive_data() %>% filter(nazev_norm == vybranyOkres())
    if (nrow(detail) == 0) return(leaflet() %>% addTiles())
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
  
  # --- 7. Grafy detail okresu ---
  output$grafPohlavi <- renderPlot({
    req(vybranyOkres())
    df_okres <- df_obyv %>%
      filter(nazev_norm == vybranyOkres()) %>%
      group_by(pohlavi_txt) %>%
      summarise(pocet = sum(pocet), .groups = "drop") %>%
      mutate(
        procenta = round(pocet / sum(pocet) * 100, 1),
        popisek = paste0(pohlavi_txt, "\n", procenta, "%")
      )
    
    ggplot(df_okres, aes(x = "", y = pocet, fill = pohlavi_txt)) +
      geom_bar(stat = "identity", width = 1) +
      coord_polar("y") +
      geom_text(aes(label = popisek),
                position = position_stack(vjust = 0.5),
                size = 5, color = "white", fontface = "bold") +
      theme_void() +
      scale_fill_manual(values = c("muž" = "#1f77b4", "žena" = "#ff7f0e")) +
      labs(fill = "Pohlaví")
  })
  
  output$grafMaterial <- renderPlot({
    req(vybranyOkres())
    df_okres <- df_mat %>% filter(nazev_norm == vybranyOkres())
    ggplot(df_okres, aes(x = "", y = pocet, fill = material_txt)) +
      geom_bar(stat = "identity", width = 1) +
      coord_polar("y") +
      theme_void() +
      labs(fill = "Materiál")
  })
  
  # --- 8. Filtrování typů materiálu ---
  observe({
    materialy <- sort(unique(df_mat$material_txt))
    updateCheckboxGroupInput(session, "vybrane_materialy",
                             choices = materialy,
                             selected = materialy)
  })
  
  # --- 9. Sloupcový graf materiálů napříč okresy ---
  output$sloupcovyGrafMaterial <- renderPlot({
    req(input$vybrane_materialy)
    df_filtered <- df_mat %>% filter(material_txt %in% input$vybrane_materialy)
    df_agg <- df_filtered %>%
      group_by(nazev_norm, material_txt) %>%
      summarise(pocet = sum(pocet, na.rm = TRUE), .groups = "drop")
    
    ggplot(df_agg, aes(x = reorder(nazev_norm, -pocet), y = pocet, fill = material_txt)) +
      geom_bar(stat = "identity", position = "stack") +
      labs(x = "Okres", y = "Počet budov", fill = "Materiál") +
      theme_minimal() +
      theme(
        axis.text.x = element_text(angle = 90, hjust = 1, size = 14),
        axis.text.y = element_text(size = 13),
        axis.title = element_text(size = 16),
        legend.title = element_text(size = 14),
        legend.text = element_text(size = 12)
      ) +
      scale_y_continuous(labels = scales::label_comma())
  })
  
  # --- 10. Heatmapa nezaměstnanosti ---
  output$mapaNezamestnanost <- renderLeaflet({
    mapa_nez <- left_join(okresy, df_nezamestnanost, by = "nazev_norm")
    
    pal_nez <- colorNumeric("Blues", domain = mapa_nez$nezamestnanost, na.color = "#cccccc")
    
    leaflet(mapa_nez, options = leafletOptions(minZoom = 8, maxZoom = 15)) %>%
      addTiles() %>%
      addPolygons(
        fillColor = ~pal_nez(nezamestnanost),
        fillOpacity = 0.8,
        color = "white",
        weight = 1,
        label = ~paste0(NAZEV_polygon, ": ", nezamestnanost, " %"),
        highlightOptions = highlightOptions(color = "black", weight = 2, bringToFront = TRUE)
      ) %>%
      addLegend(
        pal = pal_nez,
        values = ~nezamestnanost,
        opacity = 0.8,
        title = "Nezaměstnanost (%)",
        position = "bottomright"
      ) %>%
      setView(lng = 15.25, lat = 49.75, zoom = 7) %>%
      setMaxBounds(11.8, 48.5, 18.9, 51.3)
  })
}

# ==== Spuštění aplikace ====
shinyApp(ui, server)
