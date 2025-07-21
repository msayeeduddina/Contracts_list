// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

/**
 * @title Poly
 * @dev Demonstrates function overloading in Solidity, a form of compile-time polymorphism.
 */
contract Poly {

    // Tech Note: 'a' and 'b' are state variables representing internal contract data.
    uint8 a; // Stores an 8-bit unsigned integer.
    uint16 b; // Stores a 16-bit unsigned integer.

    /**
     * @dev Sets the value of state variable 'a'.
     * @param _a The 8-bit unsigned integer value to set for 'a'.
     * // Tech Note: This is an example of function overloading. The function name 'setVar' is reused
     * // but distinguished by its unique parameter list (uint8).
     */
    function setVar(uint8 _a) public {
        a = _a;
    }

    /**
     * @dev Sets the value of state variable 'b'.
     * @param _b The 16-bit unsigned integer value to set for 'b'.
     * // Tech Note: Another example of function overloading. The compiler distinguishes this
     * // 'setVar' function by its uint16 parameter type.
     */
    function setVar(uint16 _b) public {
        b = _b;
    }

    /**
     * @dev Sets the value of state variable 'a' as the sum of two 8-bit unsigned integers.
     * @param _a1 The first 8-bit unsigned integer.
     * @param _a2 The second 8-bit unsigned integer.
     * // Tech Note: This further illustrates function overloading. The signature is distinct due to
     * // the two uint8 parameters, even though the function name is the same.
     */
    function setVar(uint8 _a1, uint8 _a2) public {
        a = _a1 + _a2;
    }

    /**
     * @dev Sets the value of state variable 'b' as the sum of two 16-bit unsigned integers.
     * @param _b1 The first 16-bit unsigned integer.
     * @param _b2 The second 16-bit unsigned integer.
     * // Tech Note: This is the final overloaded 'setVar' function. Its unique signature is defined
     * // by the two uint16 parameters.
     * // Tech Note: The concept of polymorphism in this contract is specifically "compile-time polymorphism"
     * // achieved through function overloading. There is no "runtime polymorphism" (e.g., via inheritance
     * // and virtual functions) demonstrated in this specific contract.
     */
    function setVar(uint16 _b1, uint16 _b2) public {
        b = _b1 + _b2;
    }

}