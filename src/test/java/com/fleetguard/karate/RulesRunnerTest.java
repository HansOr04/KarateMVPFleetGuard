package com.fleetguard.karate;

import com.intuit.karate.junit5.Karate;

class RulesRunnerTest {
    @Karate.Test
    Karate testRules() {
        return Karate.run("classpath:rules")
                .relativeTo(getClass());
    }
}
