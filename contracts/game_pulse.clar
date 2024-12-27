;; GamePulse - Gaming Analytics Platform

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-unauthorized (err u101))
(define-constant err-invalid-game (err u102))

;; Data Variables
(define-map authorized-games principal bool)
(define-map player-stats
    { game-id: principal, player-id: principal }
    { 
        total-playtime: uint,
        sessions: uint,
        last-active: uint
    }
)

(define-map game-metrics 
    principal
    {
        total-players: uint,
        active-players: uint,
        total-sessions: uint
    }
)

;; Authorization Functions
(define-public (register-game (game-id principal))
    (if (is-eq tx-sender contract-owner)
        (begin
            (map-set authorized-games game-id true)
            (map-set game-metrics game-id {
                total-players: u0,
                active-players: u0,
                total-sessions: u0
            })
            (ok true)
        )
        err-owner-only
    )
)

(define-read-only (is-game-authorized (game-id principal))
    (default-to false (map-get? authorized-games game-id))
)

;; Event Logging
(define-public (log-game-session 
    (game-id principal)
    (player-id principal)
    (session-duration uint))
    
    (let (
        (current-stats (default-to 
            { total-playtime: u0, sessions: u0, last-active: u0 }
            (map-get? player-stats { game-id: game-id, player-id: player-id })))
        (game-data (unwrap! (map-get? game-metrics game-id) err-invalid-game))
    )
        (if (is-game-authorized game-id)
            (begin
                ;; Update player stats
                (map-set player-stats
                    { game-id: game-id, player-id: player-id }
                    {
                        total-playtime: (+ (get total-playtime current-stats) session-duration),
                        sessions: (+ (get sessions current-stats) u1),
                        last-active: block-height
                    }
                )
                
                ;; Update game metrics
                (map-set game-metrics
                    game-id
                    {
                        total-players: (+ (get total-players game-data) u1),
                        active-players: (get active-players game-data),
                        total-sessions: (+ (get total-sessions game-data) u1)
                    }
                )
                (ok true)
            )
            err-unauthorized
        )
    )
)

;; Analytics Functions
(define-read-only (get-player-stats (game-id principal) (player-id principal))
    (ok (map-get? player-stats { game-id: game-id, player-id: player-id }))
)

(define-read-only (get-game-metrics (game-id principal))
    (ok (map-get? game-metrics game-id))
)

(define-read-only (get-active-players (game-id principal))
    (let (
        (game-data (unwrap! (map-get? game-metrics game-id) err-invalid-game))
    )
        (ok (get active-players game-data))
    )
)