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
        "app.contract.consent-version=pipl-v1",
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

        service.acceptConsent(reloginSession.sessionId(), "pipl-v1");
        var bootstrap = service.bootstrap(reloginSession.sessionId(), "install-alpha");
        var storedInstallationReference = jdbcTemplate.queryForObject(
                "select installation_id from interaction_events where account_id = ? and local_event_id = ?",
                String.class,
                firstSession.accountId(),
                "evt_1"
        );
        assertThat(bootstrap.eventCount()).isEqualTo(1);
        assertThat(bootstrap.events()).extracting(AuthConsentSyncService.BootstrapEvent::eventKey)
                .containsExactly(storedInstallationReference + ":evt_1");
        assertThat(bootstrap.events()).singleElement()
                .satisfies(event -> assertThat(event.installationId()).isEqualTo(storedInstallationReference));

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
	        void persistsOnlyProtectedPhoneReferenceAndOtpVerifier() {
	                var challenge = service.createChallenge("13800138000");

	                var row = jdbcTemplate.queryForMap(
	                                "select phone_lookup_ref, phone_mask, verification_verifier from sms_challenges where challenge_id = ?",
	                                challenge.challengeId()
	                );
	                assertThat(row.get("phone_lookup_ref").toString()).doesNotContain("13800138000");
	                assertThat(row.get("phone_mask")).isEqualTo("138****8000");
	                assertThat(row.get("verification_verifier").toString())
	                                .startsWith("v1:")
	                                .doesNotContain("246810");

	                var session = service.verifyChallenge(challenge.challengeId(), "246810", "install-alpha");
	                var accountLookupRef = jdbcTemplate.queryForObject(
	                                "select phone_lookup_ref from accounts where account_id = ?",
	                                String.class,
	                                session.accountId()
	                );
	                assertThat(accountLookupRef).isEqualTo(row.get("phone_lookup_ref"));
	        }

        @Test
        void persistsOnlyProtectedInstallationReferencesInSessionAndConsentAudit() {
                var session = createAcceptedSession("13800138000", "install-alpha");

                var storedSessionInstallationId = jdbcTemplate.queryForObject(
                                "select installation_id from account_sessions where session_id = ?",
                                String.class,
                                session.sessionId()
                );
                var storedAuditInstallationId = jdbcTemplate.queryForObject(
                                "select installation_id from consent_audit_logs where account_id = ?",
                                String.class,
                                session.accountId()
                );

                assertThat(storedSessionInstallationId)
                                .startsWith("v1:")
                                .doesNotContain("install-alpha");
                assertThat(storedAuditInstallationId).isEqualTo(storedSessionInstallationId);
                assertThat(service.listAuditEntries(session.accountId()))
                                .extracting(AuthConsentSyncService.AuditEntry::installationId)
                                .containsExactly(storedAuditInstallationId);
        }

        @Test
        void persistsOnlyProtectedInstallationReferencesInInteractionEventsAndBootstrapKeepsWireContract() {
                var session = createAcceptedSession("13800138000", "install-alpha");

                service.ingestEvents(
                                session.sessionId(),
                                "install-alpha",
                                List.of(new AuthConsentSyncService.SyncEventRequest(
                                                "install-alpha:privacy-event-1",
                                                "privacy-event-1",
                                                "install-alpha",
                                                "daily_care",
                                                "bath_time",
                                                "bath_time_warm_water",
                                                "cooperating",
                                                Instant.parse("2026-04-09T02:30:00Z")
                                ))
                );

                var storedEventKey = jdbcTemplate.queryForObject(
                                "select event_key from interaction_events where account_id = ? and local_event_id = ?",
                                String.class,
                                session.accountId(),
                                "privacy-event-1"
                );
                var storedInstallationReference = jdbcTemplate.queryForObject(
                                "select installation_id from interaction_events where account_id = ? and local_event_id = ?",
                                String.class,
                                session.accountId(),
                                "privacy-event-1"
                );
                assertThat(storedEventKey)
                                .startsWith("e1:")
                                .doesNotContain("install-alpha:privacy-event-1");
                assertThat(storedInstallationReference)
                                .startsWith("v1:")
                                .doesNotContain("install-alpha");
                assertThat(service.countInteractionEvents(session.accountId(), "install-alpha")).isEqualTo(1);

                var bootstrap = service.bootstrap(session.sessionId(), "install-alpha");
                assertThat(bootstrap.events())
                                .singleElement()
                                .satisfies(event -> {
                                        assertThat(event.installationId()).isEqualTo(storedInstallationReference);
                                        assertThat(event.eventKey())
                                                        .isEqualTo(storedInstallationReference + ":privacy-event-1")
                                                        .doesNotContain("install-alpha");
                                });
        }

        @Test
        void historicalRawEventReplayIsAcceptedUnderFreshReferenceAfterV36Disposal() {
                var session = createAcceptedSession("13800138000", "install-alpha");
                var historicalEventKey = "legacy-disposed:00000000-0000-0000-0000-000000000001";
                var historicalInstallationReference = "legacy-disposed:00000000-0000-0000-0000-000000000002";
                jdbcTemplate.update(
                                """
                                insert into interaction_events (
                                    event_key, account_id, session_id, installation_id, local_event_id,
                                    space_id, activity_id, phrase_id, reaction_type, client_timestamp, received_at
                                ) values (?, ?, ?, ?, ?, 'daily_care', 'bath_time', 'bath_time_warm_water', 'cooperating', ?, ?)
                                """,
                                historicalEventKey,
                                session.accountId(),
                                session.sessionId(),
                                historicalInstallationReference,
                                "historical-event",
                                Timestamp.from(Instant.parse("2026-04-09T02:30:00Z")),
                                Timestamp.from(Instant.parse("2026-04-09T02:30:00Z"))
                );

                var replay = service.ingestEvents(
                                session.sessionId(),
                                "install-alpha",
                                List.of(new AuthConsentSyncService.SyncEventRequest(
                                                "install-alpha:historical-event",
                                                "historical-event",
                                                "install-alpha",
                                                "daily_care",
                                                "bath_time",
                                                "bath_time_warm_water",
                                                "cooperating",
                                                Instant.parse("2026-04-09T02:30:00Z")
                                ))
                );

                assertThat(replay.acceptedEventKeys()).containsExactly("install-alpha:historical-event");
                assertThat(replay.duplicateEventKeys()).isEmpty();
                assertThat(service.countAllInteractionEvents()).isEqualTo(2);
                assertThat(jdbcTemplate.queryForObject(
                                "select count(*) from interaction_events where event_key = ?",
                                Integer.class,
                                "install-alpha:historical-event"
                )).isZero();
                assertThat(jdbcTemplate.queryForObject(
                                "select event_key from interaction_events where local_event_id = ? order by received_at desc limit 1",
                                String.class,
                                "historical-event"
                )).startsWith("e1:");
        }

        @Test
        void revokeRedactsLegacyRawInstallationReferencesAndKeepsAuditReadable() {
                var session = createAcceptedSession("13800138000", "install-alpha");
                jdbcTemplate.update(
                                "update account_sessions set installation_id = 'legacy-session-install' where session_id = ?",
                                session.sessionId()
                );
                jdbcTemplate.update(
                                "update consent_audit_logs set installation_id = 'legacy-audit-install' where account_id = ?",
                                session.accountId()
                );

                service.revokeConsent(session.sessionId(), "user_requested");

                assertThat(jdbcTemplate.queryForObject(
                                "select installation_id from account_sessions where session_id = ?",
                                String.class,
                                session.sessionId()
                )).isEqualTo("redacted");
                assertThat(jdbcTemplate.queryForObject(
                                "select count(*) from consent_audit_logs where account_id = ? and installation_id in ('legacy-session-install', 'legacy-audit-install')",
                                Integer.class,
                                session.accountId()
                )).isZero();
                assertThat(service.listAuditEntries(session.accountId()))
                                .extracting(AuthConsentSyncService.AuditEntry::reason)
                                .containsExactly("consent_version:pipl-v1", "server_sync_revoked");
        }

	        @Test
	        void wrongOtpExpiresChallengeAfterFiveAttempts() {
	                var challenge = service.createChallenge("13800138000");

	                for (int attempt = 0; attempt < 5; attempt++) {
	                        assertThatThrownBy(() -> service.verifyChallenge(challenge.challengeId(), "111111", "install-alpha"))
	                                        .isInstanceOf(ContractException.class)
	                                        .satisfies(error -> {
	                                            var contract = (ContractException) error;
	                                            assertThat(contract.code()).isEqualTo("verification_code_invalid");
	                                        });
	                }

	                assertThat(jdbcTemplate.queryForObject(
	                                "select status from sms_challenges where challenge_id = ?",
	                                String.class,
	                                challenge.challengeId()
	                )).isEqualTo("expired");
	                assertThatThrownBy(() -> service.verifyChallenge(challenge.challengeId(), "246810", "install-alpha"))
	                                .isInstanceOf(ContractException.class)
	                                .satisfies(error -> assertThat(((ContractException) error).code()).isEqualTo("challenge_expired"));
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
        void lifecycleAuditRetainsOnlySafeEffectCodes() {
                var session = createAcceptedSession("13800138000", "install-alpha");
                service.revokeConsent(session.sessionId(), "宝宝姓名和家庭地址不得写入审计");
                var relogin = createSignedInSession("13800138000", "install-alpha");
                service.acceptConsent(relogin.sessionId(), "pipl-v1");
                service.deleteAccount(relogin.sessionId(), "删除原因包含私密内容");

                assertThat(service.listAuditEntries(session.accountId()))
                                .extracting(AuthConsentSyncService.AuditEntry::reason)
                                .containsExactly(
                                                "consent_version:pipl-v1",
                                                "server_sync_revoked",
                                                "consent_version:pipl-v1",
                                                "account_owned_server_data_deleted"
                                )
                                .noneMatch(reason -> reason.contains("宝宝") || reason.contains("私密"));
            }

            @Test
            void rejectsUnpublishedConsentVersionWithoutChangingConsentOrAudit() {
                var session = createSignedInSession("13800138000", "install-alpha");
                var initialStatus = jdbcTemplate.queryForObject(
                                "select latest_consent_status from accounts where account_id = ?",
                                String.class,
                                session.accountId()
                );

                assertThatThrownBy(() -> service.acceptConsent(session.sessionId(), "pipl-v2"))
                                .isInstanceOf(ContractException.class)
                                .satisfies(error -> {
                                    var contract = (ContractException) error;
                                    assertThat(contract.status()).isEqualTo(HttpStatus.BAD_REQUEST);
                                    assertThat(contract.code()).isEqualTo("unsupported_consent_version");
                                });

                assertThat(jdbcTemplate.queryForObject(
                                "select latest_consent_status from accounts where account_id = ?",
                                String.class,
                                session.accountId()
                )).isEqualTo(initialStatus);
                assertThat(service.listAuditEntries(session.accountId())).isEmpty();
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

            @Test
            void repeatedCareTurnAndReactionSyncAreIdempotent() {
                var session = createAcceptedSession("13800138000", "install-alpha");
                var events = List.of(
                        new AuthConsentSyncService.SyncEventRequest(
                                "install-alpha:care-turn-1",
                                "care-turn-1",
                                "install-alpha",
                                "daily_care",
                                "bath_time",
                                "bath_time_warm_water",
                                "cooperating",
                                Instant.parse("2026-04-09T03:00:00Z")
                        ),
                        new AuthConsentSyncService.SyncEventRequest(
                                "install-alpha:baby-reaction-1",
                                "baby-reaction-1",
                                "install-alpha",
                                "daily_care",
                                "bath_time",
                                "bath_time_splash_splash",
                                "hesitant",
                                Instant.parse("2026-04-09T03:01:00Z")
                        )
                );

                var first = service.ingestEvents(session.sessionId(), "install-alpha", events);
                var replay = service.ingestEvents(session.sessionId(), "install-alpha", events);

                assertThat(first.acceptedCount()).isEqualTo(2);
                assertThat(replay.acceptedCount()).isZero();
                assertThat(replay.duplicateEventKeys())
                        .containsExactly("install-alpha:care-turn-1", "install-alpha:baby-reaction-1");
                assertThat(service.countInteractionEvents(session.accountId(), "install-alpha")).isEqualTo(2);
            }

            @Test
            void eventKeyIdempotencyIsScopedToAccount() {
                var firstAccount = createAcceptedSession("13800138000", "install-shared");
                var secondAccount = createAcceptedSession("13900139000", "install-shared");
                var event = new AuthConsentSyncService.SyncEventRequest(
                                "install-shared:shared-event-1",
                                "shared-event-1",
                                "install-shared",
                                "daily_care",
                                "bath_time",
                                "bath_time_warm_water",
                                "cooperating",
                                Instant.parse("2026-04-09T03:30:00Z")
                );

                var first = service.ingestEvents(firstAccount.sessionId(), "install-shared", List.of(event));
                var second = service.ingestEvents(secondAccount.sessionId(), "install-shared", List.of(event));

                assertThat(first.acceptedCount()).isEqualTo(1);
                assertThat(second.acceptedCount()).isEqualTo(1);
                assertThat(second.duplicateCount()).isZero();
                assertThat(service.countAllInteractionEvents()).isEqualTo(2);
        }

            @Test
            void bootstrapRestoresAllAccountEventsOnNewDeviceWithoutCrossAccountLeakage() {
                var firstDevice = createAcceptedSession("13800138000", "install-alpha");
                service.ingestEvents(
                        firstDevice.sessionId(),
                        "install-alpha",
                        List.of(new AuthConsentSyncService.SyncEventRequest(
                                "install-alpha:care-turn-1",
                                "care-turn-1",
                                "install-alpha",
                                "daily_care",
                                "bath_time",
                                "bath_time_warm_water",
                                "cooperating",
                                Instant.parse("2026-04-09T03:00:00Z")
                        ))
                );
                var secondDevice = createSignedInSession("13800138000", "install-beta");
                var otherAccount = createAcceptedSession("13900139000", "install-gamma");
                service.ingestEvents(
                        otherAccount.sessionId(),
                        "install-gamma",
                        List.of(new AuthConsentSyncService.SyncEventRequest(
                                "install-gamma:foreign-event-1",
                                "foreign-event-1",
                                "install-gamma",
                                "daily_care",
                                "bath_time",
                                "bath_time_splash_splash",
                                "resisting",
                                Instant.parse("2026-04-09T03:02:00Z")
                        ))
                );

                var restored = service.bootstrap(secondDevice.sessionId(), "install-beta");

                assertThat(restored.eventCount()).isEqualTo(1);
                assertThat(restored.events()).extracting(AuthConsentSyncService.BootstrapEvent::eventKey)
                        .singleElement()
                        .satisfies(eventKey -> {
                                assertThat(eventKey).startsWith("v1:").doesNotContain("install-alpha");
                                assertThat(eventKey).endsWith(":care-turn-1");
                        });
                assertThat(restored.events()).singleElement().satisfies(event -> {
                        assertThat(event.installationId()).startsWith("v1:").doesNotContain("install-alpha");
                        assertThat(event.eventKey()).isEqualTo(event.installationId() + ":care-turn-1");
                });
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
