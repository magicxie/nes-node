class CPU

  ##registers

  PC : 0 ##Program Counter
  AC : 0 ##Accumulator
  XR : 0 ##X Register
  YR : 0 ##Y Register
  SR : 0 ##Status Register
  SP : 0 ##Stack Pointer
  N : 0 ##Negative
  V : 0 ##Overflow
  U : 1 ##ignored
  B : 0 ##Break
  D : 0 ##Decimal
  I : 0 ##Interrupt (IRQ disable)
  Z : 0 ##Zero
  C : 0 ##Carry

  #16k ram
  ram : []
  ramSize : 0xFFFF

  constructor : ->
    for x in [0..@ramSize]
      @ram[x] = 0;

  #reset pc
  reset :() ->
    @PC = 0; 

  #clear ram
  clear :() ->
    for x in [0..@ramSize]
      @ram[x] = 0;

  printRegisters : ()->
    console.log 'AC=',@AC,'(= BDC',@AC.toString(16),') V=',@V,'C=',@C, 'N=',@N,'Z=',@Z

  ADDRESSING_MODE : {
    ACCUMULATOR : 'ACC',
    IMMEDIATE : 'IMM',
    IMPLIED : 'IMP'
  }

  #addressing mode:
  #A		....	Accumulator	 	OPC A	 	operand is AC
  accumulator :() -> {operand : @AC, address : @ADDRESSING_MODE.ACCUMULATOR}

#abs		....	absolute	 	OPC $HHLL	 	operand is address $HHLL
  absolute    :(oper) -> {operand : @ram[oper], address : oper}

#abs,X		....	absolute, X-indexed	 	OPC $HHLL,X	 	operand is address incremented by X with carry
  absoluteX   :(oper) -> {operand : @ram[oper + @XR], address : oper + @XR}

#abs,Y		....	absolute, Y-indexed	 	OPC $HHLL,Y	 	operand is address incremented by Y with carry
  absoluteY   :(oper) -> {operand : @ram[oper + @YR], address : oper + @YR}

# #		....	immediate	 	OPC #$BB	 	operand is byte (BB)
  immediate :(oper) -> {operand : oper, address : @ADDRESSING_MODE.IMMEDIATE}

#impl		....	implied	 	OPC	 	operand implied
  implied : (oper) -> {operand : @AC, address : @ADDRESSING_MODE.IMPLIED}

#ind		....	indirect	 	OPC ($HHLL)	 	operand is effective address; effective address is value of address
  indirect :(oper) -> {operand : @ram[@ram[oper]], address : @ram[oper]}

#X,ind		....	X-indexed, indirect	 	OPC ($BB,X)
  # operand is effective zeropage address; effective address is byte (BB) incremented by X without carry
  indirectX :(oper) ->  {operand : @ram[@ram[(oper  & 0x00FF) + @XR]], address : @ram[(oper  & 0x00FF) + @XR]}

#ind,Y		....	indirect, Y-indexed	 	OPC ($LL),Y
  # operand is effective address incremented by Y with carry; effective address is word at zeropage address
  indirectY :(oper) ->  {operand : @ram[@ram[(oper  & 0x00FF) + @YR]], address : @ram[(oper  & 0x00FF) + @YR]}

#rel		....	relative	 	OPC $BB	 	branch target is PC + offset (BB), bit 7 signifies negative offset
  relative :(oper) -> {operand : @ram[@PC + oper], address : @PC + oper}

#zpg		....	zeropage	 	OPC $LL	 	operand is of address; address hibyte : zero ($00xx)
  zeropage :(oper) -> {operand : @ram[oper & 0x00FF], address : oper & 0x00FF}

