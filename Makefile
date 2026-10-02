-include .env

.PHONY: all build test install gas-report gas-scaling deploy-anvil deploy-sepolia deploy-sepolia-demo deploy-relay-sepolia

build:; forge build

test:; forge test

install:; forge install foundry-rs/forge-std@v1.16.2 && forge install OpenZeppelin/openzeppelin-contracts@v5.6.1

deploy-anvil:
	@forge script script/DeployPayroll.s.sol --rpc-url ${ANVIL_RPC_URL} --account defaultKey --broadcast -vvvv

# Sepolia targets use --slow: the deployer account is EIP-7702 delegated, and
# nodes accept only one in-flight transaction from such accounts.

# Demo instance for the thesis defense: one payroll every 120 s, triggered by
# the CRE workflow every 30 s.
deploy-sepolia-demo:
	@PAYROLL_INTERVAL_SECONDS=120 forge script script/DeployPayroll.s.sol --rpc-url ${SEPOLIA_RPC_URL} --account sepoliaKey --broadcast --slow --verify --etherscan-api-key ${ETHERSCAN_API_KEY} -vvvv

# CRE relay: PAYROLL_ADDRESS and FORWARDER_ADDRESS are read from the environment.
deploy-relay-sepolia:
	@forge script script/DeployPayrollRelay.s.sol --rpc-url ${SEPOLIA_RPC_URL} --account sepoliaKey --broadcast --slow --verify --etherscan-api-key ${ETHERSCAN_API_KEY} -vvvv

deploy-sepolia:
	@forge script script/DeployPayroll.s.sol --rpc-url ${SEPOLIA_RPC_URL} --account sepoliaKey --broadcast --slow --verify --etherscan-api-key ${ETHERSCAN_API_KEY} -vvvv

# Gas report for table 8 of the thesis.
# The scaling test is excluded: its artificial headcounts, up to fifty
# employees, shift the averages and maximums toward values that match no
# real usage.
gas-report:; forge test --gas-report --no-match-path "test/gas/*"

# Cost of runPayroll by headcount, reported separately.
gas-scaling:; forge test --match-path "test/gas/PayrollGasScaling.t.sol" -vv
