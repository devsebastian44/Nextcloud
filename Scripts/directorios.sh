# ============================================================================
# directorios.sh - Script de seguridad de directorios (MEJORADO)
# ============================================================================

#!/bin/bash

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
BOLD='\033[1m'

# Variables
LOG_FILE="nextcloud_security.log"
APACHE_CONF="/etc/apache2/apache2.conf"
SECURITY_CONF="/etc/apache2/conf-available/security.conf"

# Función de logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Función para hacer backup de configuración
backup_config() {
    local archivo=$1
    local backup="${archivo}.backup.$(date +%Y%m%d_%H%M%S)"
    
    if [ -f "$archivo" ]; then
        cp "$archivo" "$backup"
        echo -e "${GREEN}[✓]${NC} Backup creado: $backup"
        log "Backup creado: $backup"
        return 0
    else
        echo -e "${RED}[!]${NC} Archivo no encontrado: $archivo"
        return 1
    fi
}

# Función para configurar seguridad de Apache
configurar_seguridad_apache() {
    echo
    echo -e "${BOLD}=== CONFIGURACIÓN DE SEGURIDAD DE APACHE ===${NC}"
    log "Iniciando configuración de seguridad"
    
    # Hacer backup de archivos de configuración
    echo -e "${YELLOW}[*]${NC} Creando backups de configuración..."
    backup_config "$APACHE_CONF"
    backup_config "$SECURITY_CONF"
    
    # Configurar ServerSignature
    echo -e "\n${YELLOW}[*]${NC} Deshabilitando ServerSignature..."
    if grep -q "^ServerSignature" "$APACHE_CONF"; then
        sed -i 's/^ServerSignature On/ServerSignature Off/' "$APACHE_CONF"
        sed -i 's/^ServerSignature Email/ServerSignature Off/' "$APACHE_CONF"
    else
        echo "ServerSignature Off" >> "$APACHE_CONF"
    fi
    echo -e "${GREEN}[✓]${NC} ServerSignature deshabilitado"
    log "ServerSignature configurado como Off"
    
    # Configurar ServerTokens
    echo -e "${YELLOW}[*]${NC} Configurando ServerTokens..."
    if grep -q "^ServerTokens" "$APACHE_CONF"; then
        sed -i 's/^ServerTokens.*/ServerTokens Prod/' "$APACHE_CONF"
    else
        echo "ServerTokens Prod" >> "$APACHE_CONF"
    fi
    echo -e "${GREEN}[✓]${NC} ServerTokens configurado como Prod"
    log "ServerTokens configurado como Prod"
    
    # Deshabilitar listado de directorios
    echo -e "${YELLOW}[*]${NC} Deshabilitando listado de directorios..."
    if a2dismod -f autoindex >> "$LOG_FILE" 2>&1; then
        echo -e "${GREEN}[✓]${NC} Módulo autoindex deshabilitado"
        log "Módulo autoindex deshabilitado"
    else
        echo -e "${YELLOW}[!]${NC} Módulo autoindex ya estaba deshabilitado"
    fi
    
    # Deshabilitar seguimiento de HTTP (TRACE/TRACK)
    echo -e "${YELLOW}[*]${NC} Deshabilitando métodos HTTP TRACE/TRACK..."
    if ! grep -q "TraceEnable" "$SECURITY_CONF"; then
        echo "TraceEnable Off" >> "$SECURITY_CONF"
        echo -e "${GREEN}[✓]${NC} Métodos TRACE/TRACK deshabilitados"
        log "TraceEnable configurado como Off"
    else
        sed -i 's/^TraceEnable.*/TraceEnable Off/' "$SECURITY_CONF"
        echo -e "${GREEN}[✓]${NC} TraceEnable actualizado"
    fi
    
    # Agregar headers de seguridad
    echo -e "${YELLOW}[*]${NC} Configurando headers de seguridad..."
    
    local security_headers="
# Security Headers
<IfModule mod_headers.c>
    # Prevenir clickjacking
    Header always set X-Frame-Options \"SAMEORIGIN\"
    
    # Prevenir MIME-type sniffing
    Header always set X-Content-Type-Options \"nosniff\"
    
    # Habilitar protección XSS del navegador
    Header always set X-XSS-Protection \"1; mode=block\"
    
    # Política de referrer
    Header always set Referrer-Policy \"no-referrer-when-downgrade\"
    
    # Eliminar información del servidor
    Header always unset X-Powered-By
    Header always unset Server
</IfModule>
"
    
    if ! grep -q "X-Frame-Options" "$SECURITY_CONF"; then
        echo "$security_headers" >> "$SECURITY_CONF"
        echo -e "${GREEN}[✓]${NC} Headers de seguridad agregados"
        log "Headers de seguridad configurados"
    else
        echo -e "${YELLOW}[!]${NC} Headers de seguridad ya configurados"
    fi
    
    # Deshabilitar módulos innecesarios
    echo -e "\n${YELLOW}[*]${NC} Deshabilitando módulos innecesarios..."
    local modulos_deshabilitar=("status" "userdir")
    
    for modulo in "${modulos_deshabilitar[@]}"; do
        if apache2ctl -M 2>/dev/null | grep -q "${modulo}_module"; then
            if a2dismod -f "$modulo" >> "$LOG_FILE" 2>&1; then
                echo -e "${GREEN}[✓]${NC} Módulo $modulo deshabilitado"
                log "Módulo $modulo deshabilitado"
            fi
        fi
    done
    
    return 0
}

