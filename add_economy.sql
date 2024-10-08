CREATE TABLE wallets (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    balance BIGINT NOT NULL DEFAULT 0
);

ALTER TABLE metaserver_users ADD COLUMN wallet_id BIGINT;
ALTER TABLE orders ADD COLUMN wallet_id BIGINT;

ALTER TABLE metaserver_users ADD CONSTRAINT fk_user_wallet FOREIGN KEY (wallet_id) REFERENCES wallets(id);
ALTER TABLE orders ADD CONSTRAINT fk_order_wallet FOREIGN KEY (wallet_id) REFERENCES wallets(id);