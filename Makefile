-include .env

.PHONY: all test deploy

help:
	@echo "Usage:"
	@echo "make deploy [ARGS=...]"

build:; forge build --via-ir

install:; forge install Cyfrin/foundry-devops@0.0.11 --no-commit && forge install smartcontractkit/chainlink-brownie-contracts@0.6.1 --no-commit && forge install foundry-rs/forge-std@v1.5.3 --no-commit && forge install transmissions11/solmate@v6 --no-commit

# NETWORK_ARGS := --rpc-url $(ANVIL_RPC_URL) --private-key $(ANVIL_PRIVATE_KEY) --broadcast

test:; forge test --via-ir $(NETWORK_ARGS)
# check if theere is any testnet or local chain
# -verfiy --etherscan-api-key $(API_KEY) -vvvv

NETWORK_ARGS := --rpc-url $(MUMBAI_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast
# ifeq ($(ARGS),--network mumbai)
# ifeq ($(findstring --network mumbai,$(ARGS)),--network mumbai)
# 	NETWORK_ARGS := --rpc-url $(MUMBAI_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast

ifeq ($(findstring --network mumbai,$(ARGS)),--network mumbai)
	NETWORK_ARGS := --rpc-url $(ALCHEMY_RPC_URL) --private-key $(PRIVATE_KEY) --broadcast --verfiy --etherscan-api-key $(ALCHEMY_KEY) -vvvv
	
endif
anvil:; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

deploy:
	@forge script script/DeployRaffle.s.sol:DeployRaffle $(NETWORK_ARGS) --via-ir -vvvv