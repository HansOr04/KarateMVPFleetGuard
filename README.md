# FleetGuard Karate MVP

Suite de pruebas de integración para los microservicios de FleetGuard usando el framework [Karate](https://karatelabs.github.io/karate/), JUnit 5 y Maven.

---

## 📋 Prerequisitos

| Herramienta | Versión mínima |
|-------------|---------------|
| Java JDK    | 17            |
| Maven       | 3.8+          |
| Docker      | 20+           |
| Docker Compose | 2+         |

Asegúrate de tener levantado el proyecto principal **mvpfleetguard** antes de ejecutar las pruebas.

---

## 🚀 Levantar el entorno

```bash
# Desde el directorio raíz del proyecto principal
cd mvpfleetguard
docker-compose up -d

# Esperar ~30 segundos a que los servicios estén healthy
# Verificar que los servicios responden:
curl http://localhost:8081/api/vehicles/HEALTH_CHECK   # Esperado: 404, no "connection refused"
curl http://localhost:8093/api/maintenance-rules        # Esperado: 200 o 405, no "connection refused"
```

Los servicios deben estar disponibles en:
- **fleet-service**: `http://localhost:8081`
- **rules-alerts-service**: `http://localhost:8093`

---

## ▶️ Ejecutar las pruebas

### Ejecutar todos los tests

```bash
mvn clean test
```

### Ejecutar solo por servicio

```bash
# Solo fleet-service
mvn test -Dtest=FleetRunnerTest

# Solo rules-alerts-service
mvn test -Dtest=RulesRunnerTest

# Todos (runner principal)
mvn test -Dtest=KarateRunnerTest
```

### Ejecutar por tags

```bash
# Solo smoke tests
mvn test -Dkarate.options="--tags @smoke"

# Solo tests de regresión
mvn test -Dkarate.options="--tags @regression"

# Solo tests de integración
mvn test -Dkarate.options="--tags @integration"

# Solo happy path scenarios
mvn test -Dkarate.options="--tags @happy"

# Solo negative scenarios
mvn test -Dkarate.options="--tags @negative"
```

---

## 📊 Ver los reportes

Después de la ejecución, el reporte HTML se genera automáticamente en:

```
target/karate-reports/karate-summary.html
```

Ábrelo en tu navegador para ver el detalle de cada escenario, tiempos de respuesta y resultados.

---

## 📁 Estructura del proyecto

```
karate-mvp/
├── pom.xml                                         # Dependencias Maven (Karate 1.4.1, JUnit 5.10.2)
├── README.md
└── src/
    └── test/
        ├── java/
        │   ├── com/fleetguard/karate/
        │   │   ├── KarateRunnerTest.java            # Runner principal (todos los servicios)
        │   │   ├── FleetRunnerTest.java             # Runner solo fleet-service
        │   │   └── RulesRunnerTest.java             # Runner solo rules-alerts-service
        │   ├── fleet/
        │   │   ├── register-vehicle.feature         # POST /api/vehicles
        │   │   ├── register-mileage.feature         # POST /api/vehicles/{plate}/mileage
        │   │   └── get-vehicle.feature              # GET /api/vehicles/{plate}
        │   ├── rules/
        │   │   ├── create-rule.feature              # POST /api/maintenance-rules
        │   │   ├── associate-vehicle-type.feature   # POST /api/maintenance-rules/{id}/vehicle-types
        │   │   ├── register-maintenance.feature     # POST /api/maintenance/{plate}
        │   │   ├── get-alerts.feature               # GET /api/alerts
        │   │   └── validate-alert-schema.feature    # Helper: schema validation (@ignore)
        │   └── integration/
        │       └── full-flow.feature                # Flujo completo cross-service (RabbitMQ)
        └── resources/
            └── karate-config.js                    # Configuración global (URLs, seed data, headers)
```

---

## 🏷️ Tags disponibles

| Tag           | Descripción                                          |
|---------------|------------------------------------------------------|
| `@smoke`      | Pruebas básicas de sanidad — ejecución rápida        |
| `@regression` | Suite completa de regresión                          |
| `@happy`      | Escenarios del camino feliz (éxito esperado)         |
| `@negative`   | Escenarios negativos (validaciones, errores)         |
| `@integration`| Pruebas de integración cross-service (RabbitMQ)      |

---

## ⚙️ Configuración (karate-config.js)

| Variable        | Local                      | Docker                            |
|-----------------|----------------------------|-----------------------------------|
| `fleetBaseUrl`  | `http://localhost:8081`    | `http://fleet-service:8080`       |
| `rulesBaseUrl`  | `http://localhost:8093`    | `http://rules-alerts-service:8080`|
| `sedanTypeId`   | `c1a1d13e-...-5311`        | (mismo)                           |
| `suvTypeId`     | `c1a1d13e-...-5313`        | (mismo)                           |
| `pickupTypeId`  | `c1a1d13e-...-5315`        | (mismo)                           |

Para ejecutar en modo Docker:
```bash
mvn test -Dkarate.env=docker
```

---

## 🧪 Descripción de los features

### fleet/register-vehicle.feature
Valida el endpoint `POST /api/vehicles`:
- ✅ Registro exitoso (placa y VIN generados dinámicamente)
- ❌ Placa duplicada → 400
- ❌ Sin campo `plate` → 400
- ❌ VIN con 16 chars (inválido) → 400
- ❌ `vehicleTypeId` inexistente → 404

### fleet/register-mileage.feature
Valida el endpoint `POST /api/vehicles/{plate}/mileage`:
- ✅ Registro exitoso, valida `excessiveIncrement = false`
- ✅ Incremento > 2000 km → `excessiveIncrement = true`
- ❌ Km menor al actual → 400
- ❌ Km negativo → 400
- ❌ Sin `recordedBy` → 400
- ❌ Placa inexistente → 404

### fleet/get-vehicle.feature
Valida el endpoint `GET /api/vehicles/{plate}`:
- ✅ Consulta de vehículo existente
- ✅ Schema validation completa
- ❌ Vehículo inexistente → 404

### rules/create-rule.feature
Valida el endpoint `POST /api/maintenance-rules`:
- ✅ Regla preventiva con todos los campos
- ✅ Regla correctiva
- ✅ Sin `warningThresholdKm` usa default 500
- ❌ Sin `name` → 400
- ❌ Sin `intervalKm` → 400
- ❌ `intervalKm = 0` → 400

### rules/associate-vehicle-type.feature
Valida el endpoint `POST /api/maintenance-rules/{id}/vehicle-types`:
- ✅ Asociación exitosa
- ❌ Duplicado → 409 con mensaje "asociada"
- ❌ Regla inexistente → 404
- ❌ Sin `vehicleTypeId` → 400

### rules/register-maintenance.feature
Valida el endpoint `POST /api/maintenance/{plate}`:
- ✅ Registro exitoso
- ✅ Con `alertId` para resolver alerta
- ❌ Sin `serviceType` → 400
- ❌ `mileageAtService = 0` → 400

### rules/get-alerts.feature
Valida el endpoint `GET /api/alerts`:
- ✅ Lista todas las alertas activas
- ✅ Filtrado por `status=PENDING`
- ✅ Schema validation de cada alerta

### integration/full-flow.feature ⭐
Prueba de integración crítica que valida la comunicación asíncrona via **RabbitMQ**:
1. Registra vehículo en fleet-service
2. Crea regla de mantenimiento
3. Asocia regla al tipo de vehículo
4. Registra kilometraje dentro del umbral de alerta
5. Espera 3 segundos para procesamiento asíncrono
6. Verifica que se generó alerta PENDING
7. Registra mantenimiento con `alertId`
8. Verifica que la alerta fue resuelta

---

## 🔑 Decisiones de diseño

- **Datos dinámicos**: Placas y VINs se generan con UUID para evitar colisiones entre ejecuciones paralelas
- **Background reutilizable**: Cada feature que necesita un vehículo lo crea en su `Background`
- **Independencia**: Cada feature puede ejecutarse de forma independiente
- **Headers globales**: `Content-Type: application/json` configurado en `karate-config.js`
