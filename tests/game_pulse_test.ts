import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Can register new game and check authorization",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const gamedev = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('game-pulse', 'register-game', 
                [types.principal(gamedev.address)],
                deployer.address
            )
        ]);
        
        block.receipts[0].result.expectOk().expectBool(true);
        
        let authCheck = chain.mineBlock([
            Tx.contractCall('game-pulse', 'is-game-authorized',
                [types.principal(gamedev.address)],
                deployer.address
            )
        ]);
        
        authCheck.receipts[0].result.expectBool(true);
    }
});

Clarinet.test({
    name: "Can start new season and update leaderboard",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const gamedev = accounts.get('wallet_1')!;
        const player = accounts.get('wallet_2')!;
        
        // Register game first
        let setup = chain.mineBlock([
            Tx.contractCall('game-pulse', 'register-game',
                [types.principal(gamedev.address)],
                deployer.address
            )
        ]);
        
        // Start new season
        let startSeason = chain.mineBlock([
            Tx.contractCall('game-pulse', 'start-new-season',
                [
                    types.principal(gamedev.address),
                    types.uint(1),
                    types.uint(1000)
                ],
                gamedev.address
            )
        ]);
        
        startSeason.receipts[0].result.expectOk().expectBool(true);
        
        // Log game session with points
        let session = chain.mineBlock([
            Tx.contractCall('game-pulse', 'log-game-session',
                [
                    types.principal(gamedev.address),
                    types.principal(player.address),
                    types.uint(3600),
                    types.uint(100)
                ],
                gamedev.address
            )
        ]);
        
        session.receipts[0].result.expectOk().expectBool(true);
        
        // Check leaderboard
        let leaderboard = chain.mineBlock([
            Tx.contractCall('game-pulse', 'get-season-leaderboard',
                [
                    types.principal(gamedev.address),
                    types.uint(1)
                ],
                deployer.address
            )
        ]);
        
        const board = leaderboard.receipts[0].result.expectOk().expectSome();
        const topPlayers = board.value['top-players'];
        assertEquals(topPlayers.length, 1);
        assertEquals(topPlayers[0].value.points, types.uint(100));
    }
});

Clarinet.test({
    name: "Can create and unlock achievements with leaderboard updates",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const gamedev = accounts.get('wallet_1')!;
        const player = accounts.get('wallet_2')!;
        
        // Register game and start season
        let setup = chain.mineBlock([
            Tx.contractCall('game-pulse', 'register-game',
                [types.principal(gamedev.address)],
                deployer.address
            ),
            Tx.contractCall('game-pulse', 'start-new-season',
                [
                    types.principal(gamedev.address),
                    types.uint(1),
                    types.uint(1000)
                ],
                gamedev.address
            )
        ]);
        
        // Create achievement
        let createAchievement = chain.mineBlock([
            Tx.contractCall('game-pulse', 'create-achievement',
                [
                    types.principal(gamedev.address),
                    types.uint(1),
                    types.ascii("First Win"),
                    types.ascii("Win your first match"),
                    types.uint(100),
                    types.uint(1)
                ],
                gamedev.address
            )
        ]);
        
        createAchievement.receipts[0].result.expectOk().expectBool(true);
        
        // Unlock achievement
        let unlockAchievement = chain.mineBlock([
            Tx.contractCall('game-pulse', 'unlock-achievement',
                [
                    types.principal(gamedev.address),
                    types.principal(player.address),
                    types.uint(1)
                ],
                gamedev.address
            )
        ]);
        
        unlockAchievement.receipts[0].result.expectOk().expectBool(true);
        
        // Verify leaderboard update
        let leaderboard = chain.mineBlock([
            Tx.contractCall('game-pulse', 'get-season-leaderboard',
                [
                    types.principal(gamedev.address),
                    types.uint(1)
                ],
                deployer.address
            )
        ]);
        
        const board = leaderboard.receipts[0].result.expectOk().expectSome();
        const topPlayers = board.value['top-players'];
        assertEquals(topPlayers.length, 1);
        assertEquals(topPlayers[0].value.points, types.uint(100));
    }
});
