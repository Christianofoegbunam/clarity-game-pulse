;; GamePulse - Gaming Analytics Platform

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-owner-only (err u100))
(define-constant err-unauthorized (err u101))
(define-constant err-invalid-game (err u102))
(define-constant err-invalid-achievement (err u103))
(define-constant err-already-unlocked (err u104))
(define-constant err-invalid-season (err u105))

;; Data Variables
(define-map authorized-games principal bool)
(define-map player-stats
    { game-id: principal, player-id: principal }
    { 
        total-playtime: uint,
        sessions: uint,
        last-active: uint,
        achievement-points: uint,
        season-points: uint
    }
)

(define-map game-metrics 
    principal
    {
        total-players: uint,
        active-players: uint,
        total-sessions: uint,
        current-season: uint
    }
)

(define-map achievements
    { game-id: principal, achievement-id: uint }
    {
        name: (string-ascii 50),
        description: (string-ascii 200),
        points: uint,
        rarity: uint
    }
)

(define-map player-achievements
    { game-id: principal, player-id: principal, achievement-id: uint }
    {
        unlocked: bool,
        unlock-time: uint
    }
)

(define-map season-leaderboards
    { game-id: principal, season: uint }
    {
        start-block: uint,
        end-block: uint,
        top-players: (list 100 { player: principal, points: uint })
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
                total-sessions: u0,
                current-season: u1
            })
            (ok true)
        )
        err-owner-only
    )
)

(define-read-only (is-game-authorized (game-id principal))
    (default-to false (map-get? authorized-games game-id))
)

;; Season Management
(define-public (start-new-season 
    (game-id principal)
    (season uint)
    (duration uint))
    
    (let ((game-data (unwrap! (map-get? game-metrics game-id) err-invalid-game)))
        (if (is-game-authorized game-id)
            (begin
                (map-set season-leaderboards
                    { game-id: game-id, season: season }
                    {
                        start-block: block-height,
                        end-block: (+ block-height duration),
                        top-players: (list)
                    }
                )
                (map-set game-metrics
                    game-id
                    (merge game-data { current-season: season })
                )
                (ok true)
            )
            err-unauthorized
        )
    )
)

;; Achievement Functions
(define-public (create-achievement 
    (game-id principal)
    (achievement-id uint)
    (name (string-ascii 50))
    (description (string-ascii 200))
    (points uint)
    (rarity uint))
    
    (if (is-game-authorized game-id)
        (begin
            (map-set achievements
                { game-id: game-id, achievement-id: achievement-id }
                {
                    name: name,
                    description: description,
                    points: points,
                    rarity: rarity
                }
            )
            (ok true)
        )
        err-unauthorized
    )
)

(define-public (unlock-achievement
    (game-id principal)
    (player-id principal)
    (achievement-id uint))
    
    (let (
        (achievement (unwrap! (map-get? achievements { game-id: game-id, achievement-id: achievement-id }) err-invalid-achievement))
        (current-unlock (map-get? player-achievements { game-id: game-id, player-id: player-id, achievement-id: achievement-id }))
        (player-data (default-to { total-playtime: u0, sessions: u0, last-active: u0, achievement-points: u0, season-points: u0 }
            (map-get? player-stats { game-id: game-id, player-id: player-id })))
        (game-data (unwrap! (map-get? game-metrics game-id) err-invalid-game))
    )
        (if (and (is-game-authorized game-id) (is-none current-unlock))
            (begin
                (map-set player-achievements
                    { game-id: game-id, player-id: player-id, achievement-id: achievement-id }
                    {
                        unlocked: true,
                        unlock-time: block-height
                    }
                )
                (map-set player-stats
                    { game-id: game-id, player-id: player-id }
                    {
                        total-playtime: (get total-playtime player-data),
                        sessions: (get sessions player-data),
                        last-active: (get last-active player-data),
                        achievement-points: (+ (get achievement-points player-data) (get points achievement)),
                        season-points: (+ (get season-points player-data) (get points achievement))
                    }
                )
                (try! (update-leaderboard game-id player-id (get current-season game-data)))
                (ok true)
            )
            err-already-unlocked
        )
    )
)

;; Event Logging
(define-public (log-game-session 
    (game-id principal)
    (player-id principal)
    (session-duration uint)
    (points-earned uint))
    
    (let (
        (current-stats (default-to 
            { total-playtime: u0, sessions: u0, last-active: u0, achievement-points: u0, season-points: u0 }
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
                        last-active: block-height,
                        achievement-points: (get achievement-points current-stats),
                        season-points: (+ (get season-points current-stats) points-earned)
                    }
                )
                
                ;; Update game metrics
                (map-set game-metrics
                    game-id
                    {
                        total-players: (+ (get total-players game-data) u1),
                        active-players: (get active-players game-data),
                        total-sessions: (+ (get total-sessions game-data) u1),
                        current-season: (get current-season game-data)
                    }
                )
                
                (try! (update-leaderboard game-id player-id (get current-season game-data)))
                (ok true)
            )
            err-unauthorized
        )
    )
)

;; Leaderboard Functions
(define-private (update-leaderboard (game-id principal) (player-id principal) (season uint))
    (let (
        (player-data (unwrap! (map-get? player-stats { game-id: game-id, player-id: player-id }) err-unauthorized))
        (current-board (unwrap! (map-get? season-leaderboards { game-id: game-id, season: season }) err-invalid-season))
        (player-entry { player: player-id, points: (get season-points player-data) })
    )
        (ok (map-set season-leaderboards
            { game-id: game-id, season: season }
            (merge current-board {
                top-players: (take u100 (sort-leaderboard 
                    (filter remove-duplicates
                        (append (get top-players current-board) (list player-entry))
                    )
                ))
            })
        ))
    )
)

(define-private (sort-leaderboard (entries (list 100 { player: principal, points: uint })))
    (sort entries points-compare)
)

(define-private (points-compare (a { player: principal, points: uint }) (b { player: principal, points: uint }))
    (> (get points a) (get points b))
)

(define-private (remove-duplicates (entry { player: principal, points: uint }))
    true
)

;; Analytics Functions
(define-read-only (get-player-stats (game-id principal) (player-id principal))
    (ok (map-get? player-stats { game-id: game-id, player-id: player-id }))
)

(define-read-only (get-game-metrics (game-id principal))
    (ok (map-get? game-metrics game-id))
)

(define-read-only (get-achievement (game-id principal) (achievement-id uint))
    (ok (map-get? achievements { game-id: game-id, achievement-id: achievement-id }))
)

(define-read-only (get-player-achievement-status 
    (game-id principal)
    (player-id principal)
    (achievement-id uint))
    (ok (map-get? player-achievements { game-id: game-id, player-id: player-id, achievement-id: achievement-id }))
)

(define-read-only (get-season-leaderboard (game-id principal) (season uint))
    (ok (map-get? season-leaderboards { game-id: game-id, season: season }))
)
