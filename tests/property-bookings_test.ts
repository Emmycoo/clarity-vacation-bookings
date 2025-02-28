import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Test date validation and booking",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        
        // Test invalid date range (check-out before check-in)
        let block = chain.mineBlock([
            Tx.contractCall('property-bookings', 'book-property', [
                types.uint(14),
                types.uint(10)
            ], wallet1.address)
        ]);
        
        block.receipts[0].result.expectErr().expectUint(101); // err-invalid-dates
        
        // Test valid booking
        block = chain.mineBlock([
            Tx.contractCall('property-bookings', 'book-property', [
                types.uint(10),
                types.uint(14)
            ], wallet1.address)
        ]);
        
        block.receipts[0].result.expectOk().expectUint(1);
    },
});

// Additional tests remain the same...
