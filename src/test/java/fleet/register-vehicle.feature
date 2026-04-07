Feature: Vehicle registration in fleet-service

  Background:
    * url fleetBaseUrl

  @smoke @happy @regression
  Scenario: Successful vehicle registration with complete data
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
    And match response.plate == plate
    And match response.status == 'ACTIVE'
    And match response.currentMileage == 0
    And match response.id == '#uuid'
    And match response.vehicleTypeName == 'Sedan'
    * print 'Created vehicle:', response.plate

  @regression @negative
  Scenario: Registration with duplicate plate is rejected
    * def plate = 'KT' + java.util.UUID.randomUUID().toString().replace('-','').substring(0, 5).toUpperCase()
    * def vin1 = '1HGCM' + java.util.UUID.randomUUID().toString().replace('-','').substring(0, 12)
    * def vin2 = '2HGCM' + java.util.UUID.randomUUID().toString().replace('-','').substring(0, 12)

    # First registration
    Given path '/api/vehicles'
    And request
      """
      {
        "plate": "#(plate)",
        "brand": "Toyota",
        "model": "Corolla",
        "year": 2023,
        "fuelType": "Gasoline",
        "vin": "#(vin1)",
        "vehicleTypeId": "#(sedanTypeId)"
      }
      """
    When method POST
    Then status 201

    # Duplicate plate attempt
    Given path '/api/vehicles'
    And request
      """
      {
        "plate": "#(plate)",
        "brand": "Honda",
        "model": "Civic",
        "year": 2022,
        "fuelType": "Gasoline",
        "vin": "#(vin2)",
        "vehicleTypeId": "#(sedanTypeId)"
      }
      """
    When method POST
    Then status 400
    And match response.message contains 'already exists'
    * print 'Duplicate plate correctly rejected for:', plate

  @regression @negative
  Scenario: Registration without required field (plate) is rejected
    * def vin = '1HGCM' + java.util.UUID.randomUUID().toString().replace('-','').substring(0, 12)

    Given path '/api/vehicles'
    And request
      """
      {
        "brand": "Toyota",
        "model": "Corolla",
        "year": 2023,
        "fuelType": "Gasoline",
        "vin": "#(vin)",
        "vehicleTypeId": "#(sedanTypeId)"
      }
      """
    When method POST
    Then status 400
    * print 'Request without plate correctly rejected with status 400'

  @regression @negative
  Scenario: Registration with invalid VIN (16 characters) is rejected
    * def plate = 'KT' + java.util.UUID.randomUUID().toString().replace('-','').substring(0, 5).toUpperCase()

    Given path '/api/vehicles'
    And request
      """
      {
        "plate": "#(plate)",
        "brand": "Toyota",
        "model": "Corolla",
        "year": 2023,
        "fuelType": "Gasoline",
        "vin": "1234567890123456",
        "vehicleTypeId": "#(sedanTypeId)"
      }
      """
    When method POST
    Then status 400
    * print 'Invalid VIN (16 chars) correctly rejected'

  @regression @negative
  Scenario: Registration with non-existent vehicleTypeId is rejected
    * def plate = 'KT' + java.util.UUID.randomUUID().toString().replace('-','').substring(0, 5).toUpperCase()
    * def vin = '1HGCM' + java.util.UUID.randomUUID().toString().replace('-','').substring(0, 12)
    * def fakeTypeId = java.util.UUID.randomUUID().toString()

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
        "vehicleTypeId": "#(fakeTypeId)"
      }
      """
    When method POST
    Then status 404
    * print 'Non-existent vehicleTypeId correctly rejected'
