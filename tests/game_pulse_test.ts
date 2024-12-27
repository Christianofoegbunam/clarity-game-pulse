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
    name: "Can log game session and retrieve player stats",
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
    }
});

Clarinet.test({
    name: "Only owner can register games",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const nonOwner = accounts.get('wallet_1')!;
        const gamedev = accounts.get('wallet_2')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('game-pulse', 'register-game',
                [types.principal(gamedev.address)],
                nonOwner.address
            )
        ]);
        
        block.receipts[0].result.expectErr(types.uint(100)); // err-owner-only
    }
});