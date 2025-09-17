# Proxy Contract Explanation

## Overview
This project demonstrates the implementation of a proxy contract pattern in Solidity. The proxy contract allows for the dynamic switching of different contract implementations, enabling the upgrade of contract functionality without changing the contract's address.

## Contracts

1. **Version1 and Version2 Contracts**:
   - These are simple contracts that have a public string variable `V` and a function `version()` that sets the value of `V` and emits a `LogStr` event.

2. **Proxy_Storage Contract**:
   - This is the main proxy contract that manages the switching between the `Version1` and `Version2` contracts.
   - It has a constant `implementationPosition` that is used to store the address of the current implementation contract.
   - It has a public string variable `V` that is set to "proxy".
   - It has two functions, `setV1()` and `setV2()`, that create new instances of `Version1` and `Version2` contracts respectively and set the implementation address using the `SetRelay()` function.
   - The `SetRelay()` function updates the implementation address in the `implementationPosition` storage slot.
   - The `GetRelay()` function retrieves the current implementation address from the `implementationPosition` storage slot.
   - The `fallback()` function is the entry point for all external function calls. It retrieves the current implementation address, emits a `LogAdr` event, and then delegates the call to the implementation contract using `delegatecall()`.
   - The `receive()` function is the fallback function that handles Ether transfers to the contract.

## Proxy Contract Functionality

1. The proxy contract is deployed, and its address is noted.
2. The `Version1` contract is deployed, and its address is set as the implementation address in the proxy contract using the `setV1()` function.
3. Calling the `version()` function on the proxy contract will execute the `version()` function of the `Version1` contract, and the value of `V` will be set to "Version1".
4. The `Version2` contract is deployed, and its address is set as the implementation address in the proxy contract using the `setV2()` function.
5. Calling the `version()` function on the proxy contract will now execute the `version()` function of the `Version2` contract, and the value of `V` will be set to "Version2".

The proxy pattern allows the contract to switch between different implementation contracts (`Version1` and `Version2`) without changing the proxy contract's address. This enables the upgrade of contract functionality without disrupting existing integrations.

## Key Concepts

1. **Proxy Pattern**: The proxy contract acts as an intermediary between the user and the implementation contracts, allowing for dynamic switching of the implementation.
2. **Storage Slot**: The `implementationPosition` storage slot is used to store the address of the current implementation contract. This slot is accessed using low-level assembly operations.
3. **Fallback Function**: The `fallback()` function is the entry point for all external function calls. It retrieves the current implementation address and delegates the call to the implementation contract using `delegatecall()`.
4. **Delegate Call**: The `delegatecall()` function allows the proxy contract to execute the code of the implementation contract while maintaining the storage context of the proxy contract.

This proxy contract pattern is a common technique used in Ethereum smart contract development to enable contract upgradability and flexibility.