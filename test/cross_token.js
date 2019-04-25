const { BN, constants, expectEvent, shouldFail } = require('openzeppelin-test-helpers');

var CrossToken = artifacts.require("./CrossToken.sol");

function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}



contract('CrossToken', function(accounts) {

  it("Initial asset amount", async () => {
     const cross_token = await CrossToken.deployed();
      let numb = (new BN(10)).pow(new BN(18)).mul(new BN(10000));
      (await cross_token.balanceOf(accounts[0])).should.be.bignumber.equal( numb );
    return;
  });

    it("open channel", async function() {
        const cross_token = await CrossToken.deployed();
        await cross_token.openChannel(accounts[1],199);
        let numb = (new BN(10)).pow(new BN(18)).mul(new BN(10000)).sub(new BN(199));
        (await cross_token.balanceOf(accounts[0])).should.be.bignumber.equal( numb );
        return;
    });

    it("close channel", async function() {
        const cross_token = await CrossToken.deployed();

        // await cross_token.openChannel(accounts[1],199);
        await sleep(11000);

        await cross_token.fixChannel(accounts[1]);
        let numb = (new BN(10)).pow(new BN(18)).mul(new BN(10000));
        (await cross_token.balanceOf(accounts[0])).should.be.bignumber.equal( numb );
        // assert.fail('Expected throw not received');
        return;
    });

    it("reopen channel", async function() {
        const cross_token = await CrossToken.deployed();
        await cross_token.openChannel(accounts[1],199);
        let numb = (new BN(10)).pow(new BN(18)).mul(new BN(10000)).sub(new BN(199));
        (await cross_token.balanceOf(accounts[0])).should.be.bignumber.equal( numb );
        return;
    });

    it("send tx in channel", async function() {
        const cross_token = await CrossToken.deployed();

        const value = 100;
        const block = await cross_token.getStateChannelBlock(accounts[0],accounts[1]);
        const nonce = await cross_token.getStateChannelNonce(accounts[0],accounts[1]);
        const hash =  web3.utils.soliditySha3(
            { type: 'address', value: cross_token.address},
            { type: 'address', value: accounts[0].toString()},
            { type: 'address', value: accounts[1].toString()},
            { type: 'uint', value: block},
            { type: 'uint256', value: nonce},
            { type: 'uint256', value: value},
        );
        const signature = await web3.eth.sign(hash, accounts[0]);

        const r = signature.substr(0, 66);
        const s = '0x' + signature.substr(66, 64);
        const v = '0x' + (parseInt(signature.substr(130, 2),16)+27).toString(16);

        await cross_token.sendInChannel(accounts[0], accounts[1],value,v,r,s);

        return;
    });

    it("close channel", async function() {
        const cross_token = await CrossToken.deployed();
        await sleep(11000);
        await cross_token.fixChannel(accounts[1]);
        return;
    });

    it("balance of account[0]", async function() {
        const cross_token = await CrossToken.deployed();
        let numb = (new BN(10)).pow(new BN(18)).mul(new BN(10000)).sub(new BN(100));
        (await cross_token.balanceOf(accounts[0])).should.be.bignumber.equal( numb );
        // assert.fail('Expected throw not received');
        return;
    });

    it("balance of account[1]", async function() {
        const cross_token = await CrossToken.deployed();
        (await cross_token.balanceOf(accounts[1])).should.be.bignumber.equal( new BN(100) );
        return;
    });


    it("reopen channel", async function() {
        const cross_token = await CrossToken.deployed();
        await cross_token.openChannel(accounts[1],199);
        let numb = (new BN(10)).pow(new BN(18)).mul(new BN(10000)).sub(new BN(199)).sub(new BN(100));
        (await cross_token.balanceOf(accounts[0])).should.be.bignumber.equal( numb );
        return;
    });

    it("send tx in channel", async function() {
        const cross_token = await CrossToken.deployed();

        const value = 100;
        const block = await cross_token.getStateChannelBlock(accounts[0],accounts[1]);
        const nonce = await cross_token.getStateChannelNonce(accounts[0],accounts[1]);
        const hash =  web3.utils.soliditySha3(
            { type: 'address', value: cross_token.address},
            { type: 'address', value: accounts[0].toString()},
            { type: 'address', value: accounts[1].toString()},
            { type: 'uint', value: block},
            { type: 'uint256', value: nonce},
            { type: 'uint256', value: value},
        );
        const signature = await web3.eth.sign(hash, accounts[0]);

        const r = signature.substr(0, 66);
        const s = '0x' + signature.substr(66, 64);
        const v = '0x' + (parseInt(signature.substr(130, 2),16)+27).toString(16);

        await cross_token.sendInChannel(accounts[0], accounts[1],value,v,r,s);


        return;
    });

    it("chargeback in channel", async function() {
        const cross_token = await CrossToken.deployed();

        const value = 20;
        const block = await cross_token.getStateChannelBlock(accounts[0],accounts[1]);
        const nonce = await cross_token.getStateChannelNonce(accounts[0],accounts[1]);
        const hash =  web3.utils.soliditySha3(
            { type: 'address', value: cross_token.address},
            { type: 'address', value: accounts[0].toString()},
            { type: 'address', value: accounts[1].toString()},
            { type: 'uint', value: block},
            { type: 'uint256', value: nonce},
            { type: 'uint256', value: value},
        );
        const signature = await web3.eth.sign(hash, accounts[1]);

        const r = signature.substr(0, 66);
        const s = '0x' + signature.substr(66, 64);
        const v = '0x' + (parseInt(signature.substr(130, 2),16)+27).toString(16);

        await cross_token.chargebackInChannel(accounts[0], accounts[1],value,v,r,s);


        return;
    });

    it("close channel", async function() {
        const cross_token = await CrossToken.deployed();
        await sleep(11000);
        await cross_token.fixChannel(accounts[1]);
        return;
    });

    it("balance of account[0]", async function() {
        const cross_token = await CrossToken.deployed();
        let numb = (new BN(10)).pow(new BN(18)).mul(new BN(10000)).sub(new BN(100)).sub(new BN(80));
        (await cross_token.balanceOf(accounts[0])).should.be.bignumber.equal( numb );
        // assert.fail('Expected throw not received');
        return;
    });

    it("balance of account[1]", async function() {
        const cross_token = await CrossToken.deployed();
        (await cross_token.balanceOf(accounts[1])).should.be.bignumber.equal( new BN(180) );
        return;
    });



});