# Función para configurar permisos de archivos
configurar_permisos_nextcloud() {
    echo
    echo -e "${BOLD}=== CONFIGURACIÓN DE PERMISOS ===${NC}"
    log "Configurando permisos de Nextcloud"
    
    local nextcloud_dir="/var/www/html/nextcloud"
    
    if [ ! -d "$nextcloud_dir" ]; then
        echo -e "${YELLOW}[!]${NC} Directorio de Nextcloud no encontrado: $nextcloud_dir"
        log "WARNING: Directorio Nextcloud no encontrado"
        return 1
    fi
    
    echo -e "${YELLOW}[*]${NC} Configurando permisos del directorio Nextcloud..."
    
    # Establecer propietario
    chown -R www-data:www-data "$nextcloud_dir"
    
    # Establecer permisos de directorios
    find "$nextcloud_dir" -type d -exec chmod 750 {} \;
    
    # Establecer permisos de archivos
    find "$nextcloud_dir" -type f -exec chmod 640 {} \;
    
    echo -e "${GREEN}[✓]${NC} Permisos configurados"
    log "Permisos de Nextcloud configurados"
    
    return 0
}

# Función para validar configuración de Apache
validar_configuracion() {
    echo
    echo -e "${BOLD}=== VALIDACIÓN DE CONFIGURACIÓN ===${NC}"
    
    echo -e "${YELLOW}[*]${NC} Verificando sintaxis de Apache..."
    if apache2ctl configtest >> "$LOG_FILE" 2>&1; then
        echo -e "${GREEN}[✓]${NC} Configuración de Apache válida"
        log "Configuración de Apache validada"
        return 0
    else
        echo -e "${RED}[!]${NC} Error en la configuración de Apache"
        echo -e "${YELLOW}[!]${NC} Ejecuta 'apache2ctl configtest' para ver detalles"
        log "ERROR: Configuración de Apache inválida"
        return 1
    fi
}

# Función para reiniciar Apache
reiniciar_apache() {
    echo
    echo -e "${YELLOW}[*]${NC} Reiniciando Apache..."
    
    if systemctl restart apache2; then
        echo -e "${GREEN}[✓]${NC} Apache reiniciado correctamente"
        log "Apache reiniciado exitosamente"
        
        # Verificar que esté corriendo
        if systemctl is-active --quiet apache2; then
            echo -e "${GREEN}[✓]${NC} Apache está activo y corriendo"
            return 0
        else
            echo -e "${RED}[!]${NC} Apache no está activo después del reinicio"
            log "ERROR: Apache no está activo"
            return 1
        fi
    else
        echo -e "${RED}[!]${NC} Error al reiniciar Apache"
        log "ERROR: Fallo al reiniciar Apache"
        return 1
    fi
}

