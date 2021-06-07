import { expect, use } from "chai";
import { ethers, network } from "hardhat";
import { BigNumber, Signer } from "ethers";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";

// import {} from "../typechain";

let contract: any;
let token: any;
let accounts: Signer[];
let owner: SignerWithAddress;
let user1: SignerWithAddress;
let user2: SignerWithAddress;
let hashedMove1: String;
let hashedMove2: String;
let hashedMove3: String;

hashedMove1 = ethers.utils.solidityKeccak256(
  ["uint8", "string"],
  [1, "ILIKESALTYFOOD"]
);

hashedMove2 = ethers.utils.solidityKeccak256(
  ["uint8", "string"],
  [2, "ILIKESPICYFOOD"]
);

hashedMove3 = ethers.utils.solidityKeccak256(
  ["uint8", "string"],
  [1, "ILIKECRISPYFOOD"]
);

describe("Rock Paper Scissors", function () {
  beforeEach(async () => {
    [owner, user1, user2, ...accounts] = await ethers.getSigners();

    const tokenFactory = await ethers.getContractFactory("MTRToken");
    token = await tokenFactory.deploy(100);
    await token.deployed();

    const RPS = await ethers.getContractFactory("RockPaperScissors");
    // Deploys the game contract for 10 minutes with a bet amount of 1 Ether
    contract = await RPS.deploy(10 * 60, 10, token.address);
    await contract.deployed();

    await token.transfer(user1.address, 20);
    await token.approve(contract.address, 10);
    await token.connect(user1).approve(contract.address, 10);
  });
  describe("committing", async () => {
    it("players can bet", async () => {
      await contract.commitMove(hashedMove1);

      const move = await contract.getMoves(owner.address);

      expect(move).to.be.equal(hashedMove1);
    });
    it("players can't play twice", async () => {
      await contract.commitMove(hashedMove1);

      await expect(contract.commitMove(hashedMove2)).to.be.revertedWith(
        "You've already played. Wait for the other player."
      );
    });
    it("shouldn't accept more than 2 players", async () => {
      await contract.commitMove(hashedMove1);
      await contract.connect(user1).commitMove(hashedMove2);

      await expect(
        contract.connect(user2).commitMove(hashedMove3)
      ).to.be.revertedWith("Can't accept more than 2 players");
    });
  });
  describe("revealing", async () => {
    it("player can reveal their move", async () => {
      await contract.commitMove(hashedMove1);
      await contract.connect(user1).commitMove(hashedMove2);

      // await network.provider.send("evm_increaseTime", [900])

      await contract.revealMove(1, "ILIKESALTYFOOD");

      const status = await contract.getPlayerStatus(owner.address);
      expect(status).to.be.equal(2);
    });
    it("player can't reveal before other player commits", async () => {
      await contract.commitMove(hashedMove1);

      await expect(contract.revealMove(1, "ILIKESALTYFOOD")).to.be.revertedWith(
        "Wait for the other player to commit their move."
      );
    });
    it("only valid moves are accepted", async () => {
      await contract.commitMove(hashedMove1);

      await expect(contract.revealMove(5, "ILIKESALTYFOOD")).to.be.revertedWith(
        "Your move is not valid! Only 1, 2, or 3"
      );
    });
    it("only reveal after committing", async () => {
      await expect(contract.revealMove(1, "ILIKESALTYFOOD")).to.be.revertedWith(
        "You should commit a move first"
      );
    });
  });
  describe("evaluation", async () => {
    it("evaluates", async () => {
      await contract.commitMove(hashedMove1);
      await contract.connect(user1).commitMove(hashedMove2);

      await contract.revealMove(1, "ILIKESALTYFOOD");

      const balanceBefore = (await token.balanceOf(user1.address)).toNumber();

      await contract.connect(user1).revealMove(2, "ILIKESPICYFOOD");

      const balanceAfter = (await token.balanceOf(user1.address)).toNumber();

      expect(balanceAfter - balanceBefore).to.equal(20);
    });
  });
});
