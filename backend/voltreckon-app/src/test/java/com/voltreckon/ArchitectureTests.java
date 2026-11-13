package com.voltreckon;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.modulith.core.ApplicationModule;
import org.springframework.modulith.core.ApplicationModules;
import org.springframework.modulith.core.DependencyDepth;
import org.springframework.modulith.core.DependencyType;

class ArchitectureTests {

    private final ApplicationModules modules = ApplicationModules.of(VoltReckonApplication.class);

    @Test
    void verifiesModuleBoundaries() {
        modules.verify();
    }

    @Test
    void modulesDoNotReadAnotherModulesInternalPackages() {
        List<String> violations = new ArrayList<>();

        for (ApplicationModule module : modules) {
            module.getDependencies(modules, DependencyDepth.ALL, DependencyType.values())
                    .stream()
                    .filter(dependency -> !module.equals(dependency.getTargetModule()))
                    .filter(dependency -> !dependency.getTargetModule().isExposed(dependency.getTargetType()))
                    .forEach(dependency -> violations.add("%s reads %s".formatted(
                            dependency.getSourceType().getName(), dependency.getTargetType().getName())));
        }

        assertThat(violations).isEmpty();
    }
}
