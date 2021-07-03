# PolyGaj Smart Contracts

The PolyGaj contracts are deployed on the Polygon sidechain. They belong to the following address:

GajToken - 0xF4B0903774532AEe5ee567C02aaB681a81539e92

Masterchef - 0xb03f95e649724df6ba575c2c6ef062766a7fdb51

King of Elephants - 0x4b17699c4990265D35875C15D5377571159f6bfd

Elk Finance Jungle Pool - 0x85Ac6e29ee5Ab7665701CfdCC443dF50d5E67e74

WMatic Jungle Pool - 0x5ED37920412415B1d2F0F25e44776F0BE709B4e3

# Contributing

In order to begin contributing to the PolyGaj protocol, use the following instructions. This repository utilizes the Hardhat smart contract framework for compilation and testing.

## Installation

In order to install the necessary dependencies, run `npm install`.

## Compile

Once installed, run `npx hardhat compile` to compile the contracts (utilizing solc 0.7.3).

## Testing

Finally, to test the code, run `npx hardhat test`, locally deploying the contracts and running deterministic unit tests to ensure they function correctly

### Note

Unfortunately, the code needed for testing has yet to be written. Writing them would be a great way to contribute to the protocol. Please check: https://hardhat.org/ for more instructions on how to write tests.
