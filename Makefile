-include .env

.PHONY: all test deploy

build:; forge build

test:; forge test

install:; forge install foundry-rs/forge-std@v1.16.2 && forge install OpenZeppelin/openzeppelin-contracts@v5.6.1

deploy-anvil:
	@forge script script/DeployPayroll.s.sol --rpc-url ${ANVIL_RPC_URL} --account defaultKey --broadcast -vvvv

deploy-sepolia:
	@forge script script/DeployPayroll.s.sol --rpc-url ${SEPOLIA_RPC_URL} --account sepoliaKey --broadcast --verify --etherscan-api-key ${ETHERSCAN_API_KEY} -vvvv