#!/bin/bash

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Archivo de log
LOG_FILE="nextcloud_install.log"

# Función para logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Función para mostrar banner
banner() {
    clear
    echo
    echo -e "${BLUE}  _______                   __         .__                   .___       ${NC}"
    echo -e "${BLUE}  \\      \\   ____ ___  ____/  |_  ____ |  |   ____  __ __  __| _/       ${NC}"
    echo -e "${BLUE}  /   |   \\_/ __ \\\\  \\/  /\\   __\\/ ___\\|  |  /  _ \\|  |  \\/ __ |        ${NC}"
    echo -e "${BLUE} /    |    \\  ___/ >    <  |  | \\  \\___|  |_(  <_> )  |  / /_/ |        ${NC}"
    echo -e "${BLUE} \\____|__  /\\___  >__/\\_ \\ |__|  \\___  >____/\\____/|____/\\____ |        ${NC}"
    echo -e "${BLUE}         \\/     \\/      \\/           \\/                       \\/        ${NC}"
    echo
}

# Manejador de interrupción
int_handler() {
    clear
    echo
    echo -e "${BOLD}[+] Saliendo del instalador...${NC}"
    echo
    log "Instalación interrumpida por el usuario"
    exit 0
}

trap 'int_handler' INT

# Verificar si se ejecuta como root
verificar_root() {
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}[!] Este script debe ejecutarse como root (usando sudo)${NC}"
        log "ERROR: Script ejecutado sin privilegios de root"
        exit 1
    fi
}

# Función para pausar
pausar() {
    echo
    read -p "$(echo -e ${BOLD}[+] Presiona ENTER para continuar...${NC})"
}

# Verificar si un comando existe
comando_existe() {
    command -v "$1" >/dev/null 2>&1
}

# Verificar estado del servicio
verificar_servicio() {
    local servicio=$1
    if systemctl is-active --quiet "$servicio"; then
        echo -e "${GREEN}[✓]${NC} $servicio está activo"
        return 0
    else
        echo -e "${RED}[✗]${NC} $servicio no está activo"
        return 1
    fi
}

