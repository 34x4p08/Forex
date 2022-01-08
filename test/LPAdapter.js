// This is an exmaple test file. Hardhat will run every *.js file in `test/`,
// so feel free to add new ones.

// Hardhat tests are normally written with Mocha and Chai.

// We import Chai to use its asserting functions here.
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

  let forex, lpAdapter
  let owner
  let ibEurWhale
  let ibEurLPWhale
  let susdWhale
  let ibEur
  let ibEurLP
  let ibKrw
  let susd

  const ibEurWhaleAddress = '0xbb3bf20822507c70eafdf11c7469c98fc752ccca'
  const ibEurAddress = '0x96E61422b6A9bA0e068B6c5ADd4fFaBC6a4aae27'
  const ibKRWAddress = '0x95dfdc8161832e4ff7816ac4b6367ce201538253'
  const susdAddress = '0x57Ab1ec28D129707052df4dF418D58a2D46d5f51'
  const ibEurLPWhaleAddress = '0xFFb57364d63D5C5cf299D12Fa73cfabEFc301Dc4'
  const susdWhaleAddress = '0xbc3569a03af09f92a9b07e4845fa809dbdc6adfe'
  const ibEurLPAddress = '0x19b080FE1ffA0553469D20Ca36219F17Fcf03859'


  // `beforeEach` will run before each test, re-deploying the contract every
  // time. It receives a callback, which can be async.
  before(async function () {
    // Get the ContractFactory and Signers here.
    const Forex = await ethers.getContractFactory("SynthIBForex")
    const LPAdapter = await ethers.getContractFactory("LPAdapter")
    ibEur = await ethers.getContractAt("IERC20", ibEurAddress)
    ibEurLP = await ethers.getContractAt("IERC20", ibEurLPAddress)
    susd = await ethers.getContractAt("IERC20", susdAddress)
    ibKrw = await ethers.getContractAt("IERC20", ibKRWAddress)

    ;[owner, acc1] = await ethers.getSigners()

    forex = await Forex.deploy()
    await forex.deployed()

    lpAdapter = await LPAdapter.deploy(forex.address)
    await lpAdapter.deployed()

    await ethers.provider.send("hardhat_setBalance", [ibEurWhaleAddress, '0x3635c9adc5dea00000' /* 1000Ether */]);
    await ethers.provider.send("hardhat_setBalance", [ibEurLPWhaleAddress, '0x3635c9adc5dea00000' /* 1000Ether */]);
    await ethers.provider.send("hardhat_impersonateAccount", [ibEurWhaleAddress])
    await ethers.provider.send("hardhat_impersonateAccount", [ibEurLPWhaleAddress])
    await ethers.provider.send("hardhat_impersonateAccount", [susdWhaleAddress])
    ibEurWhale = await ethers.getSigner(ibEurWhaleAddress)
    ibEurLPWhale = await ethers.getSigner(ibEurLPWhaleAddress)
    susdWhale = await ethers.getSigner(susdWhaleAddress)

    // flush susd balance
    const balance = await susd.balanceOf(ibEurLPWhaleAddress);
    if (BigInt(balance) > 0)
      await susd.connect(ibEurLPWhale).transfer(acc1, balance);
  })

  describe("Exchange", function () {
    it("Should swap ibEur LP to susd", async function () {
      await ibEurLP.connect(ibEurLPWhale).approve(lpAdapter.address, ethers.constants.MaxUint256)
      const amountIn = 10_000n * 10n ** 18n
      await lpAdapter.connect(ibEurLPWhale).swapLPToSynth(ibEurLPAddress, susdAddress, amountIn, 1n)
      const amountOut = await susd.balanceOf(ibEurLPWhaleAddress)

      console.log('out: ' + Number(BigInt(amountOut) / 10n ** 16n) / 100)
      console.log('rate: ' + Number(BigInt(amountOut) * 100n / amountIn) / 100)
    })
    it("Should swap susd to ibEur LP", async function () {
      await susd.connect(susdWhale).approve(lpAdapter.address, ethers.constants.MaxUint256)
      const amountIn = 10_000n * 10n ** 18n
      await lpAdapter.connect(susdWhale).swapSynthToLP(susdAddress, ibEurLPAddress, amountIn, 1n)
      const amountOut = await ibEurLP.balanceOf(susdWhaleAddress)

      console.log('out: ' + Number(BigInt(amountOut) / 10n ** 16n) / 100)
      console.log('rate: ' + Number(BigInt(amountOut) * 100n / amountIn) / 100)
    })
  })
})