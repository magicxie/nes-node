should = require 'should'
cpu2a03 = require '../src/2a03'

CPU = cpu2a03.CPU

describe 'CPU init', ->
  it 'should has a 16k ram', ->
  cpu = new CPU
  cpu.ram.length.should.eql 0x10000

describe 'Addressing mode', ->
  cpu = new CPU
  it 'should find oper immidiate', ->
    cpu.immediate(0xAD).operand.should.eql 0xAD

  it 'should find oper absolute', ->
    cpu.ram[0xAD] = 0xD
    cpu.absolute(0xAD).operand.should.eql 0xD

  it 'should find oper absoluteX', ->
    cpu.XR = 0x0C
    cpu.ram[0xB9] = 0xDA
    cpu.absoluteX(0xAD).operand.should.eql 0xDA

  it 'should find oper absoluteY', ->
    cpu.YR = 0x0D
    cpu.ram[0xBA] = 0xDB
    cpu.absoluteY(0xAD).operand.should.eql 0xDB

  it 'should find oper immediate', ->
    cpu.immediate(0xBB).operand.should.eql 0xBB

  it 'should find oper implied', ->
    cpu.AC = 0xDD
    cpu.implied(0xAD).operand.should.eql 0xDD

  it 'should find oper indirect', ->
    cpu.ram[0x0A] = 0xBA
    cpu.ram[0xBA] = 0xDB
    cpu.indirect(0x0A).operand.should.eql 0xDB

  it 'should find oper indirectX', ->
    cpu.ram[0xBA] = 0xCD
    cpu.ram[0xCD] = 0xDD
    cpu.XR = 0xB0
    cpu.indirectX(0xAA0A).operand.should.eql 0xDD

  it 'should find oper indirectY', ->
    cpu.ram[0xBA] = 0xCD
    cpu.ram[0xCD] = 0xDD
    cpu.YR = 0xB0
    cpu.indirectY(0xAA0A).operand.should.eql 0xDD


  it 'should find oper relative', ->
    cpu.ram[0xBA] = 0xED
    cpu.PC = 0xB0
    cpu.relative(0x0A).operand.should.eql 0xED

  it 'should find oper zeropage', ->
    cpu.ram[0x0A] = 0xCD
    cpu.zeropage(0xAA0A).operand.should.eql 0xCD

  it 'should find oper zeropageX', ->
    cpu.ram[0xCA] = 0xCC
    cpu.XR = 0xC0
    cpu.zeropageX(0xAA0A).operand.should.eql 0xCC

  it 'should find oper zeropageY', ->
    cpu.ram[0xDA] = 0xED
    cpu.YR = 0xD0
    cpu.zeropageY(0xAA0A).operand.should.eql 0xED

describe 'negative and zero', ->
  cpu = new CPU

  it 'should be zero', ->
    cpu.setZ(0)
    cpu.Z.should.eql 1

  it 'should not be zero', ->
    cpu.setZ(1)
    cpu.Z.should.eql 0

  it 'should be negative', ->
    cpu.setN(0x80)
    cpu.N.should.eql 1

  it 'should be positive', ->
    cpu.setN(0x70)
    cpu.N.should.eql 0

  it 'should be zero', ->
    cpu.setN(0x00)
    cpu.N.should.eql 0


describe 'Binary Accumulate', ->
  cpu = new CPU

  beforeEach ->
    cpu.CLD()
    cpu.D.should.eql 0

  it 'should be: 88 + 70 + 1 = 159', ->
    cpu.SEC()
    cpu.AC = 0x58
    cpu.accumulate(0x46,cpu.AC, cpu.C).should.eql 159

describe 'SBC', ->

  cpu = new CPU

  it '88 - 86  = 2', ->
    cpu.SEC()
    cpu.AC = 0x58
    cpu.SBC {operand : 0x57, addressMode:cpu.implied(0x57)}
    cpu.AC.should.be.eql 2

describe 'ASL', ->

  cpu = new CPU

  it 'Accumulator 88 << 1 = 176', ->
    cpu.AC = 0x58
    addressMode = cpu.accumulator()
    cpu.ASL {operand : addressMode.operand, addressMode:addressMode}
    cpu.AC.should.be.eql 0xB0

