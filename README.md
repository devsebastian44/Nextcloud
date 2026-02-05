# Instalador Automatizado de Nextcloud

![Bash](https://img.shields.io/badge/Bash-5.0+-green?logo=gnubash&logoColor=white)
![GitLab](https://img.shields.io/badge/GitLab-Repository-orange?logo=gitlab)
![License](https://img.shields.io/badge/License-MIT-yellow)
![Status](https://img.shields.io/badge/Status-Stable-brightgreen)

Una solución profesional y automatizada en Bash para desplegar Nextcloud en servidores Ubuntu. Este proyecto simplifica la instalación del stack LEMP (Linux, Nginx/Apache, MySQL, PHP) y la configuración de Nextcloud.

## Características

*   **Gestión Automatizada de Dependencias**: Instala PHP 8.1, Apache2, MySQL y las extensiones necesarias.
*   **Diseño Modular**: Lógica del script separada en funciones para facilitar el mantenimiento.
*   **Registro (Logging)**: Logs de instalación detallados para la resolución de problemas.
*   **Verificación de Seguridad**: Verifica privilegios de root antes de la ejecución.

## Estructura del Proyecto

```
.
├── configs/        # Plantillas de configuración
├── docs/           # Documentación
├── Scripts/        # Scripts auxiliares
├── tests/          # Pruebas de validación
├── setup.sh        # Script instalador principal
└── .gitlab-ci.yml  # Configuración CI/CD
```

## Comenzando

Ver [docs/INSTALLATION.md](docs/INSTALLATION.md) para instrucciones detalladas.

### Ejecución Rápida

```bash
git clone https://github.com/Devsebastian44/Nextcloud.git
cd Nextcloud
chmod +x setup.sh
sudo ./setup.sh
```

## Descargo de Responsabilidad

Este software se proporciona "tal cual", sin garantía de ningún tipo. Úselo bajo su propio riesgo.
