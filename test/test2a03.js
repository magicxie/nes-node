var CPU, cpu2a03, should;

should = require('should');

cpu2a03 = require('../src/2a03');

CPU = cpu2a03.CPU;

describe('CPU init', function() {
  return it('should has a 16k ram', function() {
    var cpu;
    cpu = new CPU;
    return cpu.ram.length.should.eql(0x10000);
  });
});

describe('Memory read', function() {
  var address, cpu;
  cpu = new CPU;
  address = 0xAA;
  beforeEach(function() {
    cpu.ram[address] = 0x11;
    return cpu.ram[address + 1] = 0x2A;
  });
  it('should read 1 byte', function() {
    return cpu.read(address).should.be.eql(0x11);
  });
  it('should read L byte', function() {
    return cpu.read(address, cpu.READ_LENGTH.L).should.be.eql(0x11);
  });
  return it('should read 2 bytes', function() {
    return cpu.read(address, cpu.READ_LENGTH.HL).should.be.eql(0x2A11);
  });
});

describe('P register', function() {
  var cpu;
  cpu = new CPU;
  it('Should set P sequentially', function() {
    cpu.setSR(0xDC);
    cpu.N.should.be.eql(1);
    cpu.V.should.be.eql(1);
    cpu.U.should.be.eql(0);
    cpu.B.should.be.eql(1);
    cpu.D.should.be.eql(1);
    cpu.I.should.be.eql(1);
    cpu.Z.should.be.eql(0);
    return cpu.C.should.be.eql(0);
  });
  return it('Should get P sequentially', function() {
    cpu.N = 1;
    cpu.V = 1;
    cpu.U = 0;
    cpu.B = 1;
    cpu.D = 1;
    cpu.I = 1;
    cpu.Z = 0;
    cpu.C = 0;
    return cpu.getSR().should.be.eql(0xDC);
  });
});

describe('Stack', function() {
  var cpu;
  cpu = new CPU;
  it('Push 1 byte should increase sp once', function() {
    var prevSP;
    prevSP = cpu.SP;
    cpu.push(0xAA);
    cpu.ram[CPU.prototype.BASE_STACK_ADDR + prevSP].should.be.eql(0xAA);
    return (prevSP - cpu.SP).should.be.eql(1);
  });
  it('Push 2 bytes should increase sp twice', function() {
    var prevSP;
    prevSP = cpu.SP;
    cpu.push(0xAABB);
    cpu.ram[CPU.prototype.BASE_STACK_ADDR + prevSP - 1].should.be.eql(0xBB);
    cpu.ram[CPU.prototype.BASE_STACK_ADDR + prevSP].should.be.eql(0xAA);
    return (prevSP - cpu.SP).should.be.eql(2);
  });
  it('Pop 1 byte, sp should remain the same', function() {
    var prevSP;
    prevSP = cpu.SP;
    cpu.push(0xBA);
    cpu.pop().should.be.eql(0xBA);
    return cpu.SP.should.be.eql(prevSP);
  });
  return it('Push 2 bytes, should pop low byte', function() {
    var prevSP;
    prevSP = cpu.SP;
    cpu.push(0xBACD);
    cpu.pop().should.be.eql(0xCD);
    return (prevSP - cpu.SP).should.be.eql(1);
  });
});

describe('Interruption', function() {
  var cpu;
  cpu = new CPU;
  cpu.ram[CPU.prototype.VECTOR_TABLE.NMI] = 0xAA;
  cpu.ram[CPU.prototype.VECTOR_TABLE.NMI + 1] = 0xAB;
  cpu.ram[CPU.prototype.VECTOR_TABLE.IRQ] = 0xBA;
  cpu.ram[CPU.prototype.VECTOR_TABLE.IRQ + 1] = 0xBB;
  cpu.ram[CPU.prototype.VECTOR_TABLE.RST] = 0xCA;
  cpu.ram[CPU.prototype.VECTOR_TABLE.RST + 1] = 0xCB;
  it('should find NMI handler', function() {
    cpu.NMI();
    return cpu.PC.should.be.eql(0xABAA);
  });
  it('should find IRQ handler', function() {
    cpu.IRQ();
    return cpu.PC.should.be.eql(0xBBBA);
  });
  return it('should find RST handler', function() {
    cpu.RST();
    return cpu.PC.should.be.eql(0xCBCA);
  });
});

