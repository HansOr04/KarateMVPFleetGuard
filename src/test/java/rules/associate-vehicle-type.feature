Feature: Associate maintenance rule to vehicle type

  Background:
    * url rulesBaseUrl
    # Create a fresh rule for each scenario
    * def ruleName = "Regla test " + java.util.UUID.randomUUID().toString().substring(0, 8)
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
    * print 'Background: created rule:', ruleId

  @smoke @happy @regression
  Scenario: Successful association of rule to vehicle type
    Given url rulesBaseUrl
    And path '/api/maintenance-rules/' + ruleId + '/vehicle-types'
    And request { "vehicleTypeId": "#(sedanTypeId)" }
    When method POST
    Then status 201
    And match response.ruleId == ruleId
    And match response.vehicleTypeId == sedanTypeId
    * print 'Successfully associated rule', ruleId, 'to vehicle type', sedanTypeId

  @regression @negative
  Scenario: Duplicate association is rejected with 409
    # First association
    Given url rulesBaseUrl
    And path '/api/maintenance-rules/' + ruleId + '/vehicle-types'
    And request { "vehicleTypeId": "#(sedanTypeId)" }
    When method POST
    Then status 201

    # Duplicate association
    Given url rulesBaseUrl
    And path '/api/maintenance-rules/' + ruleId + '/vehicle-types'
    And request { "vehicleTypeId": "#(sedanTypeId)" }
    When method POST
    Then status 409
    And match response.message contains 'asociada'
    * print 'Duplicate association correctly rejected with 409'

  @regression @negative
  Scenario: Association with non-existent rule returns 404
    * def fakeRuleId = java.util.UUID.randomUUID().toString()
    Given url rulesBaseUrl
    And path '/api/maintenance-rules/' + fakeRuleId + '/vehicle-types'
    And request { "vehicleTypeId": "#(sedanTypeId)" }
    When method POST
    Then status 404
    * print 'Non-existent rule correctly returned 404'

  @regression @negative
  Scenario: Association without vehicleTypeId is rejected
    Given url rulesBaseUrl
    And path '/api/maintenance-rules/' + ruleId + '/vehicle-types'
    And request {}
    When method POST
    Then status 400
    * print 'Request without vehicleTypeId correctly rejected'
