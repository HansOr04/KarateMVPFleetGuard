Feature: Alert consultation in rules-alerts-service

  Background:
    * url rulesBaseUrl

  @smoke @regression
  Scenario: List all active alerts
    Given path '/api/alerts'
    When method GET
    Then status 200
    And match response == '#array'
    * print 'Total alerts returned:', response.length

  @regression @happy
  Scenario: Filter alerts by PENDING status
    Given path '/api/alerts'
    And param status = 'PENDING'
    When method GET
    Then status 200
    And match response == '#array'
    * def pendingOnly = karate.filter(response, function(x){ return x.status != 'PENDING' })
    And assert pendingOnly.length == 0
    * print 'All returned alerts are PENDING, count:', response.length

  @regression @happy
  Scenario: Schema validation of alert response
    Given path '/api/alerts'
    When method GET
    Then status 200
    And match response == '#array'
    * def alerts = response
    * if (alerts.length > 0) karate.call('classpath:rules/validate-alert-schema.feature', { alert: alerts[0] })
    * print 'Schema validation completed for alerts'
