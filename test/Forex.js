// This is an exmaple test file. Hardhat will run every *.js file in `test/`,
// so feel free to add new ones.

// Hardhat tests are normally written with Mocha and Chai.

// We import Chai to use its asserting functions here.
const { expect } = require("chai")
const { ethers } = require('hardhat')

// `describe` is a Mocha function that allows you to organize your tests. It's
// not actually needed, but having your tests organized makes debugging them
// easier. All Mocha functions are available in the global scope.

// `describe` recieves the name of a section of your test suite, and a callback.
// The callback must define the tests of that section. This callback can't be
// an async function.
describe("Forex contract", function () {
  // Mocha has four functions that let you hook into the the test runner's
  // lifecyle. These are: `before`, `beforeEach`, `after`, `afterEach`.

  // They're very useful to setup the environment for tests, and to clean it
  // up after they run.

  // A common pattern is to declare some variables, and assign them in the
  // `before` and `beforeEach` callbacks.

  let forex
  let owner
  let ibEurWhale
  let ibEur
  let ibKrw
  let susd

  const ibEurWhaleAddress = '0xbb3bf20822507c70eafdf11c7469c98fc752ccca'
  const ibEurAddress = '0x96E61422b6A9bA0e068B6c5ADd4fFaBC6a4aae27'
  const ibKRWAddress = '0x95dfdc8161832e4ff7816ac4b6367ce201538253'
  const susdAddress = '0x57Ab1ec28D129707052df4dF418D58a2D46d5f51'


  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  before(async function () {
    // Get the ContractFactory and Signers here.
    const Forex = await ethers.getContractFactory("SynthIBForex")
    ibEur = await ethers.getContractAt("erc20", ibEurAddress)
    susd = await ethers.getContractAt("erc20", susdAddress)
    ibKrw = await ethers.getContractAt("erc20", ibKRWAddress)

    ;[owner, acc1] = await ethers.getSigners()

    forex = await Forex.deploy()
    await forex.deployed()


    await ethers.provider.send("hardhat_setBalance", [ibEurWhaleAddress, '0x3635c9adc5dea00000' /* 1000Ether */]);
    await ethers.provider.send("hardhat_impersonateAccount", [ibEurWhaleAddress])
    ibEurWhale = await ethers.getSigner(ibEurWhaleAddress)

    // flush susd balance
    const balance = await susd.balanceOf(ibEurWhaleAddress);
    if (BigInt(balance) > 0)
      await susd.connect(ibEurWhale).transfer(acc1, balance);
  })

  // You can nest describe calls to create subsections.
  describe("Deployment", function () {
    // `it` is another Mocha function. This is the one you use to define your
    // tests. It receives the test name, and a callback function.

    // If the callback function is async, Mocha will `await` it.
    it("Should set the right owner", async function () {
      // Expect receives a value, and wraps it in an assertion objet. These
      // objects have a lot of utility methods to assert values.

      // This test expects the owner variable stored in the contract to be equal
      // to our Signer's owner.
      expect(await forex.gov()).to.equal(owner.address)
    })

    it("Should add ibKRW", async function () {
      const sKRW = '0x269895a3df4d73b077fc823dd6da1b95f72aaf9b'
      const pool = '0x8461A004b50d321CB22B7d034969cE6803911899'
      await forex.add(ibKRWAddress, sKRW, pool)
    })
  })

  describe("Exchange", function () {
    it("Should swap ibeur to susd", async function () {

      const amountIn = 10_000n * 10n ** 18n
      const calcOut = await forex.quoteIBToSynth(ibEurAddress, susdAddress, amountIn);

      await ethers.provider.send("hardhat_impersonateAccount", [ibEurWhaleAddress])
      ibEurWhale = await ethers.getSigner(ibEurWhaleAddress)
      await ibEur.connect(ibEurWhale).approve(forex.address, ethers.constants.MaxUint256)
      await forex.connect(ibEurWhale).swapIBToSynth(ibEurAddress, susdAddress, amountIn, 1n)
      const amountOut = await susd.balanceOf(ibEurWhaleAddress)

      expect(calcOut).to.be.bignumber.equal(amountOut);

      console.log('out: ' + Number(BigInt(amountOut) / 10n ** 16n) / 100)
      console.log('rate: ' + Number(BigInt(amountOut) * 100n / amountIn) / 100)
    })
  })
})