describe('Addressing mode', function() {
  var cpu;
  cpu = new CPU;
  it('should find oper immediately', function() {
    return cpu.immediate(0xAD).operand.should.eql(0xAD);
  });
  it('should find oper absolutely', function() {
    cpu.ram[0xAD] = 0xD;
    return cpu.absolute(0xAD).operand.should.eql(0xD);
  });
  it('should find oper absolutelyX', function() {
    cpu.XR = 0x0C;
    cpu.ram[0xB9] = 0xDA;
    return cpu.absoluteX(0xAD).operand.should.eql(0xDA);
  });
  it('should find oper absolutelyY', function() {
    cpu.YR = 0x0D;
    cpu.ram[0xBA] = 0xDB;
    return cpu.absoluteY(0xAD).operand.should.eql(0xDB);
  });
  it('should find oper immediately', function() {
    return cpu.immediate(0xBB).operand.should.eql(0xBB);
  });
  it('should find oper implied', function() {
    cpu.AC = 0xDD;
    return cpu.implied(0xAD).operand.should.eql(0xDD);
  });
  it('should find oper indirectly', function() {
    cpu.ram[0x0A] = 0xBA;
    cpu.ram[0xBA] = 0xDB;
    return cpu.indirect(0x0A).operand.should.eql(0xDB);
  });
  it('should find oper indirectlyX', function() {
    cpu.ram[0xBA] = 0xCD;
    cpu.ram[0xCD] = 0xDD;
    cpu.XR = 0xB0;
    return cpu.indirectX(0xAA0A).operand.should.eql(0xDD);
  });
  it('should find oper indirectlyY', function() {
    cpu.ram[0xBA] = 0xCD;
    cpu.ram[0xCD] = 0xDD;
    cpu.YR = 0xB0;
    return cpu.indirectY(0xAA0A).operand.should.eql(0xDD);
  });
  it('should find oper relatively', function() {
    cpu.ram[0xBA] = 0xED;
    cpu.PC = 0xB0;
    return cpu.relative(0x0A).operand.should.eql(0xED);
  });
  it('should find oper zeropage', function() {
    cpu.ram[0x0A] = 0xCD;
    return cpu.zeropage(0xAA0A).operand.should.eql(0xCD);
  });
  it('should find oper zeropageX', function() {
    cpu.ram[0xCA] = 0xCC;
    cpu.XR = 0xC0;
    return cpu.zeropageX(0xAA0A).operand.should.eql(0xCC);
  });
  return it('should find oper zeropageY', function() {
    cpu.ram[0xDA] = 0xED;
    cpu.YR = 0xD0;
    return cpu.zeropageY(0xAA0A).operand.should.eql(0xED);
  });
});

describe('negative and zero', function() {
  var cpu;
  cpu = new CPU;
  it('should be zero', function() {
    cpu.setZ(0);
    return cpu.Z.should.eql(1);
  });
  it('should not be zero', function() {
    cpu.setZ(1);
    return cpu.Z.should.eql(0);
  });
  it('should be negative', function() {
    cpu.setN(0x80);
    return cpu.N.should.eql(1);
  });
  it('should be positive', function() {
    cpu.setN(0x70);
    return cpu.N.should.eql(0);
  });
  return it('should be zero', function() {
    cpu.setN(0x00);
    return cpu.N.should.eql(0);
  });
});

describe('Binary Accumulate', function() {
  var cpu;
  cpu = new CPU;
  beforeEach(function() {
    cpu.CLD();
    return cpu.D.should.eql(0);
  });
  return it('should be: 88 + 70 + 1 = 159', function() {
    cpu.SEC();
    cpu.AC = 0x58;
    return cpu.accumulate(0x46, cpu.AC, cpu.C).should.eql(159);
  });
});