# Función para mostrar resumen de seguridad
mostrar_resumen_seguridad() {
    echo
    echo -e "${BOLD}========================================${NC}"
    echo -e "${GREEN}  CONFIGURACIÓN DE SEGURIDAD COMPLETADA${NC}"
    echo -e "${BOLD}========================================${NC}"
    echo
    echo -e "${BOLD}Configuraciones aplicadas:${NC}"
    echo -e "  ${GREEN}✓${NC} ServerSignature: Off"
    echo -e "  ${GREEN}✓${NC} ServerTokens: Prod"
    echo -e "  ${GREEN}✓${NC} Listado de directorios: Deshabilitado"
    echo -e "  ${GREEN}✓${NC} Métodos TRACE/TRACK: Deshabilitados"
    echo -e "  ${GREEN}✓${NC} Headers de seguridad: Configurados"
    echo -e "  ${GREEN}✓${NC} Módulos innecesarios: Deshabilitados"
    echo -e "  ${GREEN}✓${NC} Permisos de archivos: Configurados"
    echo
    echo -e "${BOLD}Recomendaciones adicionales:${NC}"
    echo -e "  • Configurar SSL/HTTPS con Let's Encrypt"
    echo -e "  • Configurar firewall (ufw) para limitar acceso"
    echo -e "  • Mantener el sistema actualizado regularmente"
    echo -e "  • Revisar logs de seguridad periódicamente"
    echo -e "  • Configurar backups automáticos"
    echo
    echo -e "${YELLOW}[!]${NC} Logs guardados en: $LOG_FILE"
    echo
}

# Función para prueba de seguridad básica
prueba_seguridad() {
    echo
    echo -e "${BOLD}=== PRUEBA DE SEGURIDAD ===${NC}"
    
    # Verificar ServerTokens
    echo -e "${YELLOW}[*]${NC} Verificando ServerTokens..."
    if grep -q "^ServerTokens Prod" "$APACHE_CONF"; then
        echo -e "${GREEN}[✓]${NC} ServerTokens configurado correctamente"
    else
        echo -e "${RED}[✗]${NC} ServerTokens no configurado correctamente"
    fi
    
    # Verificar ServerSignature
    echo -e "${YELLOW}[*]${NC} Verificando ServerSignature..."
    if grep -q "^ServerSignature Off" "$APACHE_CONF"; then
        echo -e "${GREEN}[✓]${NC} ServerSignature configurado correctamente"
    else
        echo -e "${RED}[✗]${NC} ServerSignature no configurado correctamente"
    fi
    
    # Verificar módulo autoindex
    echo -e "${YELLOW}[*]${NC} Verificando módulo autoindex..."
    if ! apache2ctl -M 2>/dev/null | grep -q "autoindex_module"; then
        echo -e "${GREEN}[✓]${NC} Módulo autoindex deshabilitado"
    else
        echo -e "${YELLOW}[!]${NC} Módulo autoindex aún habilitado"
    fi
    
    # Verificar headers de seguridad
    echo -e "${YELLOW}[*]${NC} Verificando headers de seguridad..."
    if grep -q "X-Frame-Options" "$SECURITY_CONF"; then
        echo -e "${GREEN}[✓]${NC} Headers de seguridad configurados"
    else
        echo -e "${RED}[✗]${NC} Headers de seguridad no encontrados"
    fi
}

# SCRIPT PRINCIPAL
main_directorios() {
    clear
    echo -e "${BOLD}=== CONFIGURACIÓN DE SEGURIDAD DE DIRECTORIOS ===${NC}"
    log "===== INICIO DE CONFIGURACIÓN DE SEGURIDAD ====="
    
    # Verificar que se ejecuta como root
    if [ "$(id -u)" != "0" ]; then
        echo -e "${RED}[!] Este script debe ejecutarse como root${NC}"
        exit 1
    fi
    
    # Verificar que Apache está instalado
    if ! command -v apache2 >/dev/null 2>&1; then
        echo -e "${RED}[!] Apache no está instalado${NC}"
        log "ERROR: Apache no encontrado"
        exit 1
    fi
    
    # Ejecutar configuraciones
    if configurar_seguridad_apache && \
       configurar_permisos_nextcloud && \
       validar_configuracion && \
       reiniciar_apache; then
        prueba_seguridad
        mostrar_resumen_seguridad
        log "Configuración de seguridad completada exitosamente"
        return 0
    else
        echo
        echo -e "${RED}[!] Hubo errores durante la configuración${NC}"
        echo -e "${YELLOW}[!]${NC} Revisa los logs en: $LOG_FILE"
        log "ERROR: Configuración de seguridad finalizada con errores"
        return 1
    fi
}

# Ejecutar solo si se llama directamente (no con source)
if [ "${BASH_SOURCE[0]}" -ef "$0" ]; then
    main_directorios
fi