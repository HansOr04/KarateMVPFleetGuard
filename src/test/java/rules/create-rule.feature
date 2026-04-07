Feature: Maintenance rule creation in rules-alerts-service

  Background:
    * url rulesBaseUrl

  @smoke @happy @regression
  Scenario: Create preventive maintenance rule successfully
    * def ruleName = "Cambio de aceite " + java.util.UUID.randomUUID().toString().substring(0, 5)
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
    And match response.name == ruleName
    And match response.status == 'ACTIVE'
    And match response.intervalKm == 10000
    And match response.warningThresholdKm == 500
    And match response.id == '#uuid'
    * print 'Created preventive rule:', response.id

  @regression @happy
  Scenario: Create corrective maintenance rule
    * def ruleName = "Reparación de frenos " + java.util.UUID.randomUUID().toString().substring(0, 5)
    Given path '/api/maintenance-rules'
    And request
      """
      {
        "name": "#(ruleName)",
        "maintenanceType": "CORRECTIVE",
        "intervalKm": 15000,
        "warningThresholdKm": 1000
      }
      """
    When method POST
    Then status 201
    And match response.maintenanceType == 'CORRECTIVE'
    And match response.id == '#uuid'
    * print 'Created corrective rule:', response.id

  @regression @happy
  Scenario: Create rule without warningThresholdKm uses default 500
    * def ruleName = "Revisión de llantas " + java.util.UUID.randomUUID().toString().substring(0, 5)
    Given path '/api/maintenance-rules'
    And request
      """
      {
        "name": "#(ruleName)",
        "maintenanceType": "PREVENTIVE",
        "intervalKm": 8000
      }
      """
    When method POST
    Then status 201
    And match response.warningThresholdKm == 500
    * print 'Default warningThresholdKm applied:', response.warningThresholdKm

  @regression @negative
  Scenario: Rule without name is rejected
    Given path '/api/maintenance-rules'
    And request
      """
      {
        "maintenanceType": "PREVENTIVE",
        "intervalKm": 10000,
        "warningThresholdKm": 500
      }
      """
    When method POST
    Then status 400
    * print 'Rule without name correctly rejected'

  @regression @negative
  Scenario: Rule without intervalKm is rejected
    Given path '/api/maintenance-rules'
    And request
      """
      {
        "name": "Sin intervalo",
        "maintenanceType": "PREVENTIVE",
        "warningThresholdKm": 500
      }
      """
    When method POST
    Then status 400
    * print 'Rule without intervalKm correctly rejected'

  @regression @negative
  Scenario: Rule with intervalKm equals zero is rejected
    Given path '/api/maintenance-rules'
    And request
      """
      {
        "name": "Intervalo cero",
        "maintenanceType": "PREVENTIVE",
        "intervalKm": 0,
        "warningThresholdKm": 500
      }
      """
    When method POST
    Then status 400
    * print 'Rule with intervalKm=0 correctly rejected'
