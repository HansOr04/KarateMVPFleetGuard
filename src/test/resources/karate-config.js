function fn() {
  var env = karate.env;
  karate.log('karate.env system property was:', env);

  if (!env) { env = 'local'; }

  var config = {
    env: env,
    fleetBaseUrl: 'http://localhost:8082',
    rulesBaseUrl: 'http://localhost:8083',
    // Seed data — vehicle type IDs from Flyway V2 migration
    sedanTypeId: 'c1a1d13e-b3df-4fab-9584-890b852d5311',
    suvTypeId: 'c1a1d13e-b3df-4fab-9584-890b852d5313',
    pickupTypeId: 'c1a1d13e-b3df-4fab-9584-890b852d5315'
  };

  if (env === 'docker') {
    config.fleetBaseUrl = 'http://fleet-service:8080';
    config.rulesBaseUrl = 'http://rules-alerts-service:8080';
  }

  karate.configure('connectTimeout', 10000);
  karate.configure('readTimeout', 10000);
  karate.configure('headers', { 'Content-Type': 'application/json' });

  return config;
}