#zpg,X		....	zeropage, X-indexed	 	OPC $LL,X
  # operand is address incremented by X; address hibyte : zero ($00xx); no page transition
  zeropageX :(oper) ->  {operand : @ram[(oper + @XR) & 0x00FF], address : oper + @XR};

  #zpg,Y		....	zeropage, Y-indexed	 	OPC $LL,Y
  # operand is address incremented by Y; address hibyte : zero ($00xx); no page transition
  zeropageY :(oper) ->  {operand : @ram[(oper + @YR) & 0x00FF], address : oper + @YR};

  addressing : () ->
    if arguments.length == 2
        return arguments[1]
    else
      return this.immediate

  ##cpu step info
  @stepInfo : {
    operand : 0x00,
    addressMode : this.immediate
  }

  step : () ->
    operand = @ram[@PC]
    @stepInfo.operand = operand


  accumulate : (src, dst, carry) ->
      return src + dst + carry;

  setZ : (oper) ->
    @Z = if oper == 0 then 1 else 0;

  setN : (oper) ->
    @N = if (oper & 0x80) != 0 then 1 else 0;

  setZN : (oper) ->
    this.setZ(oper)
    this.setN(oper)

  SED : () ->
    @D = 1

  SEC : () ->
    @C = 1

  CLC : () ->
    @C = 0

  CLD : () ->
    @D = 0

  LDA : (oper) ->

    @AC = this.addressing(arguments)(oper)


  ###
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
  ###
  ADC : (stepInfo) ->

    operand = stepInfo.operand

    @AC = this.accumulate(operand, @AC, @C)

    console.log '@AC',@AC

    @C = if @AC > 0xFF then 1 else 0;

    this.setZN(@AC)

    H4b = @AC / 0x10
    @V = if H4b >= -8 & H4b <= 7 then 0 else 1;
    if @V == 1
      console.warn('High 4 bit', H4b.toString(16), 'is not in rage(-8~7). Overflow!!')
    console.log('@H4b is', H4b.toString(16))

    @AC = @AC & 0xFF;

    this.printRegisters()

  SBC : (stepInfo) ->

    operand = - stepInfo.operand

    @AC = this.accumulate(operand, @AC, @C)

    console.log '@AC',@AC

    @C = if @AC > 0xFF then 1 else 0;

    this.setZN(@AC)

    H4b = @AC / 0x10
    @V = if H4b >= -8 & H4b <= 7 then 0 else 1;
    if @V == 1
      console.warn('High 4 bit', H4b.toString(16), 'is not in rage(-8~7). Overflow!!')
    console.log('@H4b is', H4b.toString(16))

    @AC = @AC & 0xFF;


  ###
  AND Memory with Accumulator

     A AND M -> A                     N Z C I D V
                                      + + - - - -

     addressing    assembler    opc  bytes  cyles
     --------------------------------------------
     immidiate     AND #oper     29    2     2
     zeropage      AND oper      25    2     3
     zeropage,X    AND oper,X    35    2     4
     absolute      AND oper      2D    3     4
     absolute,X    AND oper,X    3D    3     4*
     absolute,Y    AND oper,Y    39    3     4*
     (indirect,X)  AND (oper,X)  21    2     6
     (indirect),Y  AND (oper),Y  31    2     5*
  ###
  AND : (oper) ->
    oper = this.addressing(arguments)(oper)
    @AC = @AC & oper & 0xFF
    this.setZN(@AC)

  ###
  ASL  Shift Left One Bit (Memory or Accumulator)

     C <- [76543210] <- 0             N Z C I D V
                                      + + + - - -

     addressing    assembler    opc  bytes  cyles
     --------------------------------------------
     accumulator   ASL A         0A    1     2
     zeropage      ASL oper      06    2     5
     zeropage,X    ASL oper,X    16    2     6
     absolute      ASL oper      0E    3     6
     absolute,X    ASL oper,X    1E    3     7
   ###
  ASL : (oper) ->

    addressingMode = this.addressing(arguments);
    oper = addressingMode(oper)

    if addressingMode == accumulator
      console.log(addressingMode)

    else




  exports.CPU = CPU