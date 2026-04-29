package com.reportt.complaintapp.domain;

import com.reportt.complaintapp.domain.enums.UserRole;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.JoinColumn;
import jakarta.persistence.ManyToOne;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;
import org.hibernate.annotations.NotFound;
import org.hibernate.annotations.NotFoundAction;

@Getter
@Setter
@Entity
@Table(name = "app_user")
public class UserAccount extends BaseEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false, length = 120)
    private String fullName;

    @Column(nullable = false, unique = true, length = 20)
    private String phoneNumber;

    @Column(unique = true, length = 120)
    private String email;

    @Column(nullable = false)
    private String passwordHash;

    @Enumerated(EnumType.STRING)
    @Column(nullable = false, length = 20)
    private UserRole role;

    @Column(nullable = false)
    private Integer reputationScore = 0;

    @Column(nullable = false)
    private boolean enabled = true;

    @ManyToOne
    @JoinColumn(name = "station_id")
    @NotFound(action = NotFoundAction.IGNORE)
    private PoliceStation assignedStation;

    // ── V2: Güven Puanı Sayaçları (Modül 5) ─────────────────

    /** Doğrulanmış (VERIFIED) ihbar sayısı. */
    @Column(nullable = false)
    private int verifiedReportCount = 0;

    /** Reddedilmiş ihbar sayısı. */
    @Column(nullable = false)
    private int rejectedReportCount = 0;

    // ── V3: Firebase Cloud Messaging ─────────────────────────

    /** FCM cihaz token'ı — push bildirim göndermek için kullanılır. */
    @Column(name = "fcm_token", columnDefinition = "TEXT")
    private String fcmToken;
}
