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

- Envío de **notificaciones por correo electrónico** al detectar productos caducados o stock en cero, garantizando un tiempo máximo de entrega de 60 segundos desde la detección del evento.  
- El sistema permitirá configurar los horarios de envío de notificaciones, asegurando que no se generen ni envíen alertas fuera del horario laboral definido, con el fin de evitar interrupciones innecesarias.  
- El sistema deberá mostrar métricas en tiempo real (valor total del inventario, tasa de rotación de productos y listado de productos críticos) con una actualización máxima de 5 segundos entre el cambio en la base de datos y su visualización en pantalla.  

---

## 🛠 Tecnologías utilizadas

- **Infraestructura como código:** Terraform (backend S3-only) y Ansible (con Ansible Vault).
- **Contenedores:** Docker · **Registro:** Amazon ECR.
- **Orquestación y red:** Amazon ECS Fargate, Application Load Balancer (interno), Amazon API Gateway (HTTP + VPC Link), Amazon VPC (subredes públicas/privadas, NAT Gateway).
- **Base de datos:** Amazon RDS for MySQL 8.0.
- **Frontend:** Amazon S3 (2 buckets: *dashboard* y *auth*) + Amazon CloudFront (OAC y fallback para SPA); **opcional:** Route 53 + ACM (certificados) y AWS WAF.
- **Observabilidad y jobs (opcionales):** CloudWatch Logs, SNS, SQS, Lambda, EventBridge.
- **Backend:** Node.js (Express, `mysql2`) con **JWT** para autenticación.
- **Web:** HTML5, CSS3, JavaScript.

---

## 🗂 Estructura del proyecto
```
/
├── Ansible/
│   ├── playbook.yaml
│   └── prod.yaml
│
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
│   ├── backend.tf
│   ├── ecr.tf
│   ├── frontend.tf
│   ├── main.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── variables.tf
│   └── vpc.tf
│
├── web server/
│
├── auth/
│   ├── Dockerfile
│   ├── package.json
│   └── servidor-reportes.js
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

El proyecto se despliega **end-to-end en AWS** con **Ansible + Terraform** y publica los frontends (Dashboard y Auth) en **S3 + CloudFront**. No usamos GitHub Pages ni Docker Compose en producción.

### 0) Prerrequisitos
- AWS CLI, Terraform, Ansible, Docker instalados.
- Credenciales de AWS configuradas (perfil o claves).
- (Recomendado) **Ansible Vault** para secretos.

```bash
aws --version && terraform -version && ansible --version && docker --version

---

### 1) Backend del estado de Terraform (S3-only)

Crea el bucket para el **estado remoto** de Terraform (elige un nombre **único globalmente**):

```bash
aws s3api create-bucket --bucket <TU_BUCKET_STATE> --region us-east-1
aws s3api put-bucket-versioning --bucket <TU_BUCKET_STATE> --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket <TU_BUCKET_STATE> \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
```

> El archivo `backend.tf` ya está preparado para S3-only; Ansible inyecta `bucket/key/region` con `backend_config`.

---

### 2) Configura `ansible/envs/prod.yml` (¡reemplaza estos datos!)

Valores **obligatorios** (reemplaza los placeholders):

* **AWS / backend de Terraform**

  * `aws_region`: `<REPLACE_ME_AWS_REGION>` (ej. `us-east-1`)
  * `tf_state_bucket`: `<TU_BUCKET_STATE>`
  * `tf_state_key`: `infra/terraform.tfstate` (o la ruta que prefieras)

* **Frontend (S3/CloudFront)**

  * `enable_frontend`: `true`
  * `frontend_bucket_name`: `<UNICO_GLOBAL_DASHBOARD>`
  * `auth_frontend_bucket_name`: `<UNICO_GLOBAL_AUTH>`
  * `uploads_bucket_name`: `<UNICO_GLOBAL_UPLOADS>` (si lo usas)
  * `dashboard_src_dir`: `./Dashboard`
  * `auth_src_dir`: `./Web`

