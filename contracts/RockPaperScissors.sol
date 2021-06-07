//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract RockPaperScissors {
    /*

    1 = ROCK
    2 = PAPER
    3 = SCISSORS

    */

    // Token address
    address tokenAddress;

    // Token instance
    IERC20 token = IERC20(tokenAddress);

    // Single bet amount
    uint256 betAmount;

    // Total number of players
    uint8 numberOfPlayers = 0;

    // Game end time
    uint256 gameEndTime;

    // Player struct keeping address and choice
    struct player {
        address payable addr;
        uint8 choice;
    }

    // Players 1 and 2
    player player1;
    player player2;

    // Player status options
    enum status {NONE, COMMITTED, REVEALED}

    // Result options
    enum result {WIN, LOSE, TIE}

    // Evaluation result
    result res;

    // Either "COMMITTED" or "REVEALED"
    mapping(address => status) playerStatuses; // I could've used player struct instead of this, but that way I would need bunch of if statements. So I thought it would be cheaper this way

    // Keeps <user_address => hashed_move>
    mapping(address => bytes32) playerHashedMoves;

    // CONSTRUCTOR
    constructor(
        uint256 _gameLengthSeconds,
        uint256 _betAmount,
        address _unit
    ) {
        /* 
        Requires 120 seconds for game time considering transfer times for players
        This Commit&Reveal scheme needs 4 sequential transactions: 
        player1(commit), 
        player2(commit), 
        player1 or 2(reveal), 
        player2 or 2(reveal + evaluate)
        */
        if (_gameLengthSeconds < 120) {
            revert();
        }

        // Sets single bet amount
        betAmount = _betAmount;

        // Sets the game end time
        gameEndTime = block.timestamp + _gameLengthSeconds + 1 seconds;

        // Creates token instance
        token = IERC20(_unit);
    }

    // CORE FUNCTIONS
    function commitMove(bytes32 _hashedMove) public payable {
        // Valid move check will be done by front-end

        // Only allow moves during game time
        require(block.timestamp < gameEndTime, "Game ended!");

        // Only allow 1 move per player
        require(
            playerStatuses[msg.sender] == status(0),
            "You've already played. Wait for the other player."
        );

        // Only allow 2 players at the same time
        require(numberOfPlayers <= 1, "Can't accept more than 2 players");

        token.transferFrom(msg.sender, address(this), betAmount);

        // Adds hashed move to storage
        playerHashedMoves[msg.sender] = _hashedMove;

        // Changes user status to "COMMITTED"
        playerStatuses[msg.sender] = status.COMMITTED;

        // Increments total number of players
        numberOfPlayers += 1;

        // First comer is assigned to player1
        if (player1.addr == address(0)) {
            player1.addr = payable(msg.sender);
        } else if (player2.addr == address(0)) {
            player2.addr = payable(msg.sender);
        }
    }

    function revealMove(uint8 _move, string memory _salt) public {
        // Only accept valid moves
        require(
            _move == 1 || _move == 2 || _move == 3,
            "Your move is not valid! Only 1, 2, or 3"
        );

        // Only reveal if already committed
        require(
            playerStatuses[msg.sender] == status.COMMITTED,
            "You should commit a move first"
        );

        // Only reveal moves after both players have committed
        require(
            numberOfPlayers == 2,
            "Wait for the other player to commit their move."
        );

        // Hashes "move" and "salt" provided by the user
        bytes32 hashedMove = keccak256(abi.encodePacked(_move, _salt));

        // If hash(move + salt) matched with initial commit, changes the status
        if (playerHashedMoves[msg.sender] == hashedMove) {
            playerStatuses[msg.sender] = status.REVEALED;
        }

        // Check if player1 or player2
        if (player1.addr == msg.sender) {
            player1.choice = _move;
        } else if (player2.addr == msg.sender) {
            player2.choice = _move;
        }

        // If both players have revealed their move, evaluation starts
        if (player1.choice != 0 && player2.choice != 0) {
            res = evaluate();
            if (res == result.TIE) {
                // Transfer betAmount to each player
                console.log("TIE");
                token.transfer(player1.addr, betAmount);
                token.transfer(player2.addr, betAmount);
            } else if (res == result.WIN) {
                // Transfer (betAmount * 2) to player1
                console.log("player1 wins");
                token.transfer(player1.addr, betAmount * 2);
            } else if (res == result.LOSE) {
                // Transfer (betAmount * 2) to player2
                console.log("player2 wins");
                token.transfer(player2.addr, betAmount * 2);
            }
        }
    }

    function evaluate() internal view returns (result) {
        // Returns the result according to player1
        // Preferred nested "if"s because 9 seperate "if"s most probably require more gas (45 > 36)
        if (player1.choice == 1) {
            if (player2.choice == 1) {
                return result.TIE;
            } else if (player2.choice == 2) {
                return result.LOSE;
            } else if (player2.choice == 3) {
                return result.WIN;
            }
        } else if (player1.choice == 2) {
            if (player2.choice == 1) {
                return result.WIN;
            } else if (player2.choice == 2) {
                return result.TIE;
            } else if (player2.choice == 3) {
                return result.LOSE;
            }
        } else if (player1.choice == 3) {
            if (player2.choice == 1) {
                return result.LOSE;
            } else if (player2.choice == 2) {
                return result.WIN;
            } else if (player2.choice == 3) {
                return result.TIE;
            }
        }
    }

    function withdraw() external {
        require(block.timestamp > gameEndTime, "Game hasn't ended yet");

        if (msg.sender == player1.addr) {
            token.transfer(player1.addr, betAmount);
        } else if (msg.sender == player2.addr) {
            token.transfer(player2.addr, betAmount);
        }
    }

    // GETTERS
    function getMoves(address _user) public view returns (bytes32) {
        return playerHashedMoves[_user];
    }

    function getPlayerStatus(address _user) public view returns (status) {
        return playerStatuses[_user];
    }
}
