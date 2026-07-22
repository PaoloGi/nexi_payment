package com.paologi.nexi_payment_example;

import static org.junit.Assert.fail;

import androidx.test.platform.app.InstrumentationRegistry;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.junit.runners.Parameterized;

import pl.leancode.patrol.PatrolJUnitRunner;
import pl.leancode.patrol.contracts.Contracts.RunDartTestResponse;
import pl.leancode.patrol.contracts.Contracts.RunDartTestResponseResult;

/**
 * Entry point for the Patrol integration tests: every Dart test declared with
 * patrolTest() is surfaced here as a separate JUnit test case.
 */
@RunWith(Parameterized.class)
public class MainActivityTest {

    @Parameterized.Parameters(name = "{0}")
    public static Object[] testCases() {
        PatrolJUnitRunner instrumentation =
                (PatrolJUnitRunner) InstrumentationRegistry.getInstrumentation();
        instrumentation.setUp(MainActivity.class);
        instrumentation.waitForPatrolAppService();
        return instrumentation.listDartTests();
    }

    private final String dartTestName;

    public MainActivityTest(String dartTestName) {
        this.dartTestName = dartTestName;
    }

    @Test
    public void runDartTest() {
        PatrolJUnitRunner instrumentation =
                (PatrolJUnitRunner) InstrumentationRegistry.getInstrumentation();
        RunDartTestResponse response = instrumentation.runDartTest(dartTestName);
        if (response.getResult() == RunDartTestResponseResult.failure) {
            fail(response.getDetails());
        }
    }
}