describe('SBC', function() {
  var cpu;
  cpu = new CPU;
  return it('88 - 86  = 2', function() {
    cpu.SEC();
    cpu.AC = 0x58;
    cpu.SBC({
      operand: 0x57,
      addressMode: cpu.implied(0x57)
    });
    return cpu.AC.should.be.eql(2);
  });
});

describe('ASL', function() {
  var cpu;
  cpu = new CPU;
  return it('Accumulator 88 << 1 = 176', function() {
    var addressMode;
    cpu.AC = 0x58;
    addressMode = cpu.accumulator();
    cpu.ASL({
      operand: addressMode.operand,
      addressMode: addressMode
    });
    return cpu.AC.should.be.eql(0xB0);
  });
});

describe('Branch instruction test', function() {
  var addressMode, cpu, oper, stepInfo;
  cpu = new CPU;
  oper = 0x10;
  addressMode = cpu.relative(oper);
  stepInfo = {
    operand: addressMode.operand,
    addressMode: addressMode
  };
  beforeEach(function() {
    return cpu.PC = 0x00;
  });
  describe('BCC', function() {
    it('Branch on C = 0', function() {
      cpu.C = 0;
      cpu.BCC(stepInfo);
      return cpu.PC.should.be.eql(addressMode.address);
    });
    return it('Do not branch on C = 1', function() {
      cpu.C = 1;
      cpu.BCC(stepInfo);
      return cpu.PC.should.be.eql(0x00);
    });
  });
  describe('BCS', function() {
    it('Branch on C = 1', function() {
      cpu.C = 1;
      cpu.BCS(stepInfo);
      return cpu.PC.should.be.eql(addressMode.address);
    });
    return it('Do not branch on C = 0', function() {
      cpu.C = 0;
      cpu.BCS(stepInfo);
      return cpu.PC.should.be.eql(0x00);
    });
  });
  describe('BEQ', function() {
    it('Branch on Z = 1', function() {
      cpu.Z = 1;
      cpu.BEQ(stepInfo);
      return cpu.PC.should.be.eql(addressMode.address);
    });
    return it('Do not branch on Z = 0', function() {
      cpu.Z = 0;
      cpu.BEQ(stepInfo);
      return cpu.PC.should.be.eql(0x00);
    });
  });
  describe('BMI', function() {
    it('Branch on N = 1', function() {
      cpu.N = 1;
      cpu.BMI(stepInfo);
      return cpu.PC.should.be.eql(addressMode.address);
    });
    return it('Do not branch on N = 0', function() {
      cpu.N = 0;
      cpu.BMI(stepInfo);
      return cpu.PC.should.be.eql(0x00);
    });
  });
  describe('BNE', function() {
    it('Branch on Z = 0', function() {
      cpu.Z = 0;
      cpu.BNE(stepInfo);
      return cpu.PC.should.be.eql(addressMode.address);
    });
    return it('Do not branch on Z = 1', function() {
      cpu.Z = 1;
      cpu.BNE(stepInfo);
      return cpu.PC.should.be.eql(0x00);
    });
  });
  return describe('BPL', function() {
    it('Branch on N = 0', function() {
      cpu.N = 0;
      cpu.BPL(stepInfo);
      return cpu.PC.should.be.eql(addressMode.address);
    });
    return it('Do not branch on N = 1', function() {
      cpu.N = 1;
      cpu.BPL(stepInfo);
      return cpu.PC.should.be.eql(0x00);
    });
  });
});

