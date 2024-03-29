
rm(list = ls()) # Para limpiar el entorno
# Paquetes requeridos
if(!require('pacman')) install.packages('pacman') # Para manejo de paquetes 
pacman::p_load( # Instalación y carga de paquetes
               tidyverse, # Para manipulación de datos y otras muchas funciones
               zip, # Para extracción de archivos zip
               readxl, # Para lectura de archivs excel
               htmltools, # Para agregar características html en el caso de mapas interactivos
               htmlwidgets, # Para guardar nuestro mapa como html
               rgdal, rgeos, # Para el manejo de archivos geográficos
               rcartocolor, # Paquete de paleta de colores
               leaflet) # Paquete para crear mapas interactivos

# Crear directorios
dir.create("./01Datos")
dir.create("./02Shapes")
# Descarga del Marco Geoestadístico de Sonora

shapes.url <- "https://www.inegi.org.mx/contenidos/productos/prod_serv/contenidos/espanol/bvinegi/productos/geografia/marcogeo/889463807469/26_sonora.zip"
shapes.archivo <- "C:/Users/luism/OneDrive/R/Marginación/02Shapes/26_sonora.zip"

if(!file.exists(shapes.archivo)){
  download.file(shapes.url, destfile = shapes.archivo)  
  unzip(shapes.archivo, exdir = "./02Shapes")
}

# Descarga del Índice de Marginación Urbana 2020 de CONAPO

conapo.url <- "http://www.conapo.gob.mx/work/models/CONAPO/Marginacion/Datos_Abiertos/IMU_2020.zip"
conapo.archivo <- "C:/Users/luism/OneDrive/R/Marginación/01Datos/IMU_2020.zip"

if(!file.exists(conapo.archivo)){
  download.file(conapo.url, destfile = conapo.archivo)  
  unzip(conapo.archivo, exdir = "./01Datos")
  
}

# Carga de datos

marginacion_urbana <- read_excel("01Datos/IMU_2020.xls", 
                        sheet = "IMU_2020") 
Diccionario <- read_excel("01Datos/IMU_2020.xls", 
                                 sheet = "Diccionario", range = "a3:b23") # Cargamos diccionario
## Estructura
str(marginacion_urbana)
view(Diccionario)
## Valores únicos

unique(marginacion_urbana$NOM_ENT)
unique(marginacion_urbana$GM_2020)

## Niveles
levels=c("Muy bajo", "Bajo", "Medio", "Alto", "Muy alto") # Definimos los niveles del GM

# Se filtran las AGEBS Urbanas de Sonora, se ordenan los niveles del GM
marginacion_urbana_sonora <- marginacion_urbana %>% 
  filter(NOM_ENT=="Sonora") %>% mutate(GM_2020=factor(GM_2020,levels))
marginacion_urbana_sonora %>% group_by(GM_2020) %>% summarise(n())


# Se carga el shapefile

capa_ageb <- readOGR("02Shapes/conjunto_de_datos", layer="26a",  encoding = "UTF-8", use_iconv=TRUE)
capa_ageb <- spTransform(capa_ageb, 
               CRS("+proj=longlat +datum=WGS84 +ellps=WGS84 +towgs84=0,0,0"))

capa_mun <- readOGR("02Shapes/conjunto_de_datos", layer="26mun",  encoding = "UTF-8", use_iconv=TRUE)
capa_mun<- spTransform(capa_mun, 
                        CRS("+proj=longlat +datum=WGS84 +ellps=WGS84 +towgs84=0,0,0"))

str(capa_ageb@data)
view(capa_ageb@data)

# Se carga el shapefile de municipal


capa_mun <- readOGR("02Shapes/conjunto_de_datos", layer="26mun",  encoding = "UTF-8", use_iconv=TRUE)
capa_mun<- spTransform(capa_mun, 
                       CRS("+proj=longlat +datum=WGS84 +ellps=WGS84 +towgs84=0,0,0"))
str(capa_mun@data)



## Agregamos la información del GM a la capa geográfica

marginacion_urbana_sonora <- rename(marginacion_urbana_sonora, CVEGEO=CVE_AGEB) # Renombramos la variable

capa_ageb <- capa_ageb %>% merge(marginacion_urbana_sonora) # Unimos ambas capas 

capa_ageb <- capa_ageb[!is.na(capa_ageb@data$GM_2020),] # filtramos aquellas AGEBS que no tienen datos (sólo tenemos GDM para las urbanas y cabeceras municipales)
str(capa_ageb@data)
view(capa_ageb@data)

# Generamos la paleta de colores

Colores <- carto_pal(5, "TealRose")

margpal <-  colorFactor(Colores, levels=c("Muy bajo", "Bajo", "Medio", "Alto", "Muy alto"), na.color =alpha("#e8e6e6", 0))

