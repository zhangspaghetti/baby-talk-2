package com.zhangspaghetti.babytalk.practice.generated;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.IOException;
import java.util.Arrays;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.Map;
import java.util.Set;
import org.junit.jupiter.api.Test;
import org.springframework.asm.ClassReader;
import org.springframework.asm.ClassVisitor;
import org.springframework.asm.FieldVisitor;
import org.springframework.asm.Handle;
import org.springframework.asm.MethodVisitor;
import org.springframework.asm.Opcodes;
import org.springframework.asm.Type;
import org.springframework.core.io.support.PathMatchingResourcePatternResolver;

class PracticeGeneratedContentMapperContractTest {

    private static final String COMMAND_MAPPER =
            "com/zhangspaghetti/babytalk/practice/generated/internal/PracticeGeneratedContentCommandMapper";
    private static final String AUDIT_MAPPER =
            "com/zhangspaghetti/babytalk/practice/generated/internal/PracticeGenerationAuditMapper";
    private static final String WRITE_SERVICE =
            "com/zhangspaghetti/babytalk/practice/generated/internal/PracticeGeneratedContentWriteService";

    @Test
    void queryMapperExposesQueriesOnly() {
        assertThat(PracticeGeneratedContentQueryMapper.class.getDeclaredMethods())
                .allMatch(method -> method.getName().startsWith("find")
                        || method.getName().startsWith("count"));
    }

    @Test
    void onlyInternalWriteServiceReferencesCommandMapper() throws IOException {
        var references = mapperReferences();

        assertThat(references.get(COMMAND_MAPPER)).containsExactly(WRITE_SERVICE);
    }

    @Test
    void webControllerAndDiscoveryDoNotReferenceMutationMappers() throws IOException {
        var references = mapperReferences();
        var forbiddenPrefixes = Set.of(
                "com/zhangspaghetti/babytalk/controller/",
                "com/zhangspaghetti/babytalk/practice/discovery/",
                "com/zhangspaghetti/babytalk/web/");

        assertThat(references.get(COMMAND_MAPPER))
                .noneMatch(owner -> forbiddenPrefixes.stream().anyMatch(owner::startsWith));
        assertThat(references.get(AUDIT_MAPPER))
                .noneMatch(owner -> forbiddenPrefixes.stream().anyMatch(owner::startsWith));
    }

    @Test
    void commandPortUsesTopLevelTypesAndTypedExceptionsExist() {
        assertThat(PracticeGeneratedContentCommands.class.getDeclaringClass()).isNull();
        assertThat(DraftReservation.class.getDeclaringClass()).isNull();
        assertThat(ReservationPolicy.class.getDeclaringClass()).isNull();
        assertThat(GenerationStartDecision.class.getDeclaringClass()).isNull();
        assertThat(PracticeGenerationRateLimitExceededException.class.getDeclaringClass()).isNull();
        assertThat(GeneratedContentIdConflictException.class.getDeclaringClass()).isNull();
    }

    @Test
    void auditMapperExposesOnlyFocusedInsertAndCompletionMethods() throws ClassNotFoundException {
        var auditMapper = Class.forName(AUDIT_MAPPER.replace('/', '.'));

        assertThat(Arrays.stream(auditMapper.getDeclaredMethods()).map(method -> method.getName()))
                .containsExactlyInAnyOrder(
                        "insertAttempt",
                        "completeAttempt",
                        "insertOperationRun",
                        "completeOperationRun",
                        "insertProviderCall",
                        "completeProviderCall",
                        "insertEvidenceBundle",
                        "insertEvidenceItems",
                        "insertJudgeResult");
    }

    private Map<String, Set<String>> mapperReferences() throws IOException {
        var references = new LinkedHashMap<String, Set<String>>();
        references.put(COMMAND_MAPPER, new LinkedHashSet<>());
        references.put(AUDIT_MAPPER, new LinkedHashSet<>());
        var resolver = new PathMatchingResourcePatternResolver();
        for (var resource : resolver.getResources(
                "classpath*:com/zhangspaghetti/babytalk/**/*.class")) {
            try (var input = resource.getInputStream()) {
                new ClassReader(input).accept(new ReferenceVisitor(references), ClassReader.SKIP_FRAMES);
            }
        }
        return references;
    }

    private static final class ReferenceVisitor extends ClassVisitor {
        private final Map<String, Set<String>> references;
        private String owner;

        private ReferenceVisitor(Map<String, Set<String>> references) {
            super(Opcodes.ASM9);
            this.references = references;
        }

        @Override
        public void visit(int version, int access, String name, String signature,
                          String superName, String[] interfaces) {
            owner = name;
            inspect(superName);
            if (interfaces != null) {
                for (var type : interfaces) {
                    inspect(type);
                }
            }
        }

        @Override
        public FieldVisitor visitField(int access, String name, String descriptor,
                                       String signature, Object value) {
            inspectDescriptor(descriptor);
            return null;
        }

        @Override
        public MethodVisitor visitMethod(int access, String name, String descriptor,
                                         String signature, String[] exceptions) {
            inspectDescriptor(descriptor);
            return new MethodVisitor(Opcodes.ASM9) {
                @Override
                public void visitTypeInsn(int opcode, String type) {
                    inspect(type);
                }

                @Override
                public void visitFieldInsn(int opcode, String targetOwner, String fieldName, String fieldDescriptor) {
                    inspect(targetOwner);
                    inspectDescriptor(fieldDescriptor);
                }

                @Override
                public void visitMethodInsn(int opcode, String targetOwner, String methodName,
                                            String methodDescriptor, boolean isInterface) {
                    inspect(targetOwner);
                    inspectDescriptor(methodDescriptor);
                }

                @Override
                public void visitInvokeDynamicInsn(String name, String descriptor,
                                                   Handle bootstrapMethodHandle, Object... bootstrapMethodArguments) {
                    inspectDescriptor(descriptor);
                }

                @Override
                public void visitLdcInsn(Object value) {
                    if (value instanceof Type type) {
                        inspectDescriptor(type.getDescriptor());
                    }
                }
            };
        }

        private void inspectDescriptor(String descriptor) {
            if (descriptor == null) {
                return;
            }
            for (var target : references.keySet()) {
                if (descriptor.contains(target)) {
                    references.get(target).add(owner);
                }
            }
        }

        private void inspect(String internalName) {
            if (internalName != null && references.containsKey(internalName)) {
                references.get(internalName).add(owner);
            }
        }
    }
}
