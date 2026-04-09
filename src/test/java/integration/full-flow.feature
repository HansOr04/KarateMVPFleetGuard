Feature: Full integrated lifecycle flow - cross-service communication via RabbitMQ

  Background:
    * def uniquePlate = 'FG' + java.util.UUID.randomUUID().toString().replace('-','').substring(0, 5).toUpperCase()
    * def uniqueVin = '1HGCM' + java.util.UUID.randomUUID().toString().replace('-','').substring(0, 12).toUpperCase()
    * print 'Integration test starting with plate:', uniquePlate

  @smoke @integration @regression
  Scenario: Full lifecycle - vehicle registration to maintenance resolution
    # PASO 1: Register vehicle in fleet-service
    Given url fleetBaseUrl + '/api/vehicles'
    And request
      """
      {
        "plate": "#(uniquePlate)",
        "brand": "Toyota",
        "model": "Hilux",
        "year": 2024,
        "fuelType": "Diesel",
        "vin": "#(uniqueVin)",
        "vehicleTypeId": "#(sedanTypeId)"
      }
      """
    When method POST
    Then status 201
    * def vehicleId = response.id
    * print 'PASO 1: Vehicle registered, id:', vehicleId

    # PASO 2: Create maintenance rule in rules-alerts-service
    * def ruleName = "Cambio de aceite KT " + java.util.UUID.randomUUID().toString().substring(0, 5)
    Given url rulesBaseUrl + '/api/maintenance-rules'
    And request
      """
      {
        "name": "#(ruleName)",
        "maintenanceType": "PREVENTIVE",
        "intervalKm": 10000,
        "warningThresholdKm": 1000
      }
      """
    When method POST
    Then status 201
    * def ruleId = response.id
    * print 'PASO 2: Maintenance rule created, id:', ruleId

    # PASO 3: Associate rule to vehicle type (Sedán)
    Given url rulesBaseUrl + '/api/maintenance-rules/' + ruleId + '/vehicle-types'
    And request { "vehicleTypeId": "#(sedanTypeId)" }
    When method POST
    Then status 201
    * print 'PASO 3: Rule associated to vehicle type sedanTypeId:', sedanTypeId

    # PASO 4: Register mileage within warning threshold (9500 >= 10000 - 1000)
    Given url fleetBaseUrl + '/api/vehicles/' + uniquePlate + '/mileage'
    And request { "mileageValue": 9500, "recordedBy": "Operador QA" }
    When method POST
    Then status 201
    * print 'PASO 4: Mileage registered at 9500 km, within warning threshold'

    # PASO 5: Wait for async RabbitMQ processing
    * def sleep = function(millis){ java.lang.Thread.sleep(millis) }
    * sleep(3000)
    * print 'PASO 5: Waited 3 seconds for async RabbitMQ processing'

    # PASO 6: Verify PENDING alert was generated
    Given url rulesBaseUrl + '/api/alerts'
    When method GET
    Then status 200
    * def alerts = karate.filter(response, function(x){ return x.status == 'PENDING' && x.ruleId == ruleId })
    * print 'PASO 6: Alerts found for ruleId ' + ruleId + ':', alerts.length
    And assert alerts.length > 0
    * def alertId = alerts[0].id
    * print 'PASO 6: Alert generated with id:', alertId

    # PASO 7: Register maintenance to resolve the alert
    Given url rulesBaseUrl + '/api/maintenance/' + uniquePlate
    And request
      """
      {
        "alertId": "#(alertId)",
        "ruleId": "#(ruleId)",
        "serviceType": "OIL_CHANGE",
        "description": "Cambio de aceite post-alerta",
        "cost": 175.50,
        "provider": "Taller QA",
        "recordedBy": "Tecnico QA",
        "mileageAtService": 9500,
        "performedAt": "2026-04-02T14:00:00"
      }
      """
    When method POST
    Then status 201
    * print 'PASO 7: Maintenance registered to resolve alert:', alertId

    # PASO 8: Verify the alert was resolved
    Given url rulesBaseUrl + '/api/alerts'
    When method GET
    Then status 200
    * def resolvedAlerts = karate.filter(response, function(x){ return x.id == alertId })
    * print 'PASO 8: Alert status after resolution - remaining active:', resolvedAlerts.length
    # Alert should either be removed from active list or have its status changed
    * def stillPending = karate.filter(resolvedAlerts, function(x){ return x.status == 'PENDING' })
    And assert stillPending.length == 0
    * print 'PASO 8: Full lifecycle test PASSED - alert was successfully resolved'
