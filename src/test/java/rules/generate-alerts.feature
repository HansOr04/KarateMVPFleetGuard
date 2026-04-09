Feature: HU-11 - Generación automática de alertas por kilometraje

  Background:
    * url rulesBaseUrl
    * configure headers = { 'Content-Type': 'application/json' }

    # Helper para esperar procesamiento asíncrono RabbitMQ
    * def sleep = function(ms){ java.lang.Thread.sleep(ms) }

    # 1. Crear regla con interval 10000 km, warning threshold 500 km
    #    Esto significa que la alerta dispara cuando km >= 9500
    * def ruleName = 'Cambio aceite ' + java.util.UUID.randomUUID().toString().substring(0, 8)
    Given path '/api/maintenance-rules'
    And request
      """
      {
        "name": "#(ruleName)",
        "maintenanceType": "PREVENTIVE",
        "intervalKm": 10000,
        "warningThresholdKm": 500
      }
      """
    When method POST
    Then status 201
    * def ruleId = response.id

    # 2. Asociar regla al tipo Sedán
    Given path '/api/maintenance-rules', ruleId, 'vehicle-types'
    And request { "vehicleTypeId": "#(sedanTypeId)" }
    When method POST
    Then status 201

    # 3. Crear vehículo Sedán fresco
    * def plate = 'AL' + java.util.UUID.randomUUID().toString().replace('-','').substring(0, 5).toUpperCase()
    * def vin = '1HGCM' + java.util.UUID.randomUUID().toString().replace('-','').substring(0, 12).toUpperCase()
    Given url fleetBaseUrl
    And path '/api/vehicles'
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
    * def vehicleId = response.id


  @regression @happy @hu-11
  Scenario: HU-11 - Generar alerta cuando km alcanza el umbral exacto (9500)
    # Umbral exacto: intervalKm 10000 - warning 500 = 9500
    Given url fleetBaseUrl
    And path '/api/vehicles', plate, 'mileage'
    And request { "mileageValue": 9500, "recordedBy": "QA Tester" }
    When method POST
    Then status 201

    # Esperar procesamiento asíncrono RabbitMQ
    * sleep(3000)

    # Verificar alerta generada
    Given url rulesBaseUrl
    And path '/api/alerts/vehicle', plate
    When method GET
    Then status 200
    * def myAlerts = karate.filter(response, function(a){ return a.ruleId == ruleId })
    * print 'My alerts for ruleId:', ruleId, 'count:', myAlerts.length
    And match myAlerts == '#[_ > 0]'
    And match myAlerts[0].vehicleId == '#uuid'
    And match myAlerts[0].status == 'PENDING'
    And match myAlerts[0].ruleName == ruleName

  @regression @negative @hu-11
  Scenario: HU-11 - No generar alerta si km está lejos del umbral
    # km = 7000, lejos del umbral que arranca en 9500
    Given url fleetBaseUrl
    And path '/api/vehicles', plate, 'mileage'
    And request { "mileageValue": 7000, "recordedBy": "QA Tester" }
    When method POST
    Then status 201

    * sleep(3000)

    Given url rulesBaseUrl
    And path '/api/alerts/vehicle', plate
    When method GET
    Then status 200
    And match response == '#[0]'

  @regression @negative @hu-11
  Scenario: HU-11 - No duplicar alertas PENDING ya existentes (idempotencia)
    # Primer registro: dispara alerta a 9600 km
    Given url fleetBaseUrl
    And path '/api/vehicles', plate, 'mileage'
    And request { "mileageValue": 9600, "recordedBy": "QA Tester" }
    When method POST
    Then status 201

    * sleep(3000)

    # Segundo registro: incremento dentro del umbral (todavía aplica la regla)
    Given url fleetBaseUrl
    And path '/api/vehicles', plate, 'mileage'
    And request { "mileageValue": 9700, "recordedBy": "QA Tester" }
    When method POST
    Then status 201

    * sleep(3000)

    # Verificar que solo hay UNA alerta PENDING para este vehículo + regla
    Given url rulesBaseUrl
    And path '/api/alerts/vehicle', plate
    When method GET
    Then status 200
    * def pendingForRule = karate.filter(response, function(a){ return a.ruleId == ruleId && a.status == 'PENDING' })
    And match pendingForRule == '#[1]'
