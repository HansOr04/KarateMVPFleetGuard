Feature: Vehicle consultation by plate in fleet-service

  Background:
    * url fleetBaseUrl

  @smoke @happy @regression
  Scenario: Get existing vehicle by plate
    # First register a vehicle to query
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

    # Now query the vehicle
    Given path '/api/vehicles/' + plate
    When method GET
    Then status 200
    And match response.plate == plate
    And match response.brand == 'Toyota'
    And match response.status == 'ACTIVE'
    * print 'Successfully retrieved vehicle:', response.plate

  @regression @happy
  Scenario: Schema validation of vehicle response
    # Register a vehicle first
    * def plate = 'KT' + java.util.UUID.randomUUID().toString().replace('-','').substring(0, 5).toUpperCase()
    * def vin = '1HGCM' + java.util.UUID.randomUUID().toString().replace('-','').substring(0, 12)

    Given path '/api/vehicles'
    And request
      """
      {
        "plate": "#(plate)",
        "brand": "Toyota",
        "model": "RAV4",
        "year": 2024,
        "fuelType": "Hybrid",
        "vin": "#(vin)",
        "vehicleTypeId": "#(sedanTypeId)"
      }
      """
    When method POST
    Then status 201

    Given path '/api/vehicles/' + plate
    When method GET
    Then status 200
    And match response ==
      """
      {
        "id": "#uuid",
        "plate": "#string",
        "brand": "#string",
        "model": "#string",
        "year": "#number",
        "fuelType": "#string",
        "vin": "#string",
        "status": "#string",
        "currentMileage": "#number",
        "vehicleTypeName": "#string"
      }
      """
    * print 'Schema validation passed for vehicle:', response.plate

  @regression @negative
  Scenario: Get non-existent vehicle returns 404
    Given path '/api/vehicles/NOEXIST999'
    When method GET
    Then status 404
    * print 'Non-existent vehicle correctly returned 404'
