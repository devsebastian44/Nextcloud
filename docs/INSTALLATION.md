# Guía de Instalación

Este proyecto proporciona un instalador automatizado para Nextcloud en sistemas Ubuntu.

## Requisitos Previos

*   **SO**: Ubuntu 20.04 LTS o superior recomendado.
*   **Usuario**: Privilegios de root (`sudo`).
*   **Acceso a Internet**: Requerido para descargar paquetes.

## Inicio Rápido

1.  Clonar el repositorio:
    ```bash
    git clone https://github.com/Devsebastian44/Nextcloud.git
    cd Nextcloud
    ```

2.  Hacer el script ejecutable:
    ```bash
    chmod +x setup.sh
    ```

3.  Ejecutar el instalador:
    ```bash
    sudo ./setup.sh
    ```

## Post-Instalación

Una vez que el script finalice:
1.  Ejecute `mysql_secure_installation` como se le solicite.
2.  Acceda a la IP de su servidor en un navegador web para finalizar la configuración de Nextcloud.
