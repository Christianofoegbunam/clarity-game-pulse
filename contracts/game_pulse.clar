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
(define-constant err-invalid-value (err u108))

;; Rate Limiting
(define-map update-timestamps
    { game-id: principal, player-id: principal }
    { last-update: uint }
)

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

;; Archived player data
(define-map archived-player-stats
    { game-id: principal, player-id: principal, season: uint }
    {
        total-playtime: uint,
        achievement-points: uint,
        season-points: uint
    }
)

;; Achievement progress tracking
(define-map achievement-progress
    { game-id: principal, player-id: principal, achievement-id: uint }
    {
        current-value: uint,
        target-value: uint,
        last-update: uint
    }
)

;; Events
(define-data-var event-counter uint u0)

(define-public (emit-achievement-event 
    (game-id principal)
    (player-id principal)
    (achievement-id uint)
    (event-type (string-ascii 20))
)
    (let
        ((counter (var-get event-counter)))
        (print { counter: counter, 
                game-id: game-id,
                player-id: player-id,
                achievement-id: achievement-id,
                event-type: event-type })
        (var-set event-counter (+ counter u1))
        (ok true)
    )
)

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
        (emit-achievement-event game-id contract-owner u0 "GAME_REGISTERED")
        (ok true)
    )
)

;; Rate Limiting Helper
(define-private (check-rate-limit (game-id principal) (player-id principal))
    (let ((last-update (default-to { last-update: u0 }
            (map-get? update-timestamps { game-id: game-id, player-id: player-id }))))
        (if (> (- block-height (get last-update last-update)) u10)
            (begin
                (map-set update-timestamps 
                    { game-id: game-id, player-id: player-id }
                    { last-update: block-height })
                true)
            false)
    )
)

;; Enhanced Achievement Progress Functions
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
        (asserts! (is-game-authorized game-id) err-unauthorized)
        (asserts! (check-rate-limit game-id player-id) err-rate-limit)
        (asserts! (<= progress-value (get points achievement)) err-invalid-value)
        
        (map-set achievement-progress
            { game-id: game-id, player-id: player-id, achievement-id: achievement-id }
            {
                current-value: progress-value,
                target-value: (get points achievement),
                last-update: block-height
            }
        )
        (emit-achievement-event game-id player-id achievement-id "PROGRESS_UPDATE")
        (ok true)
    )
)

;; Batch Processing
(define-public (batch-update-achievements
    (game-id principal)
    (player-id principal)
    (achievement-updates (list 10 { achievement-id: uint, progress-value: uint })))
    
    (fold check-and-update-achievement achievement-updates (ok true))
    (where check-and-update-achievement
        (current-achievement { achievement-id: uint, progress-value: uint })
        (previous-result (response bool uint))
        (begin
            (try! (update-achievement-progress game-id player-id 
                (get achievement-id current-achievement)
                (get progress-value current-achievement)))
            previous-result
        )
    )
)

[... rest of existing functions ...]
