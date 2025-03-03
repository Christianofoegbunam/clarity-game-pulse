Clarinet.test({
    name: "Enhanced features test suite",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const deployer = accounts.get('deployer')!;
        const gamedev = accounts.get('wallet_1')!;
        const player = accounts.get('wallet_2')!;
        
        // Test rate limiting
        let block = chain.mineBlock([
            Tx.contractCall("game-pulse", "update-achievement-progress", 
                [gamedev.address, player.address, "u1", "u50"], gamedev.address)
        ]);
        block.receipts[0].result.expectOk().toBe(true);
        
        // Test immediate retry (should fail)
        block = chain.mineBlock([
            Tx.contractCall("game-pulse", "update-achievement-progress", 
                [gamedev.address, player.address, "u1", "u60"], gamedev.address)
        ]);
        block.receipts[0].result.expectErr().toBe(107);
        
        // Test batch processing
        const updates = [
            { achievement-id: "u1", progress-value: "u50" },
            { achievement-id: "u2", progress-value: "u30" }
        ];
        block = chain.mineBlock([
            Tx.contractCall("game-pulse", "batch-update-achievements",
                [gamedev.address, player.address, updates], gamedev.address)
        ]);
        block.receipts[0].result.expectOk().toBe(true);
    }
});
