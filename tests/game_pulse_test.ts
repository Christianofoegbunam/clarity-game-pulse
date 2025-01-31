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
    name: "Can create and unlock achievements",
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
        
        // Check achievement status
        let statusCheck = chain.mineBlock([
            Tx.contractCall('game-pulse', 'get-player-achievement-status',
                [
                    types.principal(gamedev.address),
                    types.principal(player.address),
                    types.uint(1)
                ],
                deployer.address
            )
        ]);
        
        const status = statusCheck.receipts[0].result.expectOk().expectSome();
        assertEquals(status.value['unlocked'], true);
    }
});

Clarinet.test({
    name: "Can log game session and retrieve player stats with achievements",
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
        
        // Log a game session
        let block = chain.mineBlock([
            Tx.contractCall('game-pulse', 'log-game-session',
                [
                    types.principal(gamedev.address),
                    types.principal(player.address),
                    types.uint(3600)  // 1 hour session
                ],
                gamedev.address
            )
        ]);
        
        block.receipts[0].result.expectOk().expectBool(true);
        
        // Check player stats
        let statsCheck = chain.mineBlock([
            Tx.contractCall('game-pulse', 'get-player-stats',
                [
                    types.principal(gamedev.address),
                    types.principal(player.address)
                ],
                deployer.address
            )
        ]);
        
        const stats = statsCheck.receipts[0].result.expectOk().expectSome();
        assertEquals(stats.value['total-playtime'], types.uint(3600));
        assertEquals(stats.value['sessions'], types.uint(1));
        assertEquals(stats.value['achievement-points'], types.uint(0));
    }
});
