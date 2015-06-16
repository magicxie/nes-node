should = require 'should'
nesrom = require '../src/rom'
cpu2a03 = require '../src/2a03'

ROM = nesrom.ROM
OPRCODES = cpu2a03.OPRCODES

describe 'When load rom file', ->

  rom = new ROM
  cpu = new cpu2a03.CPU

  it 'should no error', ->
    rom.parse './test/roms/NES_Test_Cart.nes'

  it 'should print valid prg banks', ->
    program = rom.getProgram()
    skip = 0
    for i,j in program
      oprcode = OPRCODES[i]
      if oprcode
        if skip == 0
          process.stdout.write '\n#line:' +j+ ' 0x' + i.toString(16) + ':' + oprcode.desc + '\n'
          skip = oprcode.addressMode.call(cpu).bytes
          process.stdout.write oprcode.text
        else
          process.stdout.write ' 0x' + i.toString(16)
          skip--
    process.stdout.write '\r\n'
