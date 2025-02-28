;; GamePulse - Gaming Analytics Platform

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-unauthorized (err u101))
(define-constant err-invalid-game (err u102))
(define-constant err-invalid-achievement (err u103))
(define-constant err-already-unlocked (err u104))
(define-constant err-invalid-season (err u105))
(define-constant err-invalid-duration (err u106))
(define-constant err-rate-limit (err u107))

;; Data Variables
(define-map authorized-games principal bool)
(define-map player-stats
    { game-id: principal, player-id: principal }
    { 
        total-playtime: uint,
        sessions: uint,
        last-active: uint,
        achievement-points: uint,
        season-points: uint,
        last-update: uint
    }
)

;; New: Archived player data
(define-map archived-player-stats
    { game-id: principal, player-id: principal, season: uint }
    {
        total-playtime: uint,
        achievement-points: uint,
        season-points: uint
    }
)

;; New: Achievement progress tracking
(define-map achievement-progress
    { game-id: principal, player-id: principal, achievement-id: uint }
    {
        current-value: uint,
        target-value: uint,
        last-update: uint
    }
)

[... existing maps ...]

;; Enhanced Authorization Functions
(define-public (register-game (game-id principal))
    (begin
        (asserts! (is-eq tx-sender contract-owner) err-owner-only)
        (map-set authorized-games game-id true)
        (map-set game-metrics game-id {
            total-players: u0,
            active-players: u0,
            total-sessions: u0,
            current-season: u1
        })
        (ok true)
    )
)

;; New: Achievement Progress Functions
(define-public (update-achievement-progress
    (game-id principal)
    (player-id principal)
    (achievement-id uint)
    (progress-value uint))
    
    (let (
        (achievement (unwrap! (map-get? achievements { game-id: game-id, achievement-id: achievement-id }) err-invalid-achievement))
        (current-progress (default-to { current-value: u0, target-value: u0, last-update: u0 }
            (map-get? achievement-progress { game-id: game-id, player-id: player-id, achievement-id: achievement-id })))
    )
        (if (is-game-authorized game-id)
            (begin
                (map-set achievement-progress
                    { game-id: game-id, player-id: player-id, achievement-id: achievement-id }
                    {
                        current-value: progress-value,
                        target-value: (get points achievement),
                        last-update: block-height
                    }
                )
                (ok true)
            )
            err-unauthorized
        )
    )
)

;; New: Data Cleanup Functions
(define-public (archive-player-data
    (game-id principal)
    (player-id principal)
    (season uint))
    
    (let (
        (player-data (unwrap! (map-get? player-stats { game-id: game-id, player-id: player-id }) err-unauthorized))
        (inactive-blocks (- block-height (get last-active player-data)))
    )
        (if (and (is-game-authorized game-id) (> inactive-blocks u10000))
            (begin
                (map-set archived-player-stats
                    { game-id: game-id, player-id: player-id, season: season }
                    {
                        total-playtime: (get total-playtime player-data),
                        achievement-points: (get achievement-points player-data),
                        season-points: (get season-points player-data)
                    }
                )
                (map-delete player-stats { game-id: game-id, player-id: player-id })
                (ok true)
            )
            err-unauthorized
        )
    )
)

[... rest of existing functions ...]
