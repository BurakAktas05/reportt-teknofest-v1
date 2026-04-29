package com.reportt.complaintapp.config;

import org.springframework.boot.context.properties.ConfigurationProperties;
import org.springframework.validation.annotation.Validated;

/**
 * Güven puanı ve güvenilir vatandaş kural motoru yapılandırması.
 *
 * <p>Eşik değerinin üstünde puana sahip vatandaşlar, AI analiz sürecini
 * atlayarak doğrudan {@code SUBMITTED} statüsüne yönlendirilir.</p>
 */
@Validated
@ConfigurationProperties(prefix = "app.trust")
public record TrustScoreProperties(
        /** Analiz bypass eşiği — bu skorun üstündeki vatandaşlar güvenilir sayılır. */
        int bypassThreshold,
        /** Bypass için gereken minimum doğrulanmış ihbar sayısı. */
        int minimumVerifiedReports
) {
}
