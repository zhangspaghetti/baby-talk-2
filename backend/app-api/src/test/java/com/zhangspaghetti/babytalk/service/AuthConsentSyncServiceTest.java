package com.zhangspaghetti.babytalk.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import com.zhangspaghetti.babytalk.web.ContractException;
import java.sql.Timestamp;
import java.time.Instant;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import com.zhangspaghetti.babytalk.AbstractIntegrationTest;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;

@SpringBootTest(properties = {
        "app.contract.min-supported-version=1.2.0",
        "app.contract.upgrade-url=https://download.example.com/babytalk.apk",
        "app.sms.provider-mode=dev",
        "app.sms.dev-code=246810"
})
class AuthConsentSyncServiceTest extends AbstractIntegrationTest {

    @Autowired
    private AuthConsentSyncService service;

    @Autowired
    private JdbcTemplate jdbcTemplate;

    @BeforeEach
    void resetTables() {
                resetDatabase(jdbcTemplate);
        jdbcTemplate.execute("delete from interaction_events");
        jdbcTemplate.execute("delete from consent_audit_logs");
        jdbcTemplate.execute("delete from sms_challenges");
        jdbcTemplate.execute("delete from account_sessions");
        jdbcTemplate.execute("delete from accounts");
    }

    @Test
    void syncBatchRollsBackWhenLaterRowViolatesDatabaseConstraint() {
        var session = createAcceptedSession("13800138000", "install-alpha");
        var tooLongLocalEventId = "x".repeat(110);

        assertThatThrownBy(() -> service.ingestEvents(
                session.sessionId(),
                "install-alpha",
                List.of(
                        new AuthConsentSyncService.SyncEventRequest(
                                "install-alpha:evt_ok",
                                "evt_ok",
                                "install-alpha",
                                "daily_care",
                                "bath_time",
                                "bath_time_warm_water",
                                "cooperating",
                                Instant.parse("2026-04-09T02:00:00Z")
                        ),
                        new AuthConsentSyncService.SyncEventRequest(
                                "install-alpha:" + tooLongLocalEventId,
                                tooLongLocalEventId,
                                "install-alpha",
                                "daily_care",
                                "bath_time",
                                "bath_time_splash_splash",
                                "cooperating",
                                Instant.parse("2026-04-09T02:01:00Z")
                        )
                )
        ))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.status()).isEqualTo(HttpStatus.BAD_REQUEST);
                    assertThat(contract.code()).isEqualTo("sync_batch_rejected");
                });

        assertThat(service.countInteractionEvents(session.accountId(), "install-alpha")).isZero();
        assertThat(service.countAllInteractionEvents()).isZero();
    }

    @Test
    void reloginAfterConsentRevokeNeedsFreshAcceptBeforeBootstrap() {
        var firstSession = createAcceptedSession("13800138000", "install-alpha");
        service.ingestEvents(
                firstSession.sessionId(),
                "install-alpha",
                List.of(
                        new AuthConsentSyncService.SyncEventRequest(
                                "install-alpha:evt_1",
                                "evt_1",
                                "install-alpha",
                                "daily_care",
                                "bath_time",
                                "bath_time_warm_water",
                                "cooperating",
                                Instant.parse("2026-04-09T03:00:00Z")
                        )
                )
        );
        service.revokeConsent(firstSession.sessionId(), "user_requested");

        var reloginSession = createSignedInSession("13800138000", "install-alpha");
        assertThat(reloginSession.consentStatus()).isEqualTo("revoked");
        assertThatThrownBy(() -> service.bootstrap(reloginSession.sessionId(), "install-alpha"))
                .isInstanceOf(ContractException.class)
                .satisfies(error -> {
                    var contract = (ContractException) error;
                    assertThat(contract.status()).isEqualTo(HttpStatus.CONFLICT);
                    assertThat(contract.code()).isEqualTo("consent_revoked");
                });

        service.acceptConsent(reloginSession.sessionId(), "pipl-v2");
        var bootstrap = service.bootstrap(reloginSession.sessionId(), "install-alpha");
        assertThat(bootstrap.eventCount()).isEqualTo(1);
        assertThat(bootstrap.events()).extracting(AuthConsentSyncService.BootstrapEvent::eventKey)
                .containsExactly("install-alpha:evt_1");

        var auditEntries = service.listAuditEntries(firstSession.accountId());
        assertThat(auditEntries)
                .extracting(entry -> entry.action() + ":" + entry.result())
                .containsExactly("accept:applied", "revoke:applied", "accept:applied");
    }

        @Test
        void verifyChallengeRejectsExpiredChallengeAndMarksItExpired() {
                var challenge = service.createChallenge("13800138000");
                jdbcTemplate.update(
                                "update sms_challenges set expires_at = ? where challenge_id = ?",
                                Timestamp.from(Instant.now().minusSeconds(60)),
                                challenge.challengeId()
                );

                assertThatThrownBy(() -> service.verifyChallenge(challenge.challengeId(), "246810", "install-alpha"))
                                .isInstanceOf(ContractException.class)
                                .satisfies(error -> {
                                        var contract = (ContractException) error;
                                        assertThat(contract.status()).isEqualTo(HttpStatus.BAD_REQUEST);
                                        assertThat(contract.code()).isEqualTo("challenge_expired");
                                        assertThat(contract.details()).containsEntry("retryable", true);
                                });
                                assertThat(jdbcTemplate.queryForObject("select count(*) from account_sessions", Integer.class)).isZero();
                                assertThat(jdbcTemplate.queryForObject("select count(*) from accounts", Integer.class)).isZero();
        }

        @Test
        void verifyChallengeRejectsWrongCodeWithoutBurningChallenge() {
                var challenge = service.createChallenge("13800138000");

                assertThatThrownBy(() -> service.verifyChallenge(challenge.challengeId(), "111111", "install-alpha"))
                                .isInstanceOf(ContractException.class)
                                .satisfies(error -> {
                                        var contract = (ContractException) error;
                                        assertThat(contract.status()).isEqualTo(HttpStatus.BAD_REQUEST);
                                        assertThat(contract.code()).isEqualTo("verification_code_invalid");
                                        assertThat(contract.details()).containsEntry("retryable", true);
                                });

                var session = service.verifyChallenge(challenge.challengeId(), "246810", "install-alpha");
                assertThat(session.accountId()).startsWith("acct_");
                assertThat(session.sessionId()).startsWith("sess_");
        }

        @Test
        void acceptConsentReturnsDuplicateWhenSessionAlreadyAccepted() {
                var session = createAcceptedSession("13800138000", "install-alpha");

                var duplicate = service.acceptConsent(session.sessionId(), "pipl-v1");

                assertThat(duplicate.applied()).isFalse();
                assertThat(duplicate.result()).isEqualTo("duplicate");
                assertThat(duplicate.consentStatus()).isEqualTo("accepted");
                assertThat(service.listAuditEntries(session.accountId()))
                                .extracting(entry -> entry.action() + ":" + entry.result())
                                .containsExactly("accept:applied", "accept:duplicate");
        }

        @Test
        void revokeConsentReturnsDuplicateWhenAccountAlreadyRevoked() {
                var session = createAcceptedSession("13800138000", "install-alpha");
                var firstRevoke = service.revokeConsent(session.sessionId(), "user_requested");

                var duplicate = service.revokeConsent(session.sessionId(), "user_requested_again");

                assertThat(firstRevoke.applied()).isTrue();
                assertThat(duplicate.applied()).isFalse();
                assertThat(duplicate.result()).isEqualTo("duplicate");
                assertThat(duplicate.consentStatus()).isEqualTo("revoked");
                assertThat(service.listAuditEntries(session.accountId()))
                                .extracting(entry -> entry.action() + ":" + entry.result())
                                .containsExactly("accept:applied", "revoke:applied", "revoke:duplicate");
        }

            @Test
            void ingestEventsRejectsInvalidReactionTypeBeforeAnyWrite() {
                var session = createAcceptedSession("13800138000", "install-alpha");

                for (var reactionType : List.of("surprised", "calm", "engaged", "imitated", "needs_break")) {
                    assertThatThrownBy(() -> service.ingestEvents(
                            session.sessionId(),
                            "install-alpha",
                            List.of(
                                    new AuthConsentSyncService.SyncEventRequest(
                                            "install-alpha:evt_invalid_reaction_" + reactionType,
                                            "evt_invalid_reaction_" + reactionType,
                                            "install-alpha",
                                            "daily_care",
                                            "bath_time",
                                            "bath_time_warm_water",
                                            reactionType,
                                            Instant.parse("2026-04-09T04:00:00Z")
                                    )
                            )
                    ))
                            .isInstanceOf(ContractException.class)
                            .satisfies(error -> {
                                var contract = (ContractException) error;
                                assertThat(contract.status()).isEqualTo(HttpStatus.BAD_REQUEST);
                                assertThat(contract.code()).isEqualTo("invalid_reaction_type");
                            });
                }

                assertThat(service.countInteractionEvents(session.accountId(), "install-alpha")).isZero();
            }

            @Test
            void ingestEventsRejectsMissingClientTimestampBeforeAnyWrite() {
                var session = createAcceptedSession("13800138000", "install-alpha");

                assertThatThrownBy(() -> service.ingestEvents(
                        session.sessionId(),
                        "install-alpha",
                        List.of(
                                new AuthConsentSyncService.SyncEventRequest(
                                        "install-alpha:evt_missing_timestamp",
                                        "evt_missing_timestamp",
                                        "install-alpha",
                                        "daily_care",
                                        "bath_time",
                                        "bath_time_warm_water",
                                        "cooperating",
                                        null
                                )
                        )
                ))
                        .isInstanceOf(ContractException.class)
                        .satisfies(error -> {
                            var contract = (ContractException) error;
                            assertThat(contract.status()).isEqualTo(HttpStatus.BAD_REQUEST);
                            assertThat(contract.code()).isEqualTo("missing_client_timestamp");
                        });

                assertThat(service.countInteractionEvents(session.accountId(), "install-alpha")).isZero();
            }

    private AuthConsentSyncService.SessionResponse createSignedInSession(String phoneNumber, String installationId) {
        var challenge = service.createChallenge(phoneNumber);
        return service.verifyChallenge(challenge.challengeId(), "246810", installationId);
    }

    private AuthConsentSyncService.SessionResponse createAcceptedSession(String phoneNumber, String installationId) {
        var session = createSignedInSession(phoneNumber, installationId);
        service.acceptConsent(session.sessionId(), "pipl-v1");
        return session;
    }
}