describe 'Branch instruction test', ->

  cpu = new CPU

  oper = 0x10
  addressMode = cpu.relative(oper)
  stepInfo = {operand : addressMode.operand, addressMode:addressMode}

  beforeEach ->
    cpu.PC = 0x00

  describe 'BCC', ->

    it 'Branch on C = 0', ->

      cpu.C = 0

      cpu.BCC stepInfo
      cpu.PC.should.be.eql addressMode.address

    it 'Do not branch on C = 1', ->

      cpu.C = 1

      cpu.BCC stepInfo
      cpu.PC.should.be.eql 0x00

  describe 'BCS', ->

    it 'Branch on C = 1', ->

      cpu.C = 1

      cpu.BCS stepInfo
      cpu.PC.should.be.eql addressMode.address

    it 'Do not branch on C = 0', ->

      cpu.C = 0

      cpu.BCS stepInfo
      cpu.PC.should.be.eql 0x00

  describe 'BEQ', ->

    it 'Branch on Z = 1', ->

      cpu.Z = 1

      cpu.BEQ stepInfo
      cpu.PC.should.be.eql addressMode.address

    it 'Do not branch on Z = 0', ->

      cpu.Z = 0

      cpu.BEQ stepInfo
      cpu.PC.should.be.eql 0x00

  describe 'BMI', ->

    it 'Branch on N = 1', ->

      cpu.N = 1

      cpu.BMI stepInfo
      cpu.PC.should.be.eql addressMode.address

    it 'Do not branch on N = 0', ->

      cpu.N = 0

      cpu.BMI stepInfo
      cpu.PC.should.be.eql 0x00

  describe 'BNE', ->

    it 'Branch on Z = 0', ->

      cpu.Z = 0

      cpu.BNE stepInfo
      cpu.PC.should.be.eql addressMode.address

    it 'Do not branch on Z = 1', ->

      cpu.Z = 1

      cpu.BNE stepInfo
      cpu.PC.should.be.eql 0x00

  describe 'BPL', ->

    it 'Branch on N = 0', ->

      cpu.N = 0

      cpu.BPL stepInfo
      cpu.PC.should.be.eql addressMode.address

    it 'Do not branch on N = 1', ->

      cpu.N = 1

      cpu.BPL stepInfo
      cpu.PC.should.be.eql 0x00


describe 'BIT', ->

  cpu = new CPU
  cpu.ram[0x00] = 0x01

  oper = 0x00
  addressMode = cpu.absolute(oper)
  stepInfo = {operand : addressMode.operand, addressMode:addressMode}

  it 'Z should be 1', ->

    cpu.AC = 0x01
    cpu.BIT stepInfo
    cpu.Z.should.be.eql 1
    cpu.N.should.be.eql 0
    cpu.V.should.be.eql 0

  it 'Z should be 0', ->

    cpu.AC = 0x00
    cpu.BIT stepInfo
    cpu.Z.should.be.eql 0
    cpu.N.should.be.eql 0
    cpu.V.should.be.eql 0

  it 'N should be 1', ->

    cpu.ram[0x00] = 0x80
    oper = 0x00
    addressMode = cpu.absolute(oper)
    stepInfo = {operand : addressMode.operand, addressMode:addressMode}

    cpu.AC = 0x00
    cpu.BIT stepInfo
    cpu.Z.should.be.eql 0
    cpu.N.should.be.eql 1
    cpu.V.should.be.eql 0

  it 'Z should be 1', ->

    cpu.ram[0x00] = 0x81
    oper = 0x00
    addressMode = cpu.absolute(oper)
    stepInfo = {operand : addressMode.operand, addressMode:addressMode}

    cpu.AC = 0x01
    cpu.BIT stepInfo
    cpu.Z.should.be.eql 1
    cpu.N.should.be.eql 1
    cpu.V.should.be.eql 0

  it 'Z ,V and N should be 1', ->

    cpu.ram[0x00] = 0xC1
    oper = 0x00
    addressMode = cpu.absolute(oper)
    stepInfo = {operand : addressMode.operand, addressMode:addressMode}

    cpu.AC = 0x01
    cpu.BIT stepInfo
    cpu.Z.should.be.eql 1
    cpu.N.should.be.eql 1
    cpu.V.should.be.eql 1

describe 'OPC 69', ->
  cpu = new CPU
  beforeEach ->
    cpu.clear()
  it 'should be ADC immediate', ->
    cpu.ram.length.should.eql 0x10000
