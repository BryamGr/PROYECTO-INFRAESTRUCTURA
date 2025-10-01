# PROYECTO-INFRAESTRUCTURA

INTEGRANTES:
- Cedamanos Guevara,Julio
- Flores Alvarez, Rodrigo
- Gutiérrez Rubio, Bryam
- Ibañez Herrera, Anthony


//CARACTERÍSTICAS DEL PROYECTO:
-Gestión de Inventario en Tiempo Real: Control completo de los productos en bodega, incluyendo registro, actualización y eliminación.
-Detección Automática de Productos Caducados: El sistema identifica automáticamente los productos que han caducado y los deshabilita o elimina según la configuración.
-Control de Stock Automático: Deshabilita productos cuando el stock llega a cero, manteniendo el registro histórico.
-Notificaciones Automáticas: Envía correos electrónicos o mensajes al administrador cuando se detectan productos caducados o sin stock.
-Dashboard Interactivo: Interfaz web responsive que muestra el inventario, métricas clave y reportes.
-Autenticación Segura: Integración con AWS Cognito para autenticación de usuarios, con soporte para proveedores de identidad como Google.
-Infraestructura como Código: Despliegue automatizado de la infraestructura en AWS usando Terraform.
-Alta Disponibilidad y Escalabilidad: Arquitectura diseñada con múltiples zonas de disponibilidad y autoescalado
-Seguridad Perimetral: Protección con WAF (Web Application Firewall) y distribución de contenido con CloudFront.
-Base de Datos Relacional: Almacenamiento seguro y confiable con Amazon RDS MySQL.

//LENGUAJE USADO PARA EL PROYECTO:
-Javascript
-CSS
-HTML
-HCL(archivos terraform)
-Dockerfile

//REQUISITOS NO FUNCIONALES PRINCIPALES:

El sistema debe identificar automáticamente productos caducados basándose en la comparación entre la fecha actual y las fechas de caducidad registradas.
El sistema debe deshabilitar productos cuando el stock llegue a cero, manteniendo el registro en la base de datos para propósitos históricos y de reporting.
El sistema debe notificar al administrador cuando los productos alcancen un nivel de stock bajo configurable, antes de llegar a cero.
El sistema debe autenticar usuarios mediante AWS Cognito, soportando proveedores de identidad externos.
El sistema debe generar y validar tokens JWT para asegurar el acceso autorizado a los recursos del sistema.
El sistema debe aplicar políticas IAM granulares para controlar el acceso a funciones y datos específicos según roles de usuario
El sistema debe enviar notificaciones por correo electrónico al administrador cuando se detecten productos caducados.
El sistema debe notificar automáticamente cuando productos alcancen stock cero.
El sistema debe permitir configurar horarios específicos para el envío de notificaciones, evitando interrupciones fuera del horario laboral.
El sistema debe mostrar métricas clave en tiempo real, incluyendo valor total del inventario, tasa de rotación de productos y listado de productos críticos (caducados o stock bajo).

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



