class ROM

  MAGIC_NUMBER: new Buffer([0x4e, 0x45, 0x53, 0x1a]).toString('binary') #NES\0x01a

  PRG_BANK_SIZE: 16384 #bytes
  CHR_BANK_SIZE: 8192  #bytes
  TITLE_DATA_SIZE: 128 #bytes

  constructor: () ->
    @romBuffer

    ###
    16 byte header
    Offsets 4 and 5 specify the number of PRG and CHR banks, @pc, @cc
    ###
    @header = []

    #prgBank number
    @pc = 0
    #chrBank number
    @cc = 0
    @prgBanks = [] #16k
    @chrBanks = []
    @titleData = []

  parse: (file) ->
    fs = require 'fs'
    @romBuffer = fs.readFileSync file

    @pc = @romBuffer.readIntLE(4)
    @cc = @romBuffer.readIntLE(5)

    @prgBanks = @exctractBankData 16, @pc, @PRG_BANK_SIZE
    @chrBanks = @exctractBankData 16 + @pc * @PRG_BANK_SIZE, @cc, @CHR_BANK_SIZE

    titleDataOffset = 16 + @prgBanks.length * @PRG_BANK_SIZE + @chrBanks.length * @CHR_BANK_SIZE
    if @romBuffer.length > titleDataOffset
      @titleData = @romBuffer.slice(titleDataOffset, @romBuffer.length - titleDataOffset).toString('binary')

    @verifyRom()

  exctractBankData: (bankOffset, bankNumber, bankSize)->
    banks = new Array bankNumber
    for ele, index in banks
      banks[index] = new Array bankSize
      start = bankOffset + index * bankSize
      end = start + bankSize
      bankBuffer = @romBuffer.slice(start, end).toString('binary')
      for b,i in bankBuffer
        banks[index][i] = b

    return banks

  verifyRom: ()->
    console.log 'Verifying rom...'

    console.info '#1 Verify magic number.'
    @verifyMagicNumber()
    console.info 'Magic number OK!'

    console.info '#2 Verify program bank.'
    @verifyPrgBanks()
    console.info 'Program bank OK!'

    console.info '#3 Verify character bank.'
    @verifyChrBanks()
    console.info 'Character bank OK!'

    console.info '#4 Verify title data.'
    @verifyTitleData()
    console.info 'Title data OK!'

    console.info '#5 Verify rom size.'
    @verifyRomSize()
    console.info 'Rom size is', @romBuffer.length, 'bytes. OK!'

  verifyMagicNumber: () ->
    magicNumber = @romBuffer.slice(0, 4).toString('binary')

    if magicNumber != @MAGIC_NUMBER
      console.error magicNumber
      throw new Error 'Invalid rom magic number!!'

  verifyPrgBanks: () ->
    console.info 'Has', @pc, 'program bank(s)'

  verifyChrBanks: () ->
    console.info 'Has', @cc, 'character bank(s)'

  verifyTitleData: () ->
    if @titleData.length == 0
      console.info 'Rom doesn\'t have title data.'
    else if @titleData.length == @TITLE_DATA_SIZE
      console.info 'Rom has title data.'
    else
      throw new Error 'Invalid title data size!!'

  verifyRomSize: () ->
    expectedBytes = 16 + @prgBanks.length * @PRG_BANK_SIZE + @chrBanks.length * @CHR_BANK_SIZE + @titleData.length

    actualBytes = @romBuffer.length

    if expectedBytes != actualBytes
      console.error 'actualBytes:', actualBytes, 'expectedBytes', expectedBytes
      throw new Error 'Invalid rom size!!'

  getProgram: () ->
    program = []
    for i of @prgBanks
      v = @prgBanks[i]
      console.info 'Bank', i
      for j of v
        program.push v[j].charCodeAt()

    return program

  getCharacter: () ->
    character = []
    for i of @chrBanks
      v = @chrBanks[i]
      console.info 'Bank', i
      for j of v
        character.push v[j].charCodeAt()

    return character

  parseSprite: (character) ->
    for i,j in character when j % 16 == 0
      channelA = character.slice j, 8
      channelB = characte.slice j + 8, 8



  combineChannel: (channelA, channelB) ->
    channelB[0] + channelA[0]

  toBinaryArray: (hexString) ->
    (hexString + 0x100).toString(2).substr(1).split('').map (e)-> e * 1;

  compositeHex: (hexA, hexB) ->
    binaryA = @toBinaryArray hexA
    binaryB = @toBinaryArray hexB

    console.log hexA,binaryA,hexB,binaryB
    [
      @compositeBit(binaryA[0], binaryB[0]),
      @compositeBit(binaryA[1], binaryB[1]),
      @compositeBit(binaryA[2], binaryB[2]),
      @compositeBit(binaryA[3], binaryB[3]),
      @compositeBit(binaryA[4], binaryB[4]),
      @compositeBit(binaryA[5], binaryB[5]),
      @compositeBit(binaryA[6], binaryB[6]),
      @compositeBit(binaryA[7], binaryB[7])
    ]

  ###
  When the channels are combined, channel B has a "weight" of 2.
  Gander at this Truth table-like diagram of how to determine the composite image (ChannelA, ChannelB, Composite):
    A	B	C
    0	0	0
    1	0	1
    0	1	2
    1	1	3
  ###
  compositeBit: (bitA, bitB) ->
    (bitB << 1) + bitA


exports.ROM = ROM