describe('BIT', function() {
  var addressMode, cpu, oper, stepInfo;
  cpu = new CPU;
  cpu.ram[0x00] = 0x01;
  oper = 0x00;
  addressMode = cpu.absolute(oper);
  stepInfo = {
    operand: addressMode.operand,
    addressMode: addressMode
  };
  it('Z should be 1', function() {
    cpu.AC = 0x01;
    cpu.BIT(stepInfo);
    cpu.Z.should.be.eql(1);
    cpu.N.should.be.eql(0);
    return cpu.V.should.be.eql(0);
  });
  it('Z should be 0', function() {
    cpu.AC = 0x00;
    cpu.BIT(stepInfo);
    cpu.Z.should.be.eql(0);
    cpu.N.should.be.eql(0);
    return cpu.V.should.be.eql(0);
  });
  it('N should be 1', function() {
    cpu.ram[0x00] = 0x80;
    oper = 0x00;
    addressMode = cpu.absolute(oper);
    stepInfo = {
      operand: addressMode.operand,
      addressMode: addressMode
    };
    cpu.AC = 0x00;
    cpu.BIT(stepInfo);
    cpu.Z.should.be.eql(0);
    cpu.N.should.be.eql(1);
    return cpu.V.should.be.eql(0);
  });
  it('Z should be 1', function() {
    cpu.ram[0x00] = 0x81;
    oper = 0x00;
    addressMode = cpu.absolute(oper);
    stepInfo = {
      operand: addressMode.operand,
      addressMode: addressMode
    };
    cpu.AC = 0x01;
    cpu.BIT(stepInfo);
    cpu.Z.should.be.eql(1);
    cpu.N.should.be.eql(1);
    return cpu.V.should.be.eql(0);
  });
  return it('Z ,V and N should be 1', function() {
    cpu.ram[0x00] = 0xC1;
    oper = 0x00;
    addressMode = cpu.absolute(oper);
    stepInfo = {
      operand: addressMode.operand,
      addressMode: addressMode
    };
    cpu.AC = 0x01;
    cpu.BIT(stepInfo);
    cpu.Z.should.be.eql(1);
    cpu.N.should.be.eql(1);
    return cpu.V.should.be.eql(1);
  });
});

describe('BRK', function() {
  var cpu;
  cpu = new CPU;
  cpu.ram[CPU.prototype.VECTOR_TABLE.NMI] = 0x34;
  cpu.ram[CPU.prototype.VECTOR_TABLE.NMI + 1] = 0x12;
  return it('should break, as nmi interruption', function() {
    cpu.BRK();
    return cpu.PC.should.be.eql(0x1234);
  });
});

describe('Clear bytes', function() {
  var cpu;
  cpu = new CPU;
  it('should be interrupt disable', function() {
    cpu.CLI();
    return cpu.I.should.be.eql(0);
  });
  it('should be overflow clear', function() {
    cpu.CLV();
    return cpu.V.should.be.eql(0);
  });
  return it('should be D clear', function() {
    cpu.CLD();
    return cpu.D.should.be.eql(0);
  });
});

describe('Compare instructions', function() {
  var cpu;
  cpu = new CPU;
  cpu.ram[0x10] = 0xDE;
  beforeEach(function() {
    cpu.C = 0;
    cpu.N = 0;
    return cpu.Z = 0;
  });
  describe('CMP', function() {
    return it('should be A > M', function() {
      cpu.AC = 0xDF;
      cpu.CMP({
        operand: 0xDE
      });
      cpu.Z.should.be.eql(0);
      cpu.N.should.be.eql(0);
      return cpu.C.should.be.eql(1);
    });
  });
  describe('CPX', function() {
    return it('should be X > M', function() {
      cpu.XR = 0xDF;
      cpu.CPX({
        operand: 0xDE
      });
      cpu.Z.should.be.eql(0);
      cpu.N.should.be.eql(0);
      return cpu.C.should.be.eql(1);
    });
  });
  return describe('CPY', function() {
    return it('should be Y > M', function() {
      cpu.YR = 0xDF;
      cpu.CPY({
        operand: 0xDE
      });
      cpu.Z.should.be.eql(0);
      cpu.N.should.be.eql(0);
      return cpu.C.should.be.eql(1);
    });
  });
});

describe('Test run', function() {
  var cpu;
  cpu = new CPU;
  return it('should get PC', function() {
    cpu.ram[CPU.prototype.PC_INIT_VAL] = 0x38;
    cpu.ram[CPU.prototype.PC_INIT_VAL + 1] = 0x02;
    cpu.run();
    return cpu.PC.should.be.eql(CPU.prototype.PC_INIT_VAL + 1);
  });
});

//# sourceMappingURL=test2a03.js.map
