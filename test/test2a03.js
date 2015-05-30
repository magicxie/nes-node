// Generated by CoffeeScript 1.9.3
(function() {
  var CPU, cpu6502, should;

  should = require('should');

  cpu6502 = require('../src/2a03');

  CPU = cpu6502.CPU;

  describe('CPU init', function() {
    var cpu;
    it('should has a 16k ram', function() {});
    cpu = new CPU;
    return cpu.ram.length.should.eql(0x10000);
  });

  describe('Addressing mode', function() {
    var cpu;
    cpu = new CPU;
    it('should find oper immidiate', function() {
      return cpu.immediate(0xAD).should.eql(0xAD);
    });
    it('should find oper absolute', function() {
      cpu.ram[0xAD] = 0xD;
      return cpu.absolute(0xAD).should.eql(0xD);
    });
    it('should find oper absoluteX', function() {
      cpu.XR = 0x0C;
      cpu.ram[0xB9] = 0xDA;
      return cpu.absoluteX(0xAD).should.eql(0xDA);
    });
    it('should find oper absoluteY', function() {
      cpu.YR = 0x0D;
      cpu.ram[0xBA] = 0xDB;
      return cpu.absoluteY(0xAD).should.eql(0xDB);
    });
    it('should find oper immediate', function() {
      return cpu.immediate(0xBB).should.eql(0xBB);
    });
    it('should find oper implied', function() {
      cpu.AC = 0xDD;
      return cpu.implied(0xAD).should.eql(0xDD);
    });
    it('should find oper indirect', function() {
      cpu.ram[0x0A] = 0xBA;
      cpu.ram[0xBA] = 0xDB;
      return cpu.indirect(0x0A).should.eql(0xDB);
    });
    it('should find oper indirectX', function() {
      cpu.ram[0xBA] = 0xCD;
      cpu.ram[0xCD] = 0xDD;
      cpu.XR = 0xB0;
      return cpu.indirectX(0xAA0A).should.eql(0xDD);
    });
    it('should find oper indirectY', function() {
      cpu.ram[0xBA] = 0xCD;
      cpu.ram[0xCD] = 0xDD;
      cpu.YR = 0xB0;
      return cpu.indirectY(0xAA0A).should.eql(0xDD);
    });
    it('should find oper relative', function() {
      cpu.ram[0xBA] = 0xED;
      cpu.PC = 0xB0;
      return cpu.relative(0x0A).should.eql(0xED);
    });
    it('should find oper zeropage', function() {
      cpu.ram[0x0A] = 0xCD;
      return cpu.zeropage(0xAA0A).should.eql(0xCD);
    });
    it('should find oper zeropageX', function() {
      cpu.ram[0xCA] = 0xCC;
      cpu.XR = 0xC0;
      return cpu.zeropageX(0xAA0A).should.eql(0xCC);
    });
    return it('should find oper zeropageY', function() {
      cpu.ram[0xDA] = 0xED;
      cpu.YR = 0xD0;
      return cpu.zeropageY(0xAA0A).should.eql(0xED);
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
      cpu.accumulate(0x46, cpu.AC, CPU.C);
      return cpu.AC.should.eql(159);
    });
  });

  describe('OPC 69', function() {
    var cpu;
    cpu = new CPU;
    beforeEach(function() {
      return cpu.clear();
    });
    return it('should be ADC immidiate', function() {
      return cpu.ram.length.should.eql(0x10000);
    });
  });

}).call(this);