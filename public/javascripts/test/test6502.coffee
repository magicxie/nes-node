should =  require 'should'
cpu6502 = require '../6502'

CPU = cpu6502.CPU

describe 'CPU init', ->
  it 'should has a 16k ram', ->
  cpu = new CPU
  cpu.ram.length.should.eql 0x10000

describe 'Addressing mode', ->
  cpu  = new CPU
  it 'should find oper immidiate', ->
    cpu.immediate(0xAD).should.eql 0xAD

  it 'should find oper absolute', ->
    cpu.ram[0xAD] = 0xD
    cpu.absolute(0xAD).should.eql 0xD

  it 'should find oper absoluteX', ->
    cpu.XR = 0x0C
    cpu.ram[0xB9]  = 0xDA
    cpu.absoluteX(0xAD).should.eql 0xDA

  it 'should find oper absoluteY', ->
    cpu.YR = 0x0D
    cpu.ram[0xBA]  = 0xDB
    cpu.absoluteY(0xAD).should.eql 0xDB

  it 'should find oper immediate', ->
    cpu.immediate(0xBB).should.eql 0xBB

  it 'should find oper implied', ->
    cpu.AC = 0xDD
    cpu.implied(0xAD).should.eql 0xDD

  it 'should find oper indirect', ->
    cpu.ram[0x0A]  = 0xBA
    cpu.ram[0xBA]  = 0xDB
    cpu.indirect(0x0A).should.eql 0xDB

  it 'should find oper indirectX', ->
    cpu.ram[0xBA]  = 0xCD
    cpu.ram[0xCD]  = 0xDD
    cpu.XR = 0xB0
    cpu.indirectX(0xAA0A).should.eql 0xDD

  it 'should find oper indirectY', ->
    cpu.ram[0xBA]  = 0xCD
    cpu.ram[0xCD]  = 0xDD
    cpu.YR = 0xB0
    cpu.indirectY(0xAA0A).should.eql 0xDD


  it 'should find oper relative', ->
    cpu.ram[0xBA]  = 0xED
    cpu.PC = 0xB0
    cpu.relative(0x0A).should.eql 0xED

  it 'should find oper zeropage', ->
    cpu.ram[0x0A]  = 0xCD
    cpu.zeropage(0xAA0A).should.eql 0xCD

  it 'should find oper zeropageX', ->
    cpu.ram[0xCA]  = 0xCC
    cpu.XR = 0xC0
    cpu.zeropageX(0xAA0A).should.eql 0xCC

  it 'should find oper zeropageY', ->
    cpu.ram[0xDA]  = 0xED
    cpu.YR = 0xD0
    cpu.zeropageY(0xAA0A).should.eql 0xED

describe 'Binary Accumulate', ->
  cpu = new CPU

  beforeEach ->
    cpu.CLD()
    cpu.D.should.eql 0

  it 'should be: 88 + 70 + 1 = 159', ->
    cpu.SEC()
    cpu.AC = 0x58
    cpu.accumulate(0x46)
    cpu.AC.should.eql 159

describe 'BCD Accumulate', ->
  cpu = new CPU

  beforeEach ->
    cpu.SED()
    cpu.D.should.eql 1

  it 'should be: 58 + 46 + 1 = 105', ->
    cpu.SEC()
    cpu.AC = 0x58
    cpu.accumulate(0x46)
    cpu.C.should.eql 1
    cpu.AC.should.eql 0x05

  it 'should be: 12 + 34 = 46', ->
    cpu.CLC()
    cpu.AC = 0x12
    cpu.accumulate(0x34)
    cpu.C.should.eql 0
    cpu.AC.should.eql 0x46

  it 'should be: 15 + 26 = 41', ->
    cpu.CLC()
    cpu.AC = 0x15
    cpu.accumulate(0x26)
    cpu.C.should.eql 0
    cpu.AC.should.eql 0x41

  it 'should be: 81 + 92 = 173)', ->
    cpu.CLC()
    cpu.AC = 0x81
    cpu.accumulate(0x92)
    cpu.C.should.eql 1
    cpu.AC.should.eql 0x73

  it 'should be: 46 - 12 = 34', ->
    cpu.SEC()
    cpu.AC = 0x46
    cpu.accumulate(-0x12)
    cpu.C.should.eql 1
    cpu.AC.should.eql 0x34

  it 'should be: 40 - 13 = 27', ->
    cpu.SEC()
    cpu.AC = 0x40
    cpu.accumulate(-0x13)
    cpu.C.should.eql 1
    cpu.AC.should.eql 0x27

  it 'should be: 32 - 2 - 1 = 29', ->
    cpu.CLC()
    cpu.AC = 0x32
    cpu.accumulate(-0x2)
    cpu.C.should.eql 1
    cpu.AC.should.eql 0x29

  it 'should be: 12 - 21 = (91 - 100)', ->
    cpu.SEC()
    cpu.AC = 0x12
    cpu.accumulate(-0x21)
    cpu.C.should.eql 0
    cpu.AC.should.eql 0x91

  it 'should be: 21 - 34 = (87 - 100)', ->
    cpu.SEC()
    cpu.AC = 0x21
    cpu.accumulate(-0x34)
    cpu.C.should.eql 0
    cpu.AC.should.eql 0x87

  it 'should be: 1 - 1 = 0', ->
    cpu.SEC()
    cpu.AC = 0x01
    cpu.accumulate(-0x01)
    cpu.Z.should.eql 1
    cpu.AC.should.eql 0x0

  it 'should be: 99 + 1 = 0', ->
    cpu.SEC()
    cpu.AC = 0x99
    cpu.accumulate(0x01)
    cpu.Z.should.eql 1
    cpu.AC.should.eql 0x0

describe 'OPC 69', ->
  cpu = new CPU
  beforeEach ->
    cpu.clear()
  it 'should be ADC immidiate', ->
    cpu.ram.length.should.eql 0x10000