# Función para instalar requisitos
instalar_requisitos() {
    echo
    echo -e "${BOLD}=== INSTALACIÓN DE REQUISITOS ===${NC}"
    log "Iniciando instalación de requisitos"
    
    # Verificar conexión a internet
    echo -e "\n${YELLOW}[*]${NC} Verificando conexión a internet..."
    if ! ping -c 1 8.8.8.8 &> /dev/null; then
        echo -e "${RED}[!]${NC} No hay conexión a internet"
        log "ERROR: Sin conexión a internet"
        pausar
        return 1
    fi
    echo -e "${GREEN}[✓]${NC} Conexión a internet disponible"
    
    # Actualizar sistema
    echo -e "\n${YELLOW}[*]${NC} Actualizando lista de paquetes..."
    if apt update >> "$LOG_FILE" 2>&1; then
        echo -e "${GREEN}[✓]${NC} Lista de paquetes actualizada"
        log "Lista de paquetes actualizada exitosamente"
    else
        echo -e "${RED}[!]${NC} Error al actualizar paquetes"
        log "ERROR: Fallo al actualizar lista de paquetes"
        pausar
        return 1
    fi
    
    echo -e "\n${YELLOW}[*]${NC} Actualizando sistema (esto puede tardar)..."
    if apt upgrade -y >> "$LOG_FILE" 2>&1; then
        echo -e "${GREEN}[✓]${NC} Sistema actualizado"
        log "Sistema actualizado exitosamente"
    else
        echo -e "${YELLOW}[!]${NC} Hubo problemas al actualizar el sistema"
        log "WARNING: Problemas al actualizar sistema"
    fi
    
    # Instalar software-properties-common si no está
    if ! comando_existe add-apt-repository; then
        echo -e "\n${YELLOW}[*]${NC} Instalando software-properties-common..."
        apt install -y software-properties-common >> "$LOG_FILE" 2>&1
    fi
    
    # Agregar repositorio PHP
    echo -e "\n${YELLOW}[*]${NC} Agregando repositorio PHP..."
    if add-apt-repository ppa:ondrej/php -y >> "$LOG_FILE" 2>&1; then
        echo -e "${GREEN}[✓]${NC} Repositorio PHP agregado"
        log "Repositorio PHP agregado"
        apt update >> "$LOG_FILE" 2>&1
    else
        echo -e "${RED}[!]${NC} Error al agregar repositorio PHP"
        log "ERROR: Fallo al agregar repositorio PHP"
    fi
    
    # Instalar PHP y extensiones
    echo -e "\n${YELLOW}[*]${NC} Instalando PHP 8.1 y extensiones..."
    local php_packages=(
        "php8.1"
        "php8.1-common"
        "php8.1-mysql"
        "php8.1-pgsql"
        "php8.1-xml"
        "php8.1-mbstring"
        "php8.1-curl"
        "php8.1-gd"
        "php8.1-zip"
        "php8.1-intl"
        "php8.1-bcmath"
        "php8.1-gmp"
        "php8.1-imagick"
        "php8.1-apcu"
        "php8.1-redis"
        "php8.1-fpm"
    )
    
    if apt-get install -y "${php_packages[@]}" >> "$LOG_FILE" 2>&1; then
        echo -e "${GREEN}[✓]${NC} PHP 8.1 y extensiones instaladas"
        log "PHP 8.1 instalado exitosamente"
    else
        echo -e "${RED}[!]${NC} Error al instalar PHP"
        log "ERROR: Fallo al instalar PHP"
        pausar
        return 1
    fi
    
    # Verificar versión de PHP
    php_version=$(php -v | head -n 1)
    echo -e "${GREEN}[✓]${NC} $php_version"
    
    # Instalar MySQL
    echo -e "\n${YELLOW}[*]${NC} Instalando MySQL Server..."
    if apt install -y mysql-server >> "$LOG_FILE" 2>&1; then
        echo -e "${GREEN}[✓]${NC} MySQL Server instalado"
        log "MySQL instalado exitosamente"
        
        # Iniciar y habilitar MySQL
        systemctl start mysql
        systemctl enable mysql >> "$LOG_FILE" 2>&1
        
        verificar_servicio mysql
    else
        echo -e "${RED}[!]${NC} Error al instalar MySQL"
        log "ERROR: Fallo al instalar MySQL"
        pausar
        return 1
    fi
    
    # Instalar Apache2 (necesario para Nextcloud)
    echo -e "\n${YELLOW}[*]${NC} Instalando Apache2..."
    if apt install -y apache2 libapache2-mod-php8.1 >> "$LOG_FILE" 2>&1; then
        echo -e "${GREEN}[✓]${NC} Apache2 instalado"
        log "Apache2 instalado exitosamente"
        
        # Habilitar módulos necesarios
        a2enmod rewrite headers env dir mime ssl >> "$LOG_FILE" 2>&1
        
        systemctl start apache2
        systemctl enable apache2 >> "$LOG_FILE" 2>&1
        
        verificar_servicio apache2
    else
        echo -e "${RED}[!]${NC} Error al instalar Apache2"
        log "ERROR: Fallo al instalar Apache2"
    fi
    
    # Instalar utilidades adicionales
    echo -e "\n${YELLOW}[*]${NC} Instalando utilidades adicionales..."
    apt install -y unzip wget curl >> "$LOG_FILE" 2>&1
    
    # Resumen de instalación
    echo
    echo -e "${BOLD}=== RESUMEN DE INSTALACIÓN ===${NC}"
    echo -e "${GREEN}[✓]${NC} Sistema actualizado"
    echo -e "${GREEN}[✓]${NC} PHP 8.1 instalado"
    echo -e "${GREEN}[✓]${NC} MySQL instalado"
    echo -e "${GREEN}[✓]${NC} Apache2 instalado"
    echo -e "${GREEN}[✓]${NC} Extensiones PHP instaladas"
    
    log "Instalación de requisitos completada"
    
    echo
    echo -e "${YELLOW}[!]${NC} IMPORTANTE: Ejecuta 'mysql_secure_installation' para securizar MySQL"
    echo -e "${YELLOW}[!]${NC} Logs guardados en: $LOG_FILE"
    
    pausar
}

# Función para configurar Nextcloud
configurar_nextcloud() {
    echo
    echo -e "${BOLD}=== CONFIGURACIÓN DE NEXTCLOUD ===${NC}"
    log "Iniciando configuración de Nextcloud"
    
    if [ -f "Scripts/configuracion.sh" ]; then
        source Scripts/configuracion.sh
        log "Script de configuración ejecutado"
    else
        echo -e "${RED}[!]${NC} Error: No se encuentra 'Scripts/configuracion.sh'"
        echo -e "${YELLOW}[!]${NC} Asegúrate de que el archivo existe en la ruta correcta"
        log "ERROR: Script configuracion.sh no encontrado"
    fi
    
    pausar
}