* **Build & push (contenedores)**

  * `ecr_repo_prefix`: `inventario-panel` (o el prefijo que quieras)
  * `auth_context_dir`, `inventario_context_dir`, `reportes_context_dir`: rutas a tus Dockerfile (p. ej. `.../web_server`)
  * `image_tag`: `v1.0` (o el tag que publiques)

* **Base de datos (RDS MySQL)**

  * `db_name`: `inventario`
  * `db_username`: (ej. `root` o `appuser`)
  * `db_password`: **coloca una contraseña fuerte** (usa **Ansible Vault**)

* **JWT**

  * `jwt_secret`: **coloca un secreto fuerte** (usa **Ansible Vault**)

Valores **opcionales**:

* **Credenciales AWS** (si **no** usas `aws_profile`):

  * `aws_access_key_id`, `aws_secret_access_key`, `aws_session_token`

* **Dominio / DNS / Certificados (pueden quedar vacíos)**

  * `domain_name`, `hosted_zone_id`

    > Si están vacíos, CloudFront usará el dominio `*.cloudfront.net` y el certificado por defecto.
    > Cuando tengas dominio, complétalos y vuelve a aplicar.

* **WAF**

  * `waf_enable`: `true/false`

> **Recomendado**: cifra `prod.yml` con Vault
>
> ```bash
> ansible-vault create ansible/envs/prod.yml
> # o si ya existe:
> ansible-vault edit ansible/envs/prod.yml
> ```

---

### 3) Instala las colecciones de Ansible

```bash
ansible-galaxy collection install -r ansible/requirements.yml
```

---

### 4) Despliegue (build & push → Terraform → S3/CloudFront)

Ejecuta el playbook **end-to-end**:

```bash
# Con prompt de contraseña de Vault (si cifraste prod.yml)
ansible-playbook ansible/playbook.yml --ask-vault-pass

# O sin prompt (si guardaste la clave de Vault en un archivo):
# ansible-playbook ansible/playbook.yml --vault-password-file ~/.vault-pass.txt
```

El playbook hace automáticamente:

1. **ECR**: crea/valida repos, login y **build & push** de `auth`, `inventario`, `reportes`.
2. **Terraform**: `init` (backend S3) + `apply` (VPC, RDS, ECS, ALB, API Gateway, S3/CloudFront).
3. **Frontend**: sincroniza `./Dashboard` → bucket **dashboard** y `./Web` → bucket **auth**.
4. **CloudFront**: invalidación **solo** de `/index.html` y `/auth/index.html` para propagar cambios al instante.

---

### 5) Outputs y pruebas rápidas

```bash
terraform output -raw api_invoke_url
terraform output -raw cloudfront_domain
terraform output -raw rds_endpoint
terraform output ecr_repos
```

Pruebas de salud:

```bash
API="$(terraform output -raw api_invoke_url)"
curl -s "$API/auth/health"
curl -s "$API/inventario/health"
curl -s "$API/reportes/health"

CF="$(terraform output -raw cloudfront_domain)"
echo "Dashboard: https://$CF/"
echo "Auth:      https://$CF/auth/"
```

---

### 6) Notas importantes

* Los **nombres de buckets S3** deben ser **únicos globalmente** (cámbialos si ves conflicto).
* Sin `domain_name`/`hosted_zone_id`: CloudFront queda con **cert por defecto** y dominio `*.cloudfront.net`.
  Cuando tengas dominio, actualiza esos campos y reaplica.
* Minimiza invalidaciones usando **asset versioning** (hash en nombre de JS/CSS) y cache fuerte; invalida solo los **HTML**.
* No se usa **Docker Compose** en producción; el runtime es **ECS Fargate**.


## 👥 Autores

- Gutierrez Rubio, Bryam

- Cedamanos Guevara, Julio

- Flores Alvarez, Rodrigo

- Ibañez Herrera, Luis

---
