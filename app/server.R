library(leaflet)
library(tidyverse)
library(stringr)
library(htmltools)
library(ggplot2)
library(Hmisc)
library(lubridate)
library(readxl)
library(rgdal)
library(sf)
library(httr)


server <- function(input, output, session) {
  

  ##Parameters -----------------------------------------------------------------------------------------------------------
  
  downloadGit = "https://github.com/araupontones/covid19mx/blob/master/downloads/download_datos_abiertos.R?raw=TRUE"
  
  Sys.setlocale("LC_TIME", "Spanish")
  #fuente="obtenidos a través del paquete <i>covidMex</i> (Reyes,2020) y el repositario <i>covid19_mex</i> (Guzmán, 2020)"
  fuente="obtenidos a través de www.gob.mx y limpiados por @AndresArau"
  INEGI = "| Los datos de población INEGI. Censo de Población y Vivienda 2010"
  
  #parameters
  
  hora = "20:00 (CST)"
  colorH="steelblue"
  colorM="#652D90"
  
  
  
  
  
  
## Run script to download data from github -------------------------------------------------------------------------------------------------
  
  
  source(downloadGit)

##limpiar datos ------------------------------------------------------------------------------------------------------ 
  ##manterner solamente casos confirmados Y hacer tabla consistente con version previa
  table = subset(tabla_casos_covid, RESULTADO =="Positivo SARS-CoV-2") %>%
    rename(Edad = EDAD,
           Sexo = SEXO,
           Fecha_reporte = FECHA_ACTUALIZACION,
           Fecha = FECHA_INGRESO,
           Estado = ENTIDAD_RES) %>%
    mutate(Sexo = if_else(Sexo=="MUJER", "F", "M"),
           Defuncion = if_else(is.na(FECHA_DEF),0,1),
           Estado = str_to_title(Estado)
    ) %>%
    arrange(Fecha) %>% ##tomando la fecha de ingreso como fecha
    mutate(Caso = row_number())
  
  
  
  ##grupos de edad
  dfTables =table %>%
    mutate(Grupo = case_when(Edad %in% c(0:9) ~ "0-9", #crear grupos de edad
                             Edad %in% c(10:19) ~ "10-19",
                             Edad %in% c(20:29) ~ "20-29",
                             Edad %in% c(30:39) ~ "30-39",
                             Edad %in% c(40:49) ~ "40-49",
                             Edad %in% c(50:59) ~ "50-59",
                             Edad %in% c(60:69) ~ "60-69",
                             Edad %in% c(70:79) ~ "70-79",
                             Edad >79 ~ "80+"
    ))
  
  
  
  
  ## Crear diasData -----------------------------------------------------------------------------------------------------
  
  diasData = table %>%
    group_by(Fecha) %>%
    summarise(casos_nuevos= n(),
              decesos = sum(Defuncion)) %>%
    mutate(Casos = cumsum(casos_nuevos),
           Casoslog=log(Casos),
           Dia = row_number()) %>%
    rename(Muertos = decesos,
           Nuevos = casos_nuevos) %>%
    arrange(Dia) %>%
    mutate(fecha= paste(day(Fecha), month(Fecha, label = T)),
           Nuevos = Casos - lag(Casos))
    
  
  
  muertos = diasData %>%
    select(Muertos, Fecha) %>%
    rename(DefuncionesMasQAyer= Muertos) %>%
    mutate(Defunciones = cumsum(DefuncionesMasQAyer))
  
  
  ## Read data from github ---------------------------------------------------------------------------------------------
  #options(encoding = 'UTF-8')
  

  
  ###desde aqui
  ##table of poblacion
  # url ="https://github.com/araupontones/covid19mx/blob/master/app/poblacion.rds?raw=true"
  # rds_file = "poblacion.rds"
  # poblacion = get_rds(url = url, rds_file = "poblacion.rds")
  poblacion = read_rds("poblacion.rds")
  
  
  
  #municipios_shp = readRDS("municipios.rds")
  # url ="https://github.com/araupontones/covid19mx/blob/master/app/centroids_mun.rds?raw=true"
  # rds_file = "centroids_mun.rds"
  # municipios_centroids = get_rds(url = url, rds_file = "centroids_mun.rds")
 
  
  municipios_centroids = read_rds("centroids_mun.rds")
  
  
  
  
  ###############################################################################
  
  #function to translate
  
  
  english_months <- c("January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December")
  spanish_months <- c("enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto", "septiembre", "octubre", "noviembre", "diciembre")
  
  
  to_spanish_dict <- spanish_months
  names(to_spanish_dict) <- english_months
  
  translate_date <- function(date, output_lang = "es"){
    if(output_lang == "es"){
      str_replace_all(date, to_spanish_dict)
    }
  }
  
  
  
  
  
  #---------------------------------------------
  #fecha de hoy ayer
  last = max(dfTables$Fecha_reporte)
  second_last = last - 1
  
  fecha = paste(day(last), "de", month(last, label = T, abbr = F)) #fecha de ultimo registro
  fecha = translate_date(fecha)
  ayer =  paste(day(second_last), "de", month(second_last, label = T, abbr = F)) #fecha de penultimo registro
  ayer = translate_date(ayer)
  
  
  #boxes total casos
  totalCases = nrow(dfTables)
  #Percentage men and women
  mujeres = paste0(round(sum(dfTables$Sexo=="F") /nrow(dfTables), digits = 2) *100,"% mujeres")
  hombres = paste0(round(sum(dfTables$Sexo=="M") /nrow(dfTables), digits = 2)*100, "% hombres")
  
  #Nuevos Casos
  casosNuevos=diasData$Nuevos[nrow(diasData)]
  
  #Dia desde inicio
  DiaDesde = max(diasData$Dia)
  
  #total muertes 
  
  totalMuertes = max(muertos$Defunciones)
  
  #mas muertos que ayer
  muertosMasqAyer = muertos$DefuncionesMasQAyer[nrow(muertos)]
  
  
  #Para mapaconfirmar que todos los nombres estan correctos
  casosEstados = dfTables %>%
    group_by(Estado) %>%
    summarise(Casos = n()) %>%
    ungroup()
  
  
  
  
  
  #Para chart por edad chart por grupo de edad edad------------------------------------------------------------------------------------------------------
  
  
  tableGrupos2 = dfTables %>%
    group_by(Grupo, Sexo) %>%
    summarise(Casos = n()) %>%
    group_by(Sexo) %>%
    mutate(Total = sum(Casos)) %>%
    ungroup() %>%
    mutate(freq = Casos/Total,
           label = paste0(round(freq*100, digits = 0),"%"),
           label = ifelse(Grupo=="0-9", "", label),
           labelM = ifelse(Sexo=="M",label, ""),
           labelF= ifelse(Sexo=="F",label,""),
           freqM = ifelse(Sexo=="M", freq, NA),
           freqF = ifelse(Sexo=="F", freq, NA),
           Sexo = ifelse(Sexo=="F", "Mujeres", "Hombres")
    )%>%
    mutate(Grupo = factor(Grupo),
           Grupo = factor(Grupo, levels = rev(levels(Grupo)))
    ) %>%
    arrange(Grupo) 
  
  
## data para mapa --------------------------------------------------------------------------------------
  casos_municipio = dfTables %>%
    filter(RESULTADO=="Positivo SARS-CoV-2") %>%
    group_by(MUNICIPIO_RES,MUNICIPIO_RES_ID) %>%
    summarise(Casos=n()) %>%
    rename(Municipio = MUNICIPIO_RES)
  
##prepare centroides para mapear
  library(sf)
  municipios_centroids$long  = st_coordinates(municipios_centroids)[,1]
  municipios_centroids$lat  = st_coordinates(municipios_centroids)[,2]
  
  municipios_centroids = data.frame(municipios_centroids) %>%
    select(-geometry)
  
  
  
  #casos_shape = sf::st_sf(merge(x=casos_municipio,y=municipios_centroids, by="MUNICIPIO_RES_ID", type="left"))
  casos_shape = merge(x=casos_municipio,y=municipios_centroids, by="MUNICIPIO_RES_ID", type="left")
  
  

  # casos_shape$long  = st_coordinates(casos_shape)[,1]
  # casos_shape$lat  = st_coordinates(casos_shape)[,2]
  casos_shape$Municipio = as.character(casos_shape$Municipio)
  #casos_shape = data.frame(casos_shape)
  # casos_shape = casos_shape %>%
  #   select(-geometry)
  
##style graphs
  tema_linea <- theme_minimal() +
    theme(text = element_text(family="Poppins", 
                              color = "#333333",
                              size = 14
    ),
    plot.title = element_text(size = 13.5, 
                              face = "bold", 
                              margin = margin(10,0,20,0), 
                              family="Poppins", color = "grey25"),
    panel.grid.major = element_blank(),
    panel.grid.minor = element_blank(),
    axis.line = element_line(colour = "black"),
    axis.text.x= element_text(angle=90, hjust=1),
    axis.text = element_text(family = "Poppins")
    ) 
  
  
  size_point =5
  color_chart = "steelblue"
  size_line = 1
  
  

#------------------------------------------------------------------------------------------------------
 #source("global.R")
  
  Sys.setlocale("LC_TIME", "Spanish")
  
  react = reactiveValues(
    
    #table with casos totales y nuevos casos por dia
    diasData = diasData,
    timeAxis = "yes",
    chart = "acumulados",
    titulo_tiempo="Evolución cumulativa de casos confirmados (escala lineal)",
    tabla="totales"
    
  )
 
#eventos de botones de tabla de casos por entidad federativa -----------------------------------------------------
  
  observeEvent(input$total,{
    
    react$tabla = "totales"
    
  })
  
  
  observeEvent(input$habitantes,{
    
    react$tabla = "habitantes"
    
  })
  
  
  
#eventos de botones de casos sobre tiempo--------------------------------------------------------------------------
  observeEvent(input$nuevos, {

    
    react$chart = "nuevos"
    react$titulo_tiempo= "Número de casos nuevos por día"
    
    
  })
  
  
  observeEvent(input$linear, {
    
    react$diasData =  diasData
    
    react$timeAxis = "yes"
    
    react$chart = "acumulados"
    
    react$titulo_tiempo="Evolución cumulativa de casos confirmados (escala lineal)"
   
    
  })
  
  
  observeEvent(input$log, {
    
    react$diasData = diasData %>%
      mutate(Casos= Casoslog)
    
    react$timeAxis = "no"
    react$chart = "acumulados"
    react$titulo_tiempo="Evolución cumulativa de casos confirmados (escala logarítmica)"
    
    
  })
  
 observeEvent(input$muertes,{
   
   react$chart = "muertes"
   react$titulo_tiempo="Evolución cumulativa de muertes (escala lineal)"
   
 })
  
  
### Outputs ----------------------------------------------------------------------------------------------------------

  output$intro <- renderUI({
    
    HTML(paste('<p class="introtext"> <span class= intro_title> Fuente: </span> datos @ssalud', fuente,"el",  
               fecha , INEGI,' </p>',
               '<p class = introtext> <span class= intro_title> Creador:</span> <a href ="https://www.linkedin.com/in/andr%C3%A9s-arau-017b1127/" target ="_blank">Andrés Arau Pontones </a> (andres.arau@outlook.com)</p>',
               '<p class = "introtext introtextsub"> <span class= intro_title> Colaboradores:</span> Rodrigo Sirvent</p>'))
    
    # 
    # htmlOutput(class="text6","actualizado"),
    #  h6("Datos: Reporte oficial de la Secretaría de Salud"),
    #  h6("Creado por:",tags$a(href="https://www.linkedin.com/in/andr%C3%A9s-arau-017b1127/",
    #                          "Andrés Arau Pontones")),
    #  h6(id = "colaboradres", "Colaboradores: Alejando Morales, Rodrigo Sirvent")),
    
    
  })
  
  
  output$dia <- renderUI({
    
    HTML(paste("<p class = caja_titulo>Día</p>  <hr class= caja_linea> <p class= caja_info>", fecha, "</p>"))
    
    
  })
  
  output$casos <- renderUI({
    
    
    HTML(paste('<p class = "caja_titulo"> Casos</p> <hr class= caja_linea>',
               '<p class = "caja_info casos_info"> ',totalCases,'</p>')
         
    )
    
  })
  
  
  output$fallecidos <- renderUI({
    
    HTML(paste('<p class = "caja_titulo"> Muertes </p> <hr class = caja_linea>', 
    '<p class = caja_info>',totalMuertes, '</p>'))
      
      
    
  })
  


  output$table <- DT::renderDT({
    
#if covidMX doesnt work   
    
    tableEstados = dfTables %>%
      group_by(Estado) %>%
      summarise(Casos = n()) %>%
      ungroup()%>%
      arrange(desc(Casos)) %>%
      select(Estado, Casos) %>%
      mutate(Casoslab = paste(Estado,'<b><font color="#fb4444">', Casos, "</font></b>"))
    
    tableEstados$Estado[tableEstados$Estado=="Michoacán De Ocampo"]="Michoacán"
    tableEstados$Estado[tableEstados$Estado=="Coahuila De Zaragoza"]="Coahuila"
    tableEstados$Estado[tableEstados$Estado=="Veracruz De Ignacio De La Llave"]="Veracruz"
    
    
    poblacion$Estado[poblacion$Estado=="Ciudad de Mexico"] = "Ciudad De México"
    poblacion$Estado[poblacion$Estado=="Mexico"] = "México"
    poblacion$Estado[poblacion$Estado=="Michoacan"] = "Michoacán"
    poblacion$Estado[poblacion$Estado=="Nuevo Leon"] = "Nuevo León"
    poblacion$Estado[poblacion$Estado=="Queretaro"] = "Querétaro"
    poblacion$Estado[poblacion$Estado=="Yucatan"] = "Yucatán"
    poblacion$Estado[poblacion$Estado=="San Luis Potosi"] = "San Luis Potosí"
    
    #join with population data and estimate per 100,00
    tableEstados = plyr::join(tableEstados, poblacion, by="Estado", type="left") %>%
      mutate(Casospop = round((Casos*100000)/Poblacion, digits = 1),
             CasospopLab = paste(Estado,'<b><font color="#fb4444">', Casospop, "</font></b>")
             ) 
    
    
    
      
#if covidMX works
    
    # tableEstados <- dfTables %>%
    #   group_by(Estado, Fecha) %>%
    #   arrange(Estado, Fecha) %>%
    #   summarise(Nuevos = n()) %>%
    #   mutate(Casos = cumsum(Nuevos),
    #          Fechalabel = paste(day(lag(Fecha)), "de", month(lag(Fecha), label = T, abbr = F)),
    #          Casos2 = paste(Estado,'<b><font color="#fb4444">', Casos, '</font></b> <p><span class ="table_note">*'
    #                         , Nuevos, 'más que el', Fechalabel, '</span></p>'),
    #          Casos2 = translate_date(Casos2)) %>%
    #   filter(row_number()==n()) %>%
    #   arrange(desc(Casos)) %>%
    #   ungroup() %>%
    #   select(Casos2)
     
             
    if(react$tabla == "totales"){
      
      tableEstados <- tableEstados %>%
        arrange(desc(Casos)) %>%
        select(Casoslab) %>%
        rename(Casos = Casoslab)
      
      
    } else if(react$tabla == "habitantes"){
      
      tableEstados <- tableEstados %>%
        arrange(desc(Casospop)) %>%
        select(CasospopLab) %>%
        rename(Casps = CasospopLab)
      
      
    }
             
  
    
    
    
    DT::datatable(tableEstados,
    options = list(pageLength = 32,
                   LengthChange = F,
                   columnDefs = list(list(orderable=F, targets=c(0))),
                   dom = 't',
                   scrollY = '600px'
                   
                   ),
      selection = 'none',
      rownames = FALSE,
    escape = F,
    colnames = c("")
  
    )



  })

  output$map <- renderLeaflet({
  #
  #
    labs <- lapply(seq(nrow(casos_shape)), function(i) {
      paste0( '<p> <b>', casos_shape[i, "Municipio"], '</b><p></p>',
              'Casos confirmados : <b><font color="#fb4444">', casos_shape[i, "Casos"], '</b></font>')
      
    })


    map = leaflet(
                  options = leafletOptions(maxZoom = 12,
                                           minZoom = 4
                  )) %>%
      addProviderTiles("CartoDB.Positron", group = "Basemap") %>%
     

      addCircleMarkers(data = casos_shape,  #
                       color = "#CE0A0A",
                       lng = ~long,
                       lat = ~lat,
                       weight = 1.5,
                       stroke = T,
                       fillOpacity = .3,
                       radius =  ~1 *Casos^0.5,
                       label = lapply(labs,HTML),
                       group = "Casos totales"
                       
                       
      ) %>%
      addCircleMarkers( data = casos_shape,  #                       l
                        label = ~Casos,
                        lng = ~long,
                        lat = ~lat,
                        weight = 0,
                        stroke = F,
                        radius = 0,
                        group = "Número de casos totales",
                        labelOptions = labelOptions(noHide = TRUE,  direction = "top",
                                                    offset=c(0,10),textOnly = TRUE,
                                                    textsize = "11px", textcolor="red",
                                                    style = list("color"="#fb4444",
                                                                 "font-family"="Poppins")))  %>%
      
      
      
      #     #max bouds
      setMaxBounds(lng1= -116,lat1=33,
                   lng2= -85,lat2 =  13
      ) %>%
      setView(zoom = 5,
              lat = 20,
              lng = -98) %>%
      #
      #layers control
      addLayersControl(
        overlayGroups = c("Casos totales","Número de casos totales","Basemap"),
        options = layersControlOptions(collapsed = FALSE)
      ) %>%
      #hideGroup("Número de casos totales") %>%
      hideGroup("Número de casos totales") 
    
    
    
    
    
    
    map

  })

  #titulo de la grafica de tiempo
  output$Titulo_tiempo <-renderUI({
    
    h4(react$titulo_tiempo)
    
  })
  
  #grafica de tiempo
  output$chartTiempo <- renderPlot({

      #if boton is acumulados
      if(react$chart == "acumulados"){
      
      chart_Tiempo = ggplot( data =  react$diasData,
              aes(x=Fecha,
                  y = Casos)
              ) +
    geom_point(size = size_point,
               color = color_chart) +
        geom_line(size= size_line,
                  color = color_chart) +
      tema_linea +
        xlab("") +
        ylab("") +
        scale_x_date(date_breaks = "4 days",
                     date_labels =  " %d %b") 
      
      if(react$timeAxis == "yes"){
        
        test = react$diasData[seq(nrow(react$diasData),1,-3),]
        
        chart_Tiempo  +
          geom_label(data = test, 
                     aes(label = Casos))
        
      } else {
        
        chart_Tiempo  
        
        
      }
      
      }
      
      #chart casos nuevos
      else if(react$chart=="nuevos"){
        
        
        ggplot(data = diasData,
               aes(x=Fecha,
                   y = Nuevos)) +
          geom_col(color = "white",
                   fill = "steelblue") +
          geom_text(aes(Fecha, Nuevos+2.5, label = Nuevos),
                    check_overlap = TRUE,
                    size = 3,
                    color = "black") +
          tema_linea +
          xlab("") +
          ylab("") +
          scale_x_date(date_breaks = "1 week",
                       date_labels =  " %d %b"
          ) 
        
      } 
      
      #muertes
      else if(react$chart=="muertes"){
        
        ggplot(data = muertos,
               aes(x=Fecha,
                   y=Defunciones)) +
          
          geom_point(size = size_point,
                     colour = "black") +
          geom_line(size  = size_line,
                    colour = "black")+
          geom_label(aes(label = Defunciones))+
          tema_linea +
          xlab("") +
          ylab("") +
          scale_x_date(date_breaks = "3 days",
                       date_labels =  " %d %b")
        
        
      }
      
      
    
                
                
              
    })
  
  #grafica por grupo de edad
  output$chartEdad<-renderPlot({
    
    dfTables$Grupo <- factor(dfTables$Grupo, levels = sort(unique(dfTables$Grupo)))
    
    tableGrupo = dfTables %>%
      group_by(Grupo, Sexo) %>%
      summarise(Casos = n()) %>%
      ungroup() %>%
      group_by(Sexo) %>%
      mutate(Casos_perc= round(Casos*100/sum(Casos), digits = 0),
             Casos_label = if_else(Casos_perc>5,paste0(Casos_perc,"%"),""),
             Casos_perc = if_else(Sexo=="M", Casos_perc*-1, Casos_perc)) %>%
      ungroup() %>%
      mutate(Sexo = if_else(Sexo=="M", "Hombres", "Mujeres"))
    
    
    dataM <- tableGrupo %>%
      filter(Sexo=="Hombres")
    
    dataF <- tableGrupo %>%
      filter(Sexo=="Mujeres")
    
   
    #graph
    chartGrupo = ggplot(data =tableGrupo,
           aes(x=Grupo,
               y=Casos_perc,
               fill=Sexo),
           xlab="Grupo de Edad",
           lineend="round") +
      
      #barra de hombres
      geom_bar(data= dataM,
               stat="identity",
               size=1,
               alpha=.7
               
      )+
      
      geom_text(data= dataM,
                aes(label= Casos_label),
                nudge_y =2,
                size=3.5,
                color="white",
                show.legend = F) +
      
      #barra de mujeres
      geom_bar(data= dataF,
               stat = "identity",
               alpha=.7,
               show.legend = F) +
      
      geom_text(data= dataF,
                aes(label= Casos_label),
                nudge_y =-2,
                size=3.5,
                color="white",
                show.legend = F) +
      
      #breaks y lables de eje
      scale_y_continuous(breaks = seq(-100, 100, 10),
                         labels = paste0(as.character(c(seq(100, 0, -10), seq(10, 100, 10))), "%")) +
      #tema
      coord_flip() +
      theme_bw() +
      scale_fill_manual(values = adjustcolor(c(colorH, colorM), alpha.f =.6)) +
      xlab("Grupo de edad") +
      ylab("% de casos confirmados") +
      
      theme(legend.position=c(.55,.95),
            legend.direction = "horizontal",
            legend.title = element_blank()
            )
    
    chartGrupo
    
    
  })
  
  
#end server    
}
    
    
    
  
  
  
  