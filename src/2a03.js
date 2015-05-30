var CPU;

CPU = (function() {
  CPU.prototype.PC = 0;

  CPU.prototype.AC = 0;

  CPU.prototype.XR = 0;

  CPU.prototype.YR = 0;

  CPU.prototype.SR = 0;

  CPU.prototype.SP = 0;

  CPU.prototype.N = 0;

  CPU.prototype.V = 0;

  CPU.prototype.U = 1;

  CPU.prototype.B = 0;

  CPU.prototype.D = 0;

  CPU.prototype.I = 0;

  CPU.prototype.Z = 0;

  CPU.prototype.C = 0;

  CPU.prototype.ram = [];

  CPU.prototype.ramSize = 0xFFFF;

  function CPU() {
    var i, ref, x;
    for (x = i = 0, ref = this.ramSize; 0 <= ref ? i <= ref : i >= ref; x = 0 <= ref ? ++i : --i) {
      this.ram[x] = 0;
    }
  }

  CPU.prototype.reset = function() {
    return this.PC = 0;
  };

  CPU.prototype.clear = function() {
    var i, ref, results, x;
    results = [];
    for (x = i = 0, ref = this.ramSize; 0 <= ref ? i <= ref : i >= ref; x = 0 <= ref ? ++i : --i) {
      results.push(this.ram[x] = 0);
    }
    return results;
  };

  CPU.prototype.printRegisters = function() {
    return console.log('AC=', this.AC, '(= BDC', this.AC.toString(16), ') V=', this.V, 'C=', this.C, 'N=', this.N, 'Z=', this.Z);
  };

  CPU.prototype.accumulator = function(oper) {
    return this.AC;
  };

  CPU.prototype.absolute = function(oper) {
    return this.ram[oper];
  };

  CPU.prototype.absoluteX = function(oper) {
    return this.ram[oper + this.XR];
  };

  CPU.prototype.absoluteY = function(oper) {
    return this.ram[oper + this.YR];
  };

  CPU.prototype.immediate = function(oper) {
    return oper;
  };

  CPU.prototype.implied = function(oper) {
    return this.AC;
  };

  CPU.prototype.indirect = function(oper) {
    return this.ram[this.ram[oper]];
  };

  CPU.prototype.indirectX = function(oper) {
    return this.ram[this.ram[(oper & 0x00FF) + this.XR]];
  };

  CPU.prototype.indirectY = function(oper) {
    return this.ram[this.ram[(oper & 0x00FF) + this.YR]];
  };

  CPU.prototype.relative = function(oper) {
    return this.ram[this.PC + oper];
  };

  CPU.prototype.zeropage = function(oper) {
    return this.ram[oper & 0x00FF];
  };

  CPU.prototype.zeropageX = function(oper) {
    return this.ram[(oper + this.XR) & 0x00FF];
  };

  CPU.prototype.zeropageY = function(oper) {
    return this.ram[(oper + this.YR) & 0x00FF];
  };

  CPU.prototype.addressing = function() {
    if (arguments.length === 2) {
      return arguments[1];
    } else {
      return this.immediate;
    }
  };

  CPU.prototype.accumulate = function(src, dst, carry) {
    return src + dst + carry;
  };

  CPU.prototype.setZ = function(oper) {
    return this.Z = oper === 0 ? 1 : 0;
  };

  CPU.prototype.setN = function(oper) {
    return this.N = (oper & 0x80) !== 0 ? 1 : 0;
  };

  CPU.prototype.setZN = function(oper) {
    setZ(oper);
    return setN(oper);
  };

  CPU.prototype.SED = function() {
    return this.D = 1;
  };

  CPU.prototype.SEC = function() {
    return this.C = 1;
  };

  CPU.prototype.CLC = function() {
    return this.C = 0;
  };

  CPU.prototype.CLD = function() {
    return this.D = 0;
  };

  CPU.prototype.LDA = function(oper) {
    return this.AC = this.addressing(arguments)(oper);
  };


  /*
  ADC  Add Memory to Accumulator with Carry
  
     A + M + C -> A, C                N Z C I D V
                                      + + + - - +
  
     addressing    assembler    opc  bytes  cyles
     --------------------------------------------
     immidiate     ADC #oper     69    2     2
     zeropage      ADC oper      65    2     3
     zeropage,X    ADC oper,X    75    2     4
     absolute      ADC oper      6D    3     4
     absolute,X    ADC oper,X    7D    3     4*
     absolute,Y    ADC oper,Y    79    3     4*
     (indirect,X)  ADC (oper,X)  61    2     6
     (indirect),Y  ADC (oper),Y  71    2     5*
   */

  CPU.prototype.ADC = function(oper) {
    var H4b;
    oper = this.addressing(arguments)(oper);
    this.AC = this.accumulate(oper, this.AC, this.C);
    console.log('@AC', this.AC);
    this.C = this.AC > 0xFF ? 1 : 0;
    setZN(this.AC);
    H4b = this.AC / 0x10;
    this.V = H4b >= -8 & H4b <= 7 ? 0 : 1;
    if (this.V === 1) {
      console.warn('High 4 bit', H4b.toString(16), 'is not in rage(-8~7). Overflow!!');
    }
    console.log('@H4b is', H4b.toString(16));
    this.AC = this.AC & 0xFF;
    return this.printRegisters();
  };

  CPU.prototype.SBC = function(oper, addressing) {
    return addressing(oper);
  };

  return CPU;

})();

exports.CPU = CPU;

//# sourceMappingURL=2a03.js.map