# Función para configurar directorios
configurar_directorios() {
    echo
    echo -e "${BOLD}=== CONFIGURACIÓN DE DIRECTORIOS ===${NC}"
    log "Iniciando configuración de directorios"
    
    if [ -f "Scripts/directorios.sh" ]; then
        source Scripts/directorios.sh
        log "Script de directorios ejecutado"
    else
        echo -e "${RED}[!]${NC} Error: No se encuentra 'Scripts/directorios.sh'"
        echo -e "${YELLOW}[!]${NC} Asegúrate de que el archivo existe en la ruta correcta"
        log "ERROR: Script directorios.sh no encontrado"
    fi
    
    pausar
}

# Función para verificar estado del sistema
verificar_estado() {
    echo
    echo -e "${BOLD}=== ESTADO DEL SISTEMA ===${NC}"
    
    echo -e "\n${BOLD}Servicios:${NC}"
    verificar_servicio apache2
    verificar_servicio mysql
    
    echo -e "\n${BOLD}Versiones instaladas:${NC}"
    if comando_existe php; then
        php_ver=$(php -v | head -n 1 | cut -d' ' -f2)
        echo -e "${GREEN}[✓]${NC} PHP: $php_ver"
    else
        echo -e "${RED}[✗]${NC} PHP no instalado"
    fi
    
    if comando_existe mysql; then
        mysql_ver=$(mysql --version | cut -d' ' -f6)
        echo -e "${GREEN}[✓]${NC} MySQL: $mysql_ver"
    else
        echo -e "${RED}[✗]${NC} MySQL no instalado"
    fi
    
    if comando_existe apache2; then
        apache_ver=$(apache2 -v | head -n 1 | cut -d' ' -f3)
        echo -e "${GREEN}[✓]${NC} Apache: $apache_ver"
    else
        echo -e "${RED}[✗]${NC} Apache no instalado"
    fi
    
    echo -e "\n${BOLD}Espacio en disco:${NC}"
    df -h / | tail -n 1 | awk '{print "Usado: " $3 " / " $2 " (" $5 ")"}'
    
    echo -e "\n${BOLD}Memoria:${NC}"
    free -h | grep "Mem:" | awk '{print "Usada: " $3 " / " $2}'
    
    pausar
}

# Menú principal
menu_principal() {
    while true; do
        banner
        echo -e "${BOLD}=== INSTALADOR DE NEXTCLOUD ===${NC}"
        echo
        echo -e "   ${BOLD}[1]${NC} Instalar Requisitos"
        echo -e "   ${BOLD}[2]${NC} Configurar Nextcloud"
        echo -e "   ${BOLD}[3]${NC} Configurar seguridad de Directorios"
        echo -e "   ${BOLD}[4]${NC} Verificar estado del sistema"
        echo -e "   ${BOLD}[5]${NC} Ver logs de instalación"
        echo -e "   ${BOLD}[6]${NC} Salir"
        echo
        
        read -p "$(echo -e ${BOLD}[+] Seleccione una opción: ${NC})" opcion
        
        case $opcion in
            1)
                instalar_requisitos
                ;;
            2)
                configurar_nextcloud
                ;;
            3)
                configurar_directorios
                ;;
            4)
                verificar_estado
                ;;
            5)
                if [ -f "$LOG_FILE" ]; then
                    echo
                    echo -e "${BOLD}=== ÚLTIMAS 30 LÍNEAS DEL LOG ===${NC}"
                    tail -n 30 "$LOG_FILE"
                    pausar
                else
                    echo -e "${YELLOW}[!]${NC} No hay archivo de log disponible"
                    pausar
                fi
                ;;
            6)
                clear
                echo
                echo -e "${BOLD}[+] ¡Gracias por usar el instalador de Nextcloud!${NC}"
                echo
                log "Instalador finalizado"
                exit 0
                ;;
            *)
                echo -e "${RED}[!]${NC} Opción inválida"
                sleep 1
                ;;
        esac
    done
}

# Función principal
main() {
    verificar_root
    
    # Crear directorio Scripts si no existe
    mkdir -p Scripts
    
    log "===== INICIO DEL INSTALADOR DE NEXTCLOUD ====="
    menu_principal
}

# Ejecutar
main