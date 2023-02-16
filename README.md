# Glue - continuous ERC20 pull payments

Allows any Ethereum address to continously send funds to another Ethereum address on a regular interval.

The idea is to build an incentive layer on top for the actual `pull` call.

The sender only needs to approve pulls, the rest will happen automatically.

**Note: This is a proof of concept implementation and not ready for production**.

# Development
Glue uses [Foundry](https://github.com/foundry-rs/foundry) for development.
You can install it using [foundryup](https://github.com/foundry-rs/foundry#installation).

## Install 
```bash
forge install
```

## Run tests
```bash
forge test
```

### Deploy
```
forge script script/Deploy.s.sol:DeployScript --rpc-url $RPC_URL  --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_KEY -vvvv
```
