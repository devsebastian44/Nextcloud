#!/bin/bash
# ============================================================================
# configuracion.sh - Script de configuración de Nextcloud (MEJORADO)
# ============================================================================

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
BOLD='\033[1m'

# Variables
LOG_FILE="nextcloud_config.log"
NEXTCLOUD_DIR="/var/www/html/nextcloud"
NEXTCLOUD_VERSION="latest"

# Función de logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Función para validar contraseña
validar_contrasena() {
    local pass=$1
    local len=${#pass}
    
    if [ $len -lt 8 ]; then
        echo -e "${RED}[!] La contraseña debe tener al menos 8 caracteres${NC}"
        return 1
    fi
    
    if ! [[ "$pass" =~ [A-Z] ]]; then
        echo -e "${YELLOW}[!] Advertencia: Se recomienda usar mayúsculas${NC}"
    fi
    
    if ! [[ "$pass" =~ [0-9] ]]; then
        echo -e "${YELLOW}[!] Advertencia: Se recomienda usar números${NC}"
    fi
    
    return 0
}

# Función para configurar MySQL
configurar_mysql() {
    echo
    echo -e "${BOLD}=== CONFIGURACIÓN DE MYSQL ===${NC}"
    log "Iniciando configuración de MySQL"
    
    # Solicitar contraseña con confirmación
    while true; do
        read -sp "$(echo -e ${BOLD}[+] Contraseña para MySQL root: ${NC})" contrasena_root
        echo
        read -sp "$(echo -e ${BOLD}[+] Confirmar contraseña: ${NC})" contrasena_root_confirm
        echo
        
        if [ "$contrasena_root" != "$contrasena_root_confirm" ]; then
            echo -e "${RED}[!] Las contraseñas no coinciden. Intenta de nuevo.${NC}"
            continue
        fi
        
        if ! validar_contrasena "$contrasena_root"; then
            read -p "$(echo -e ${YELLOW}[?] ¿Continuar con esta contraseña? [s/N]: ${NC})" continuar
            if [[ ! "$continuar" =~ ^[Ss]$ ]]; then
                continue
            fi
        fi
        break
    done
    
    # Cambiar contraseña de root en MySQL
    echo -e "\n${YELLOW}[*]${NC} Configurando contraseña de root en MySQL..."
    if mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY '$contrasena_root';" 2>> "$LOG_FILE"; then
        echo -e "${GREEN}[✓]${NC} Contraseña de root configurada"
        log "Contraseña de root MySQL configurada"
    else
        echo -e "${RED}[!]${NC} Error al configurar contraseña de root"
        log "ERROR: Fallo al configurar contraseña root"
        return 1
    fi
    
    # Solicitar contraseña para usuario nextcloud
    echo
    while true; do
        read -sp "$(echo -e ${BOLD}[+] Contraseña para usuario 'nextcloud' en MySQL: ${NC})" contrasena_nextcloud
        echo
        read -sp "$(echo -e ${BOLD}[+] Confirmar contraseña: ${NC})" contrasena_nextcloud_confirm
        echo
        
        if [ "$contrasena_nextcloud" != "$contrasena_nextcloud_confirm" ]; then
            echo -e "${RED}[!] Las contraseñas no coinciden. Intenta de nuevo.${NC}"
            continue
        fi
        
        if ! validar_contrasena "$contrasena_nextcloud"; then
            read -p "$(echo -e ${YELLOW}[?] ¿Continuar con esta contraseña? [s/N]: ${NC})" continuar
            if [[ ! "$continuar" =~ ^[Ss]$ ]]; then
                continue
            fi
        fi
        break
    done
    
    # Crear usuario de Nextcloud
    echo -e "\n${YELLOW}[*]${NC} Creando usuario 'nextcloud' en MySQL..."
    if mysql -u root -p"$contrasena_root" -e "CREATE USER IF NOT EXISTS 'nextcloud'@'localhost' IDENTIFIED BY '$contrasena_nextcloud';" 2>> "$LOG_FILE"; then
        echo -e "${GREEN}[✓]${NC} Usuario 'nextcloud' creado"
        log "Usuario nextcloud creado en MySQL"
    else
        echo -e "${RED}[!]${NC} Error al crear usuario nextcloud"
        log "ERROR: Fallo al crear usuario nextcloud"
        return 1
    fi
    
    # Crear base de datos
    echo -e "${YELLOW}[*]${NC} Creando base de datos 'nextcloud'..."
    if mysql -u root -p"$contrasena_root" -e "CREATE DATABASE IF NOT EXISTS nextcloud CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;" 2>> "$LOG_FILE"; then
        echo -e "${GREEN}[✓]${NC} Base de datos 'nextcloud' creada"
        log "Base de datos nextcloud creada"
    else
        echo -e "${RED}[!]${NC} Error al crear base de datos"
        log "ERROR: Fallo al crear base de datos"
        return 1
    fi
    
    # Otorgar privilegios
    echo -e "${YELLOW}[*]${NC} Otorgando privilegios..."
    if mysql -u root -p"$contrasena_root" -e "GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud'@'localhost';" 2>> "$LOG_FILE" && \
       mysql -u root -p"$contrasena_root" -e "FLUSH PRIVILEGES;" 2>> "$LOG_FILE"; then
        echo -e "${GREEN}[✓]${NC} Privilegios otorgados"
        log "Privilegios otorgados al usuario nextcloud"
    else
        echo -e "${RED}[!]${NC} Error al otorgar privilegios"
        log "ERROR: Fallo al otorgar privilegios"
        return 1
    fi
    
    # Guardar credenciales en archivo seguro
    local cred_file="nextcloud_credentials.txt"
    echo "=== CREDENCIALES DE NEXTCLOUD ===" > "$cred_file"
    echo "Fecha: $(date)" >> "$cred_file"
    echo "" >> "$cred_file"
    echo "Base de datos: nextcloud" >> "$cred_file"
    echo "Usuario DB: nextcloud" >> "$cred_file"
    echo "Contraseña DB: $contrasena_nextcloud" >> "$cred_file"
    echo "" >> "$cred_file"
    echo "IMPORTANTE: Guarda este archivo en un lugar seguro y elimínalo del servidor" >> "$cred_file"
    chmod 600 "$cred_file"
    
    echo -e "\n${GREEN}[✓]${NC} Credenciales guardadas en: $cred_file"
    echo -e "${YELLOW}[!]${NC} IMPORTANTE: Guarda este archivo y elimínalo del servidor"
    
    return 0
}

# Función para configurar Apache
configurar_apache() {
    echo
    echo -e "${BOLD}=== CONFIGURACIÓN DE APACHE ===${NC}"
    log "Iniciando configuración de Apache"
    
    # Verificar si Apache está instalado
    if ! command -v apache2 >/dev/null 2>&1; then
        echo -e "${YELLOW}[*]${NC} Apache no está instalado. Instalando..."
        apt install -y apache2 libapache2-mod-php >> "$LOG_FILE" 2>&1
    fi
    
    # Crear archivo de configuración de Nextcloud
    echo -e "${YELLOW}[*]${NC} Creando configuración de VirtualHost..."
    
    cat > /etc/apache2/sites-available/nextcloud.conf << 'EOF'
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot /var/www/html/nextcloud

    ErrorLog ${APACHE_LOG_DIR}/nextcloud_error.log
    CustomLog ${APACHE_LOG_DIR}/nextcloud_access.log combined

    <Directory /var/www/html/nextcloud>
        Options +FollowSymlinks
        AllowOverride All
        Require all granted
        
        <IfModule mod_dav.c>
            Dav off
        </IfModule>
        
        SetEnv HOME /var/www/html/nextcloud
        SetEnv HTTP_HOME /var/www/html/nextcloud
    </Directory>
</VirtualHost>
EOF
    
    if [ -f /etc/apache2/sites-available/nextcloud.conf ]; then
        echo -e "${GREEN}[✓]${NC} Archivo de configuración creado"
        log "VirtualHost de Nextcloud creado"
    else
        echo -e "${RED}[!]${NC} Error al crear configuración"
        log "ERROR: Fallo al crear VirtualHost"
        return 1
    fi
    
    # Deshabilitar sitio por defecto
    echo -e "${YELLOW}[*]${NC} Deshabilitando sitio por defecto..."
    a2dissite 000-default.conf >> "$LOG_FILE" 2>&1
    
    # Habilitar módulos necesarios
    echo -e "${YELLOW}[*]${NC} Habilitando módulos de Apache..."
    a2enmod rewrite headers env dir mime ssl >> "$LOG_FILE" 2>&1
    echo -e "${GREEN}[✓]${NC} Módulos habilitados"
    log "Módulos de Apache habilitados"
    
    # Habilitar sitio de Nextcloud
    echo -e "${YELLOW}[*]${NC} Habilitando sitio de Nextcloud..."
    a2ensite nextcloud.conf >> "$LOG_FILE" 2>&1
    echo -e "${GREEN}[✓]${NC} Sitio habilitado"
    
    # Reiniciar Apache
    echo -e "${YELLOW}[*]${NC} Reiniciando Apache..."
    if systemctl restart apache2; then
        echo -e "${GREEN}[✓]${NC} Apache reiniciado correctamente"
        log "Apache reiniciado"
    else
        echo -e "${RED}[!]${NC} Error al reiniciar Apache"
        log "ERROR: Fallo al reiniciar Apache"
        return 1
    fi
    
    return 0
}

# Función para descargar e instalar Nextcloud
instalar_nextcloud() {
    echo
    echo -e "${BOLD}=== INSTALACIÓN DE NEXTCLOUD ===${NC}"
    log "Iniciando instalación de Nextcloud"
    
    # Crear directorio si no existe
    if [ ! -d "$NEXTCLOUD_DIR" ]; then
        echo -e "${YELLOW}[*]${NC} Creando directorio de Nextcloud..."
        mkdir -p "$NEXTCLOUD_DIR"
    fi
    
    # Establecer permisos
    echo -e "${YELLOW}[*]${NC} Configurando permisos..."
    chmod 750 "$NEXTCLOUD_DIR"
    chown -R www-data:www-data "$NEXTCLOUD_DIR"
    echo -e "${GREEN}[✓]${NC} Permisos configurados"
    log "Permisos del directorio Nextcloud configurados"
    
    # Descargar instalador de Nextcloud
    echo -e "${YELLOW}[*]${NC} Descargando instalador de Nextcloud..."
    cd "$NEXTCLOUD_DIR" || return 1
    
    if wget -q --show-progress https://download.nextcloud.com/server/installer/setup-nextcloud.php; then
        echo -e "${GREEN}[✓]${NC} Instalador descargado"
        log "Instalador de Nextcloud descargado"
    else
        echo -e "${RED}[!]${NC} Error al descargar instalador"
        log "ERROR: Fallo al descargar instalador de Nextcloud"
        return 1
    fi
    
    # Establecer permisos del instalador
    chown www-data:www-data setup-nextcloud.php
    chmod 644 setup-nextcloud.php
    
    echo -e "${GREEN}[✓]${NC} Instalador configurado correctamente"
    
    return 0
}

# Función para mostrar información final
mostrar_info_final() {
    local server_ip=$(hostname -I | awk '{print $1}')
    
    echo
    echo -e "${BOLD}========================================${NC}"
    echo -e "${GREEN}  CONFIGURACIÓN COMPLETADA${NC}"
    echo -e "${BOLD}========================================${NC}"
    echo
    echo -e "${BOLD}Próximos pasos:${NC}"
    echo -e "1. Abre tu navegador y ve a: ${BOLD}http://$server_ip${NC}"
    echo -e "2. Completa la instalación web de Nextcloud"
    echo -e "3. Usa las credenciales guardadas en: ${BOLD}nextcloud_credentials.txt${NC}"
    echo
    echo -e "${BOLD}Información de la base de datos:${NC}"
    echo -e "   Base de datos: ${BOLD}nextcloud${NC}"
    echo -e "   Usuario: ${BOLD}nextcloud${NC}"
    echo -e "   Host: ${BOLD}localhost${NC}"
    echo
    echo -e "${YELLOW}[!]${NC} IMPORTANTE:"
    echo -e "   - Guarda el archivo de credenciales en un lugar seguro"
    echo -e "   - Considera configurar SSL/HTTPS para producción"
    echo -e "   - Revisa los logs en: $LOG_FILE"
    echo
}

# SCRIPT PRINCIPAL
main() {
    clear
    echo -e "${BOLD}=== CONFIGURACIÓN DE NEXTCLOUD ===${NC}"
    log "===== INICIO DE CONFIGURACIÓN DE NEXTCLOUD ====="
    
    # Verificar que se ejecuta como root
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}[!] Este script debe ejecutarse como root${NC}"
        exit 1
    fi
    
    # Ejecutar configuraciones
    if configurar_mysql && configurar_apache && instalar_nextcloud; then
        mostrar_info_final
        log "Configuración completada exitosamente"
        return 0
    else
        echo -e "\n${RED}[!] Hubo errores durante la configuración${NC}"
        echo -e "${YELLOW}[!]${NC} Revisa los logs en: $LOG_FILE"
        log "ERROR: Configuración finalizada con errores"
        return 1
    fi
}