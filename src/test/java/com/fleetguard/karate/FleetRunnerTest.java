package com.fleetguard.karate;

import com.intuit.karate.junit5.Karate;

class FleetRunnerTest {
    @Karate.Test
    Karate testFleet() {
        return Karate.run("classpath:fleet")
                .relativeTo(getClass());
    }
}
