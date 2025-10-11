# 📦 Proyecto Infra - Sistema de Control de Inventario en AWS

> Implementación de un sistema de control de inventario para una bodega, desplegado completamente en la nube de AWS.  
> El objetivo principal es **automatizar la gestión de productos**, controlando vencimientos y niveles de stock, asegurando acceso autenticado y notificaciones en tiempo real al personal administrativo.

---

## 📋 Tabla de contenido

- [Contexto del proyecto](#-contexto-del-proyecto)  
- [Problemática](#-problemática)   
- [Requisitos no funcionales](#-requisitos-no-funcionales)  
- [Tecnologías utilizadas](#-tecnologías-utilizadas)  
- [Estructura del proyecto](#-estructura-del-proyecto)  
- [Despliegue](#-despliegue)  
- [Autores](#-autores)  
- [Licencia](#-licencia)  

---

## 🧐 Contexto del proyecto

El sistema busca **modernizar la gestión de inventario** de una bodega, aprovechando la infraestructura en la nube de AWS.  
Con este proyecto se pretende:  
- Automatizar procesos críticos.  
- Asegurar notificaciones oportunas.  
- Brindar métricas en tiempo real para la toma de decisiones.  

---

## ⚠️ Problemática

Actualmente, muchas bodegas gestionan el inventario de forma manual o con sistemas locales que presentan limitaciones:  

- Pérdidas económicas por falta de control de vencimientos.  
- Desorganización operativa y poca visibilidad.  
- Ausencia de supervisión automatizada del stock y fechas de caducidad.  
- Falta de alertas en tiempo real ante productos sin stock.  
- El administrador depende de revisiones manuales o reportes tardíos.  

---

## 🔔 Requisitos no funcionales

- Envío de **notificaciones por correo electrónico** al detectar productos caducados o stock en cero.  
- Configuración de **horarios para notificaciones**, evitando interrupciones fuera del horario laboral.  
- Visualización de métricas en tiempo real:  
  - Valor total del inventario.  
  - Tasa de rotación de productos.  
  - Listado de productos críticos (caducados o en stock bajo).  

---

## 🛠 Tecnologías utilizadas

- **AWS (Cognito, IAM, notificaciones, hosting en la nube)**  
- **HTML5, CSS3, JavaScript** (interfaz web)  
- **JWT** para seguridad  
- **GitHub Pages** para despliegue inicial  

---

## 🗂 Estructura del proyecto
```
/
├── Dashboard/
│   ├── index.html
│   ├── script.js
│   └── style.css
│
├── Web/
│   ├── auth.js
│   ├── index.html
│   ├── script.js
│   └── style.css
│
├── terraform/
│   ├── providers.tf
│   ├── subnets_priv.tf
│   ├── subnets_public.tf
│   └── vpc.tf
│
├── web server/
│
├── inventario/
│   ├── Dockerfile
│   ├── package.json
│   └── servidor-inventario.js
│
├── reportes/
│   ├── Dockerfile
│   ├── package.json
│   └── servidor-reportes.js
│
├── BD_proyecto.sql
└── README.md
```
---

## 🌐 Despliegue

El sistema se despliega en AWS y también puede publicarse en GitHub Pages para fines de demostración.


COMANDO DE LOGUEO EN DOCKER:
````````````
docker login
````````````
COMANDO PARA LA VISUALIZACIÓN DE CONTEINERS: 
````````````
docker ps
````````````
COMANDOS DE DESPLIEGUE:
Inicializar Terraform:
````````````
terraform init
````````````
Revisar el plan de ejecución:
````````````
terraform plan
````````````
Aplicar la configuración:
````````````
terraform apply 
````````````

---

## 👥 Autores

- Gutierrez Rubio, Bryam

- Cedananos Guevara, Julio

- Flores Alvarez, Rodrigo

- Ibañez Herrera, Luis

---
