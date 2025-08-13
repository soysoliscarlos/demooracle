# DEMO – Integración de Oracle con Azure Data Factory y Power BI  

**Usando Integration Runtime por defecto**

Este demo muestra cómo extraer datos desde una base de datos **Oracle** en Azure hacia **Azure Data Lake Storage Gen2** utilizando **Azure Data Factory (ADF)**, y luego visualizarlos en **Power BI**.

---

## 1. Requisitos previos

- Base de datos Oracle accesible públicamente desde Azure (por ejemplo, la creada con Terraform en la demo).
- Credenciales de conexión a Oracle:
  - **Usuario**: `demo`
  - **Contraseña**: definida en el despliegue
  - **Host**: IP pública de la VM Oracle
  - **Puerto**: `1521`
  - **Service Name**: `XEPDB1`
- Un **Azure Data Lake Storage Gen2** disponible (creado en la demo como `oracle-export`).
- Permisos para crear y administrar pipelines en **Azure Data Factory**.

---

## 2. Crear el Linked Service a Oracle

1. En el portal de Azure, abre tu instancia de **Azure Data Factory**.
2. En el menú izquierdo, selecciona **Manage** → **Linked Services** → **+ New**.
3. Busca y selecciona **Oracle**.
4. Configura:
   - **Name**: `LS_Oracle`
   - **Integration Runtime**: *Default AutoResolveIntegrationRuntime* (ya incluido en ADF, no requiere instalación).
   - **Host**: IP pública de la VM Oracle.
   - **Port**: `1521`.
   - **Service name**: `XEPDB1`.
   - **Authentication type**: Basic.
   - **User name**: `demo`.
   - **Password**: Contraseña definida en el despliegue.
5. Haz clic en **Test connection** y confirma que es exitosa.
6. Guarda el Linked Service.

---

## 3. Crear el Linked Service a ADLS Gen2

1. En la misma sección **Linked Services**, selecciona **+ New**.
2. Elige **Azure Data Lake Storage Gen2**.
3. Configura:
   - **Name**: `LS_ADLS`.
   - **Authentication method**: Managed Identity o clave de cuenta (según configuración).
   - **Storage account name**: Nombre del Storage creado en la demo.
4. Haz clic en **Test connection** y guarda.

---

## 4. Crear los Datasets

### Dataset Oracle:
1. Entra a **Author** → **Datasets** → **+ New Dataset**.
2. Elige **Oracle**.
3. Asigna el Linked Service `LS_Oracle`.
4. Tabla: `EMPLOYEES_DEMO`.

### Dataset ADLS (sink):

1. **+ New Dataset**.
2. Elige **Azure Data Lake Storage Gen2** → Formato **DelimitedText**.
3. Asigna el Linked Service `LS_ADLS`.
4. Carpeta de destino: `oracle-export`.
5. Nombre de archivo: `employees_demo.csv`.

---

## 5. Crear y ejecutar el pipeline

1. Ve a **Author** → **Pipelines** → **+ New Pipeline**.
2. Agrega una actividad **Copy Data**.
3. Configura:
   - **Source**: Dataset Oracle (`EMPLOYEES_DEMO`).
   - **Sink**: Dataset ADLS (`employees_demo.csv`).
4. Guarda y publica los cambios (**Publish all**).
5. Haz clic en **Add Trigger** → **Trigger Now** para ejecutar el pipeline.
6. Verifica en el **Monitor** que el pipeline se ejecutó correctamente.

---

## 6. Visualizar en Power BI

1. Abre **Power BI Desktop**.
2. Selecciona **Get Data** → **Azure Data Lake Storage Gen2**.
3. Ingresa la URL del contenedor y carpeta `oracle-export`.
4. Selecciona el archivo `employees_demo.csv`.
5. Carga los datos y crea una visualización (ejemplo: tabla con `employee_id`, `first_name`, `last_name`, `salary`).

---

## 7. Resultado esperado

- El pipeline extraerá los datos de Oracle y los guardará como CSV en ADLS.
- Power BI mostrará la tabla `employees_demo` con los registros cargados desde Oracle.

## DemoOracle: Infraestructura Oracle XE + Azure Data Factory con Terraform

Este proyecto despliega una arquitectura de demo en Azure usando Terraform, que incluye:

- Red virtual y subred segura
- VM Ubuntu con Docker y Oracle XE (contenedor)
- Key Vault para almacenar contraseñas
- Storage Account (ADLS Gen2) para exportación de datos
- Azure Data Factory (ADF) para integración de datos

## Estructura del proyecto

``` 
terraform/
  main.tf           # Infraestructura principal (red, VM, Key Vault, Storage, etc.)
  datafactory.tf    # Recursos de Azure Data Factory
  variables.tf      # Definición de variables
  output.tf         # Salidas útiles
  terraform.tfstate # Estado de Terraform
```

## Requisitos previos

- Azure Subscription
- [Terraform >= 1.0.0](https://www.terraform.io/downloads.html)
- Claves SSH para acceso a la VM
- Permisos para crear recursos en Azure

## Variables principales

- `prefix`: Prefijo para nombrar recursos
- `rg_name`: Nombre del Resource Group
- `location`: Región de Azure (ej. eastus)
- `my_ip`: Tu IP pública para acceso seguro (formato x.x.x.x/32)
- `oracle_password`: Contraseña para Oracle XE
- `admin_username`: Usuario admin de la VM
- `ssh_public_key_path`: Ruta a tu clave pública SSH
- `vm_size`: Tamaño de la VM (ej. Standard_D2s_v3)

## Despliegue rápido

1. Clona el repositorio y entra al directorio `terraform`:

   ```pwsh
   git clone <repo-url>
   cd DemoOracle/terraform
   ```

2. Inicializa Terraform:

   ```pwsh
   terraform init
   ```

3. Aplica la infraestructura (ajusta variables según tu entorno):

   ```pwsh
   terraform apply -var my_ip="<TU_IP>/32" -var oracle_password="<TU_PASSWORD>"
   ```

4. Espera a que termine el despliegue. Obtén la IP pública de la VM y accede vía SSH:

   ```pwsh
   ssh <admin_username>@<public_ip>
   ```

## Componentes desplegados

- **Red y Seguridad:** VNet, Subnet, NSG con reglas para SSH y Oracle (puerto 1521) solo desde tu IP.
- **VM Ubuntu:** Instala Docker y despliega Oracle XE en contenedor. Crea usuario demo y tabla de ejemplo.
- **Key Vault:** Guarda la contraseña de Oracle de forma segura.
- **Storage Account (ADLS Gen2):** Para exportar datos desde ADF.
- **Azure Data Factory:** Orquestación de pipelines de datos (puedes crear Linked Services y Pipelines adicionales).

## Notas y recomendaciones

- El tamaño de VM debe estar disponible en la región elegida. Si recibes error de SKU, prueba otro tamaño (ej. Standard_D2s_v3).
- La contraseña de Oracle se almacena en Key Vault y puede ser referenciada desde ADF.
- Puedes extender el proyecto agregando pipelines de ADF, Linked Services, datasets, etc.
- El acceso a la VM y Oracle está restringido a tu IP pública.

## Limpieza

Para eliminar todos los recursos creados:

```pwsh
terraform destroy -var my_ip="<TU_IP>/32" -var oracle_password="<TU_PASSWORD>"
```

## Créditos

Demo creada por Carlos. Infraestructura como código con Terraform y Azure.

