Feature: Mileage registration in fleet-service

  Background:
    * url fleetBaseUrl
    # Register a fresh vehicle for each scenario
    * def plate = 'KT' + java.util.UUID.randomUUID().toString().replace('-','').substring(0, 5).toUpperCase()
    * def vin = '1HGCM' + java.util.UUID.randomUUID().toString().replace('-','').substring(0, 12)
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

  @smoke @happy @regression
  Scenario: Successful mileage registration
    Given url fleetBaseUrl
    And path '/api/vehicles/' + plate + '/mileage'
    And request { "mileageValue": 1000, "recordedBy": "Juan Pérez" }
    When method POST
    Then status 201
    And match response.mileageValue == 1000
    And match response.currentMileage == 1000
    And match response.excessiveIncrement == false
    And match response.recordedBy == 'Juan Pérez'
    * print 'Mileage registered successfully:', response.mileageValue

  @regression @happy
  Scenario: Excessive increment (> 2000 km) is flagged
    # Register first mileage
    Given url fleetBaseUrl
    And path '/api/vehicles/' + plate + '/mileage'
    And request { "mileageValue": 5000, "recordedBy": "Operador A" }
    When method POST
    Then status 201

    # Register second mileage with excessive increment (3500 km diff)
    Given url fleetBaseUrl
    And path '/api/vehicles/' + plate + '/mileage'
    And request { "mileageValue": 8500, "recordedBy": "Operador A" }
    When method POST
    Then status 201
    And match response.excessiveIncrement == true
    * print 'Excessive increment correctly flagged, increment was 3500 km'

  @regression @negative
  Scenario: Mileage lower than current is rejected
    # Register initial mileage
    Given url fleetBaseUrl
    And path '/api/vehicles/' + plate + '/mileage'
    And request { "mileageValue": 5000, "recordedBy": "Operador A" }
    When method POST
    Then status 201

    # Try to register lower mileage
    Given url fleetBaseUrl
    And path '/api/vehicles/' + plate + '/mileage'
    And request { "mileageValue": 3000, "recordedBy": "Operador A" }
    When method POST
    Then status 400
    * print 'Lower mileage correctly rejected with status 400'
    * print 'Response:', response

  @regression @negative
  Scenario: Negative mileage value is rejected
    Given url fleetBaseUrl
    And path '/api/vehicles/' + plate + '/mileage'
    And request { "mileageValue": -100, "recordedBy": "Operador A" }
    When method POST
    Then status 400
    * print 'Negative mileage correctly rejected'

  @regression @negative
  Scenario: Mileage without recordedBy is rejected
    Given url fleetBaseUrl
    And path '/api/vehicles/' + plate + '/mileage'
    And request { "mileageValue": 5000 }
    When method POST
    Then status 400
    * print 'Request without recordedBy correctly rejected'

  @regression @negative
  Scenario: Mileage for non-existent plate returns 404
    Given url fleetBaseUrl
    And path '/api/vehicles/ZZZZZ99/mileage'
    And request { "mileageValue": 5000, "recordedBy": "Operador A" }
    When method POST
    Then status 404
    * print 'Non-existent plate correctly returned 404'

  @regression @happy @hu-05
  Scenario: HU-05 - Aceptar km igual al actual sin error
    # Precondición: vehículo registrado en el Background con currentMileage=0
    # Primero registrar km=45000
    Given url fleetBaseUrl
    And path '/api/vehicles', plate, 'mileage'
    And request { "mileageValue": 45000, "recordedBy": "María Torres" }
    When method POST
    Then status 201

    # Luego registrar exactamente el mismo km (debe aceptarse)
    Given url fleetBaseUrl
    And path '/api/vehicles', plate, 'mileage'
    And request { "mileageValue": 45000, "recordedBy": "María Torres" }
    When method POST
    Then status 201
    And match response.currentMileage == 45000
    And match response.excessiveIncrement == false
