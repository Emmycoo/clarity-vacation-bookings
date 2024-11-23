import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Test successful booking",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('property-bookings', 'book-property', [
                types.uint(10), // check-in
                types.uint(14)  // check-out
            ], wallet1.address)
        ]);
        
        block.receipts[0].result.expectOk().expectUint(1);
    },
});

Clarinet.test({
    name: "Test booking cancellation",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('property-bookings', 'book-property', [
                types.uint(20),
                types.uint(24)
            ], wallet1.address),
            Tx.contractCall('property-bookings', 'cancel-booking', [
                types.uint(1)
            ], wallet1.address)
        ]);
        
        block.receipts[1].result.expectOk().expectBool(true);
    },
});

Clarinet.test({
    name: "Test invalid booking dates",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('property-bookings', 'book-property', [
                types.uint(1), // past date
                types.uint(4)
            ], wallet1.address)
        ]);
        
        block.receipts[0].result.expectErr().expectUint(101); // err-invalid-dates
    },
});
