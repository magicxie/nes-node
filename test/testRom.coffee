should = require 'should'
nesrom = require '../src/rom'
cpu2a03 = require '../src/2a03'

ROM = nesrom.ROM
OPRCODES = cpu2a03.OPRCODES

describe 'When load rom file', ->
  rom = new ROM
  cpu = new cpu2a03.CPU

  it 'should no error', ->
    rom.parse 'test/roms/NES_Test_Cart.nes'

  it 'should print valid prg banks', ->
    program = rom.getProgram()
    skip = 0
    for i,j in program
      oprcode = OPRCODES[i]
      if oprcode
        if skip == 0
#          process.stdout.write '\n#line:' + j + ' 0x' + i.toString(16) + ':' + oprcode.desc + '\n'
          skip = oprcode.addressMode.call(cpu).bytes
#          process.stdout.write oprcode.text
        else
#          process.stdout.write ' 0x' + i.toString(16)
          skip--
    process.stdout.write '\r\n'

  describe 'When reading sprites bank', ->
    it 'should parse sprites', ->
      character = rom.getCharacter()
      sprites = rom.parseSprite character
    #      for spr,j in sprites
    #        console.log 'sprite', j
    #        console.log spr

    it 'should get binary array', ->
      rom.toBinaryArray(0xFF).should.be.eql [1, 1, 1, 1, 1, 1, 1, 1]
      rom.toBinaryArray(0xF0).should.be.eql [1, 1, 1, 1, 0, 0, 0, 0]
      rom.toBinaryArray(0xA0).should.be.eql [1, 0, 1, 0, 0, 0, 0, 0]

    it 'should composite hex in 4 ways', ->
      rom.compositeHex(0xF0, 0x00).should.be.eql [1, 1, 1, 1, 0, 0, 0, 0]
      rom.compositeHex(0xF0, 0xFF).should.be.eql [3, 3, 3, 3, 2, 2, 2, 2]
      rom.compositeHex(0x0F, 0x00).should.be.eql [0, 0, 0, 0, 1, 1, 1, 1]
      rom.compositeHex(0x0F, 0xFF).should.be.eql [2, 2, 2, 2, 3, 3, 3, 3]

    it 'should composite bit in 4 ways', ->
      rom.compositeBit(0, 0).should.be.eql 0
      rom.compositeBit(1, 0).should.be.eql 1
      rom.compositeBit(0, 1).should.be.eql 2
      rom.compositeBit(1, 1).should.be.eql 3

  describe 'When cpu run', ->
    it 'should execute rom', ->
      for i,j in rom.getProgram()
        cpu.ram[0x8000 + j] = i
      cpu.PC = 0x8000
      while cpu.PC <=33580
        console.log cpu.PC, cpu.ram[cpu.PC]
        cpu.run()
