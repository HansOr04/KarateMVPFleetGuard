package com.fleetguard.karate;

import com.intuit.karate.junit5.Karate;

class KarateRunnerTest {
    @Karate.Test
    Karate testAll() {
        return Karate.run("classpath:fleet", "classpath:rules", "classpath:integration")
                .relativeTo(getClass());
    }
}
