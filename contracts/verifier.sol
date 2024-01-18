// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

/**
 * @title EIP712Verifier
 * @dev EIP712Verifier is a contract for verifying EIP-712 signatures
 * @author geofferyj
 */
contract EIP712Verifier {
    // EIP-712 domain separator
    bytes32 public DOMAIN_SEPARATOR;

    /**
     * @dev TransferTransaction data struct
     * @param token The address of the token to transfer
     * @param from The address of the sender
     * @param to The address of the recipient
     * @param amount The amount of tokens to transfer
     * @param nonce The nonce of the transaction
     * @param deadline The deadline of the transaction
     */
    struct TransferTransaction {
        address token;
        address from;
        address to;
        uint256 amount;
        uint256 nonce;
        uint256 deadline;
    }

    /**
     * EIP-712 type hash for the TransferTransaction data type
     */
    bytes32 public constant TransferTransaction_TYPEHASH = keccak256(
        "TransferTransaction(address token,address from,address to,uint256 amount,uint256 nonce,uint256 deadline)"
    );

    /**
     * @dev SwapTransaction data struct
     */
    struct SwapTransaction {
        address tokenA;
        address tokenB;
        address from;
        uint256 amountA;
        uint256 amountB;
        uint256 nonce;
        uint256 deadline;
    }

    /**
     * @dev EIP-712 type hash for the SwapTransaction data type
     */
    bytes32 public constant SwapTransaction_TYPEHASH = keccak256(
        "SwapTransaction(address tokenA,address tokenB,address from,uint256 amountA,uint256 amountB,uint256 nonce,uint256 deadline)"
    );

    /**
     * @dev struct for Spray transaction
     */
    struct SprayTransaction {
        address token;
        address from;
        address[] receivers;
        uint256 amount;
        string code;
    }

    /**
     * @dev EIP-712 type hash for the SprayTransaction data type
     */
    bytes32 public constant SprayTransaction_TYPEHASH = keccak256(
        "SprayTransaction(address token,address from,address[] receivers,uint256 amount,string code)"
    );


    constructor() {
        // Calculate the DOMAIN_SEPARATOR in the constructor

        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
                keccak256(bytes("Peniwallet")), // Contract name
                keccak256(bytes("1")), // Version
                chainId, // Chain ID
                address(this) // Contract address
            )
        );
    }

    // Verify a signature and return the signer's address for tranfer transaction
    function verifyTransfer(
        TransferTransaction memory transaction,
        bytes memory signature
    ) internal view returns (bool) {
        // Extract v, r, and s from the signature
        require(signature.length == 65, "Invalid signature");
        // Create a hash of the Transaction data using EIP-712 encoding
        bytes32 structHash = keccak256(
            abi.encode(
                TransferTransaction_TYPEHASH,
                transaction.token,
                transaction.from,
                transaction.to,
                transaction.amount,
                transaction.nonce,
                transaction.deadline
            )
        );

        address signer = _getSigner(signature, structHash);
        require(signer != address(0), "Invalid signature");

        return signer == transaction.from;
    }

    // Verify a signature and return the signer's address for swap transaction
    function verifySwap(
        SwapTransaction memory transaction,
        bytes memory signature
    ) internal view returns (bool) {
        // Extract v, r, and s from the signature
        require(signature.length == 65, "Invalid signature");
        // Create a hash of the Transaction data using EIP-712 encoding
        bytes32 structHash = keccak256(
            abi.encode(
                SwapTransaction_TYPEHASH,
                transaction.tokenA,
                transaction.tokenB,
                transaction.from,
                transaction.amountA,
                transaction.amountB,
                transaction.nonce,
                transaction.deadline
            )
        );

        address signer = _getSigner(signature, structHash);
        require(signer != address(0), "Invalid signature");

        return signer == transaction.from;
    }

    // Verify a signature and return the signer's address for spray transaction
    function verifySpray(
        SprayTransaction memory transaction,
        bytes memory signature
    ) internal view returns (bool) { 
        // Extract v, r, and s from the signature
        require(signature.length == 65, "Invalid signature");
        // Create a hash of the Transaction data using EIP-712 encoding
        bytes32 structHash = keccak256(
            abi.encode(
                SprayTransaction_TYPEHASH,
                transaction.token,
                transaction.from,
                keccak256(abi.encodePacked(transaction.receivers)),
                transaction.amount,
                keccak256(abi.encodePacked(transaction.code))
            )
        );

        address signer = _getSigner(signature, structHash);
        require(signer != address(0), "Invalid signature");

        return signer == transaction.from;
    }

    function _getSigner(bytes memory signature, bytes32 structHash) private view returns (address){

        uint8 v;
        bytes32 r;
        bytes32 s;

        assembly {
            // Slice the signature into v, r, and s
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }

        // Add EIP-191 header ("\x19\x01" prefix)
        bytes32 messageHash = keccak256(
            abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, structHash)
        );

        // Recover the signer's address from the signature
        return ecrecover(messageHash, v, r, s);
    }
}
