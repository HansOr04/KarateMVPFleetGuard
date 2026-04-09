Feature: Maintenance registration in rules-alerts-service

  Background:
    * url fleetBaseUrl
    # Register a fresh vehicle in fleet-service
    * def plate = 'KT' + java.util.UUID.randomUUID().toString().replace('-','').substring(0, 5).toUpperCase()
    * def vin = '1HGCM' + java.util.UUID.randomUUID().toString().replace('-','').substring(0, 12).toUpperCase()
    Given path '/api/vehicles'
    And request
      """
      {
        "plate": "#(plate)",
        "brand": "Toyota",
        "model": "Corolla",
        "year": 2023,
        "fuelType": "Gasoline",
        "vin": "#(vin)",
        "vehicleTypeId": "#(sedanTypeId)"
      }
      """
    When method POST
    Then status 201
    * print 'Background: registered vehicle with plate:', plate



  @regression @negative
  Scenario: Maintenance without serviceType is rejected
    Given url rulesBaseUrl
    And path '/api/maintenance/' + plate
    And request
      """
      {
        "description": "Mantenimiento sin tipo",
        "cost": 100.00,
        "provider": "Taller Test",
        "mileageAtService": 5000,
        "performedAt": "2026-04-01T10:00:00"
      }
      """
    When method POST
    Then status 400
    * print 'Request without serviceType correctly rejected'

  @regression @negative
  Scenario: Maintenance with zero mileageAtService is rejected
    Given url rulesBaseUrl
    And path '/api/maintenance/' + plate
    And request
      """
      {
        "serviceType": "OIL_CHANGE",
        "description": "Km en cero",
        "cost": 100.00,
        "provider": "Taller Test",
        "mileageAtService": 0,
        "performedAt": "2026-04-01T10:00:00"
      }
      """
    When method POST
    Then status 400
    * print 'Request with mileageAtService=0 correctly rejected'

  @smoke @happy @regression
  Scenario: Maintenance with alertId resolves the alert
    # First create a rule and associate it
    * def ruleName = "Regla resolución alerta " + java.util.UUID.randomUUID().toString().substring(0, 5)
    Given url rulesBaseUrl
    And path '/api/maintenance-rules'
    And request
      """
      {
        "name": "#(ruleName)",
        "maintenanceType": "PREVENTIVE",
        "intervalKm": 5000,
        "warningThresholdKm": 500
      }
      """
    When method POST
    Then status 201
    * def ruleId = response.id

    Given url rulesBaseUrl
    And path '/api/maintenance-rules/' + ruleId + '/vehicle-types'
    And request { "vehicleTypeId": "#(sedanTypeId)" }
    When method POST
    Then status 201

    # Register mileage to trigger alert
    Given url fleetBaseUrl
    And path '/api/vehicles', plate, 'mileage'
    And request { "mileageValue": 4600, "recordedBy": "Operador QA" }
    When method POST
    Then status 201

    # Wait for async processing using Karate retry
    * configure retry = { count: 10, interval: 1000 }

    # Get generated alerts
    Given url rulesBaseUrl
    And path '/api/alerts'
    And retry until karate.filter(response, function(x){ return x.status == 'PENDING' && x.ruleId == ruleId }).length > 0
    When method GET
    Then status 200
    * def pendingAlerts = karate.filter(response, function(x){ return x.status == 'PENDING' && x.ruleId == ruleId })
    * print 'Pending alerts found:', pendingAlerts.length

    # Register maintenance (with alertId if available)
    * def alertId = pendingAlerts.length > 0 ? pendingAlerts[0].id : null
    Given url rulesBaseUrl
    And path '/api/maintenance/' + plate
    And request
      """
      {
        "alertId": "#(alertId)",
        "ruleId": "#(ruleId)",
        "serviceType": "OIL_CHANGE",
        "description": "Cambio de aceite para resolver alerta",
        "cost": 150.00,
        "provider": "Taller QA",
        "recordedBy": "Operador QA",
        "mileageAtService": 4600,
        "performedAt": "2026-04-02T14:00:00"
      }
      """
    When method POST
    Then status 201
    And match response.id == '#uuid'
    * print 'Maintenance registered to resolve alert, maintenance id:', response.id

  @smoke @happy @regression @hu-13
  Scenario: HU-13 - Registrar mantenimiento con datos completos
    * def maintenancePlate = 'MT' + java.util.UUID.randomUUID().toString().replace('-','').substring(0, 5).toUpperCase()
    * def maintVin = '1HGCM' + java.util.UUID.randomUUID().toString().replace('-','').substring(0, 12).toUpperCase()
    * def sleep = function(ms){ java.lang.Thread.sleep(ms) }

    # Paso 1: Crear vehículo
    Given url fleetBaseUrl
    And path '/api/vehicles'
    And request
      """
      {
        "plate": "#(maintenancePlate)",
        "brand": "Toyota",
        "model": "Hilux",
        "year": 2023,
        "fuelType": "Diesel",
        "vin": "#(maintVin)",
        "vehicleTypeId": "#(sedanTypeId)"
      }
      """
    When method POST
    Then status 201

    # Paso 2: Crear regla y asociar al tipo
    * def hu13RuleName = 'Regla HU13 ' + java.util.UUID.randomUUID().toString().substring(0, 5)
    Given url rulesBaseUrl
    And path '/api/maintenance-rules'
    And request
      """
      {
        "name": "#(hu13RuleName)",
        "maintenanceType": "PREVENTIVE",
        "intervalKm": 5000,
        "warningThresholdKm": 500
      }
      """
    When method POST
    Then status 201
    * def hu13RuleId = response.id

    Given url rulesBaseUrl
    And path '/api/maintenance-rules', hu13RuleId, 'vehicle-types'
    And request { "vehicleTypeId": "#(sedanTypeId)" }
    When method POST
    Then status 201

    # Paso 3: Registrar km para disparar alerta (4600 >= 5000-500=4500)
    Given url fleetBaseUrl
    And path '/api/vehicles', maintenancePlate, 'mileage'
    And request { "mileageValue": 4600, "recordedBy": "Operador QA" }
    When method POST
    Then status 201

    # Esperar procesamiento asíncrono
    * sleep(3000)

    # Paso 4: Obtener alertId
    * configure retry = { count: 10, interval: 1000 }
    Given url rulesBaseUrl
    And path '/api/alerts'
    And retry until karate.filter(response, function(x){ return x.status == 'PENDING' && x.ruleId == hu13RuleId }).length > 0
    When method GET
    Then status 200
    * def hu13Alerts = karate.filter(response, function(x){ return x.status == 'PENDING' && x.ruleId == hu13RuleId })
    * def hu13AlertId = hu13Alerts[0].id

    # Paso 5: Registrar mantenimiento completo con alertId
    Given url rulesBaseUrl
    And path '/api/maintenance', maintenancePlate
    And request
      """
      {
        "alertId": "#(hu13AlertId)",
        "ruleId": "#(hu13RuleId)",
        "serviceType": "OIL_CHANGE",
        "description": "Sin novedades",
        "cost": 85.00,
        "provider": "Taller Central",
        "recordedBy": "Tecnico QA",
        "mileageAtService": 4600,
        "performedAt": "2026-04-01T10:00:00"
      }
      """
    When method POST
    Then status 201
    And match response.serviceType == 'OIL_CHANGE'
    And match response.cost == 85.00
    And match response.provider == 'Taller Central'
    And match response.description == 'Sin novedades'
    And match response.plate == maintenancePlate
    And match response.id == '#uuid'

  @regression @negative @hu-13
  Scenario: HU-13 - Rechazar registro de mantenimiento sin tipo de servicio
    * def maintenancePlate = 'MT' + java.util.UUID.randomUUID().toString().replace('-','').substring(0, 5).toUpperCase()
    * def vin = '1HGCM' + java.util.UUID.randomUUID().toString().replace('-','').substring(0, 12).toUpperCase()

    Given url fleetBaseUrl
    And path '/api/vehicles'
    And request
      """
      {
        "plate": "#(maintenancePlate)",
        "brand": "Toyota",
        "model": "Hilux",
        "year": 2023,
        "fuelType": "Diesel",
        "vin": "#(vin)",
        "vehicleTypeId": "#(sedanTypeId)"
      }
      """
    When method POST
    Then status 201

    # Intentar registrar mantenimiento sin serviceType
    Given url rulesBaseUrl
    And path '/api/maintenance', maintenancePlate
    And request
      """
      {
        "description": "Sin tipo",
        "cost": 50.00,
        "mileageAtService": 5000,
        "performedAt": "2026-04-01T10:00:00"
      }
      """
    When method POST
    Then status 400
