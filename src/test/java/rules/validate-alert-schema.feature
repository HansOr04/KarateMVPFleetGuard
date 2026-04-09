@ignore
Feature: Alert schema validation helper

  Scenario: Validate alert schema
    * match alert ==
      """
      {
        "id": "#uuid",
        "vehicleId": "#uuid",
        "vehicleTypeId": "#uuid",
        "ruleId": "#uuid",
        "ruleName": "#string",
        "status": "#string",
        "dueAtKm": "#number",
        "triggeredAt": "##string",
        "resolvedAt": "##string"
      }
      """
    * print 'Alert schema validated successfully for id:', alert.id
