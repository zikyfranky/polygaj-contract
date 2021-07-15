const { expect } = require("chai");

describe('MasterChef', () => {
    let dfault, bob, feeAddress, dev, rest

    beforeEach(async () => {
        [dfault, bob, feeAddress, dev, alice, ...rest] = await ethers.getSigners();
        const MasterChef = await ethers.getContractFactory("MasterChef");
        const GajToken = await ethers.getContractFactory("GajToken");
        const MockERC201 = await ethers.getContractFactory("MockERC20");
        const MockERC202 = await ethers.getContractFactory("MockERC20");
        const MockERC203 = await ethers.getContractFactory("MockERC20");
        this.gaj = await GajToken.deploy()
        this.lp1 = await MockERC201.deploy('LPToken', 'LP1', '1000000');
        this.lp2 = await MockERC202.deploy('LPToken', 'LP2', '1000000');
        this.lp3 = await MockERC203.deploy('LPToken', 'LP3', '1000000');
        this.chef = await MasterChef.deploy(this.gaj.address, dev.address, feeAddress.address, '1000', '100');
        await this.gaj.transferOwnership(this.chef.address);

        await this.lp1.transfer(bob.address, '2000');
        await this.lp2.transfer(bob.address, '2000');
        await this.lp3.transfer(bob.address, '2000');

        await this.lp1.transfer(alice.address, '2000');
        await this.lp2.transfer(alice.address, '2000');
        await this.lp3.transfer(alice.address, '2000');
    });
    it('real case', async () => {
      await this.chef.add("2000", this.lp1.address, "300", true);
      await this.chef.add("1000", this.lp2.address, "300", true);
      await this.chef.add("500", this.lp3.address, "300", true);
      await this.chef.add("100", this.lp3.address, "300", true);
      const len = (await this.chef.poolLength()).toString();
      expect(len).to.equal("4");

      await this.lp1.connect(alice).approve(this.chef.address, "1000");
      alice_balance = (await this.gaj.balanceOf(alice.address)).toString();
      expect(alice_balance).to.equal("0");

      await this.chef.connect(alice).deposit(0, "20");
      // go to next 100 blocks (to generate gaj from staking)
      for(i=0; i<100; i++){
        await ethers.provider.send("evm_mine");
      }
      await this.chef.connect(alice).withdraw(0, "20");
      alice_balance = (await this.gaj.balanceOf(alice.address)).toString();
      expect(alice_balance).to.equal("10555");
    })


    it('deposit/withdraw', async () => {
      await this.chef.add('1000', this.lp1.address, '300', true);
      await this.chef.add('1000', this.lp2.address, '300', true);
      await this.chef.add('1000', this.lp3.address, '300', true);

      await this.lp1.connect(alice).approve(this.chef.address, '100');
      await this.chef.connect(alice).deposit(0, '20');
      await this.chef.connect(alice).deposit(0, '0');
      await this.chef.connect(alice).deposit(0, '40');
      await this.chef.connect(alice).deposit(0, '0');
      alice_lp1_balance = (await this.lp1.balanceOf(alice.address)).toString()
      expect(alice_lp1_balance).to.equal('1940');

      await this.chef.connect(alice).withdraw(0, '10');
      alice_lp1_balance = (await this.lp1.balanceOf(alice.address)).toString()
      alice_gaj_balance = (await this.gaj.balanceOf(alice.address)).toString()
      dev_gaj_balance = (await this.gaj.balanceOf(dev.address)).toString()
      expect(alice_lp1_balance).to.equal('1950');
      expect(alice_gaj_balance).to.equal('1332');
      expect(dev_gaj_balance).to.equal('132');

      await this.lp1.connect(bob).approve(this.chef.address, '100');
      bob_lp1_balance = (await this.lp1.balanceOf(bob.address)).toString()
      expect(bob_lp1_balance).to.equal('2000');
      
      await this.chef.connect(bob).deposit(0, '50');
      bob_lp1_balance = (await this.lp1.balanceOf(bob.address)).toString()
      expect(bob_lp1_balance).to.equal('1950');
      
      await this.chef.connect(bob).deposit(0, '0');
      bob_gaj_balance = (await this.gaj.balanceOf(bob.address)).toString()
      expect(bob_gaj_balance).to.equal('167');
      
      await this.chef.connect(bob).emergencyWithdraw(0);
      bob_lp1_balance = (await this.lp1.balanceOf(bob.address)).toString()
      expect(bob_lp1_balance).to.equal('1999'); // fee will be subtracted
    })

    it('should allow dev and only dev to update dev', async () => {
        chef_dev = (await this.chef.devaddr()).valueOf()
        expect(chef_dev).to.equal(dev.address);
        await expect(this.chef.connect(bob).dev(bob.address)).to.be.revertedWith("dev: wut?");

        await this.chef.connect(dev).dev(bob.address);
        chef_dev = (await this.chef.devaddr()).valueOf()
        expect(chef_dev).to.equal(bob.address);
        
        await this.chef.connect(bob).dev(alice.address);
        chef_dev = (await this.chef.devaddr()).valueOf()
        expect(chef_dev).to.equal(alice.address);
    })

    it('should allow feeAddress and only feeAddress to update feeAddress', async () => {
        chef_feeAddress = (await this.chef.feeAddress()).valueOf()
        expect(chef_feeAddress).to.equal(feeAddress.address);
        await expect(this.chef.connect(bob).setFeeAddress(bob.address)).to.be.revertedWith("setFeeAddress: FORBIDDEN");

        await this.chef.connect(feeAddress).setFeeAddress(bob.address);
        chef_feeAddress = (await this.chef.feeAddress()).valueOf()
        expect(chef_feeAddress).to.equal(bob.address);
        
        await this.chef.connect(bob).setFeeAddress(alice.address);
        chef_feeAddress = (await this.chef.feeAddress()).valueOf()
        expect(chef_feeAddress).to.equal(alice.address);
    })
});