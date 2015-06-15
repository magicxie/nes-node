should = require 'should'
nesrom = require '../src/rom'
cpu2a03 = require '../src/2a03'
ROM = nesrom.ROM
OPRCODES = cpu2a03.OPRCODES

describe 'When load rom file', ->

  rom = new ROM

  it 'should no error', ->
    rom.parse 'roms/NES Test Cart (Official Nintendo) (U) [!].nes'

  it 'should print valid prg banks', ->
    program = rom.getProgram()
    skip = 0
    for i,j in program when skip = 0
      oprcode = OPRCODES[j]
      if oprcode
        skip = oprcode.addressMode.bytes