# Preparamos el texto para popup 
popup <- paste0(
  "<b>", "Municipio: ", "</b>", as.character(capa_ageb$NOM_MUN),"<br>",  
  "<b>", "Localidad: ", "</b>", as.character(capa_ageb$NOM_LOC),"<br>",
  "<b>", "AGEB: ", "</b>", as.character(capa_ageb$CVE_AGEB),"<br>",
  "<b>", "Grado de marginación: ", "</b>",   as.character(capa_ageb$GM_2020),      "<br>",
  "<b>", "Población total: ", "</b>",   prettyNum(as.numeric(capa_ageb$POB_TOTAL), big.mark=",", preserve.width="none"), "<br>",
  "<b>", "6 a 14 años que no asiste a la escuela: ", "</b>", round(capa_ageb$P6A14NAE,1),"%", "<br>",
  "<b>", "15 años o más sin educación básica:   ", "</b>", round(capa_ageb$SBASC,1),"%","<br>",
  "<b>", "Sin servicios de salud: ", "</b>", round(capa_ageb$PSDSS,1),  "%","<br>",
  "<b>", "Sin drenaje ni excusado: ", "</b>", round(capa_ageb$OVSDE,1), "%","<br>",
  "<b>", "Sin energía eléctrica: ", "</b>", round(capa_ageb$OVSEE,1),  "%", "<br>",
  "<b>", "Sin agua entubada: ", "</b>", round(capa_ageb$OVSAE,1), "%","<br>",
  "<b>", "Con piso de tierra: ", "</b>", round(capa_ageb$OVPT,1), "%","<br>",
  "<b>", "Con hacinamiento: ", "</b>", round(capa_ageb$OVHAC,1),  "%","<br>",
  "<b>", "Sin refrigerador: ", "</b>", round(capa_ageb$OVSREF,1), "%","<br>",
  "<b>", "Sin internet: ", "</b>", round(capa_ageb$OVSINT,1), "%", "<br>",
  "<b>", "Sin celular: ", "</b>", round(capa_ageb$OVSCEL,1), "%", "<br>")  %>% lapply(htmltools::HTML) # Se aplica formato HTML

mapaagebmarg <- leaflet(capa_ageb) %>% 
  addProviderTiles(providers$CartoDB.Voyager) %>% # Elegimos fondo del mapa
    addPolygons(data= capa_ageb, #Carga de capa
              stroke= TRUE, # Si se dibujan los bordes o no
              weight=0.5,  # Peso de la línea de los bordes                 
              opacity=1, #Opacidad de la línea de borde
              color= "white", # Color de la línea de borde
              fillColor = ~margpal(capa_ageb$GM_2020), # Color de relleno de los polígonos, se hace uso de la paleta de colores
              fillOpacity = 0.6, # Opacidad del relleno
              smoothFactor = 1, # Suaviza los bordes del polígono para un mejor rendimiento 
              highlightOptions = highlightOptions(color = "black", # Sobresaltar los polígonos donde pasa el mouse y las características
                                                  weight = 1.2,
                                                  bringToFront = TRUE),
              popup = popup, # Popup (en este caso es al dar click, para hover usamos label)
              popupOptions = labelOptions(noHide = F, direction = "auto",  closeOnClick = TRUE, #opciones del popup
                                          style = list( # características del popup (css)
                                            "color" = "black",
                                            "font-family" = "Arial",
                                            "font-style" = "regular",
                                            "box-shadow" = "2px 2px rgba(0,0,0,0.25)",
                                            "font-size" = "8px",
                                            "border-color" = "rgba(0,0,0,0.5)"
                                          )),
              group= "Urbano") %>% # Nombre de la capa para referencia en menú
  addPolygons(data= capa_mun, # Se carga capa de referencia municipal
              stroke= TRUE,
              weight=0.2,                   
              opacity=1,
              fillColor = "transparent", #En este caso es la base de la división municipal por ello es transparente
              color= "black",
              fillOpacity = 0,
              smoothFactor = 1,
              group= "Municipal") %>% # A manera de ejemplo
  addLegend(position = "bottomleft",  pal = margpal, values = ~capa_ageb$GM_2020, opacity=1, group= "GRADO DE MARGINACIÓN", # Leyenda de referencia
            title = "GRADO DE MARGINACIÓN<br>CONAPO,2020<br>(click en el área de interés para mayor información)", na.label = "No aplica") %>% 
  addLayersControl( 
    baseGroups = c("Municipal", "Urbano"), 
    options = layersControlOptions(collapsed = FALSE, position = "bottomleft"))
 

mapaagebmarg

saveWidget(mapaagebmarg,"marginación urbana.html", title= "Sonora: Marginación Urbana", selfcontained = T, libdir = "lib")


