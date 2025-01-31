import {
  Clarinet,
  Tx,
  Chain,
  Account,
  types
} from 'https://deno.land/x/clarinet@v1.0.0/index.ts';
import { assertEquals } from 'https://deno.land/std@0.90.0/testing/asserts.ts';

Clarinet.test({
    name: "Test successful booking with payment",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        const deployer = accounts.get('deployer')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('property-bookings', 'book-property', [
                types.uint(10),
                types.uint(14)
            ], wallet1.address),
            Tx.contractCall('property-bookings', 'pay-booking', [
                types.uint(1)
            ], wallet1.address)
        ]);
        
        block.receipts[0].result.expectOk().expectUint(1);
        block.receipts[1].result.expectOk().expectBool(true);
    },
});

Clarinet.test({
    name: "Test booking cancellation with refund",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('property-bookings', 'book-property', [
                types.uint(20),
                types.uint(24)
            ], wallet1.address),
            Tx.contractCall('property-bookings', 'pay-booking', [
                types.uint(1)
            ], wallet1.address),
            Tx.contractCall('property-bookings', 'cancel-booking', [
                types.uint(1)
            ], wallet1.address)
        ]);
        
        block.receipts[2].result.expectOk().expectBool(true);
    },
});

Clarinet.test({
    name: "Test payment failures",
    async fn(chain: Chain, accounts: Map<string, Account>) {
        const wallet1 = accounts.get('wallet_1')!;
        const wallet2 = accounts.get('wallet_2')!;
        
        let block = chain.mineBlock([
            Tx.contractCall('property-bookings', 'book-property', [
                types.uint(30),
                types.uint(34)
            ], wallet1.address),
            Tx.contractCall('property-bookings', 'pay-booking', [
                types.uint(1)
            ], wallet2.address)
        ]);
        
        block.receipts[1].result.expectErr().expectUint(103); // err-not-owner
    },
});
