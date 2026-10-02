-include .env

.PHONY: all build test install gas-report gas-scaling deploy-anvil deploy-sepolia deploy-sepolia-demo deploy-sepolia-defense deploy-relay-sepolia

build:; forge build

test:; forge test

install:; forge install foundry-rs/forge-std@v1.16.2 && forge install OpenZeppelin/openzeppelin-contracts@v5.6.1

deploy-anvil:
	@forge script script/DeployPayroll.s.sol --rpc-url ${ANVIL_RPC_URL} --account defaultKey --broadcast -vvvv

deploy-sepolia-demo:
	@PAYROLL_INTERVAL_SECONDS=10 forge script script/DeployPayroll.s.sol --rpc-url ${SEPOLIA_RPC_URL} --account sepoliaKey --broadcast --verify --etherscan-api-key ${ETHERSCAN_API_KEY} -vvvv

# Instance de la soutenance : une paie toutes les 120 s, declenchee par le
# workflow CRE toutes les 30 s.
deploy-sepolia-defense:
	@PAYROLL_INTERVAL_SECONDS=120 forge script script/DeployPayroll.s.sol --rpc-url ${SEPOLIA_RPC_URL} --account sepoliaKey --broadcast --verify --etherscan-api-key ${ETHERSCAN_API_KEY} -vvvv

# Relais CRE : PAYROLL_ADDRESS et FORWARDER_ADDRESS sont lus dans l'environnement.
deploy-relay-sepolia:
	@forge script script/DeployPayrollRelay.s.sol --rpc-url ${SEPOLIA_RPC_URL} --account sepoliaKey --broadcast --verify --etherscan-api-key ${ETHERSCAN_API_KEY} -vvvv

deploy-sepolia:
	@forge script script/DeployPayroll.s.sol --rpc-url ${SEPOLIA_RPC_URL} --account sepoliaKey --broadcast --verify --etherscan-api-key ${ETHERSCAN_API_KEY} -vvvv

# Rapport de gas du tableau 8 du memoire.
# Le test de mise a l'echelle est exclu : ses effectifs artificiels, jusqu'a
# cinquante salaries, deplacent les moyennes et les maximums vers des valeurs
# qui ne correspondent a aucun usage reel.
gas-report:; forge test --gas-report --no-match-path "test/gas/*"

# Mesure du cout de runPayroll selon l'effectif, presentee separement.
gas-scaling:; forge test --match-path "test/gas/PayrollGasScaling.t.sol" -vv
